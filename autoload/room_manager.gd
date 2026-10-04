extends Node
## 房間流程（autoload）：依 docs/lobby-flow.md 管理單機、加入、開局、斷線與離開，並負責換場景。
## 畫面（等候頁、主選單、遊戲）只讀這裡的狀態、呼叫這裡的函式；畫面之間不直接換場景。

## 房間內容、角色或提示文字改變，等候頁收到後重新讀取。
signal room_changed

enum Role { NONE, HOST, CLIENT }
## MENU：在主選單。ROOM：等候頁。JOINING：Host 正在嘗試連線他人房間。SOLO：單機遊戲。MATCH：連線遊戲。
enum Phase { MENU, ROOM, JOINING, SOLO, MATCH }

const MENU_SCENE: String = "res://scenes/main_menu/main_menu.tscn"
const LOBBY_SCENE: String = "res://scenes/lobby/room_lobby.tscn"
const GAME_SCENE: String = "res://scenes/game/main.tscn"

var role: Role = Role.NONE
var phase: Phase = Phase.MENU
## 給玩家看的最近一則提示（加入失敗原因、對方斷線等）。使用者做下一個動作時清除。
var notice: String = ""
## Host 建立區網房間失敗的原因（例如 port 被占用）；成功時為空字串。
var room_error: String = ""
## 房主坐的座位：1＝玩家 1（音高換層），2＝玩家 2（吸／吐）；加入者坐另一個。
## 座位只決定誰負責哪一種輸入，遊戲邏輯仍然只在房主的電腦上執行。連線局開始後不能換。
var host_slot: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.join_failed.connect(func() -> void: _join_failed("連不上對方，請確認 IP、同一個網路與防火牆"))
	NetworkManager.join_rejected.connect(_join_failed)
	NetworkManager.join_timed_out.connect(func() -> void: _join_failed("連線逾時（%d 秒）" % int(NetworkManager.join_timeout_sec)))
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.slot_swap_requested.connect(_on_slot_swap_requested)
	NetworkManager.slot_assignment_received.connect(_on_slot_assignment_received)
	NetworkManager.server_lost.connect(_on_server_lost)
	NetworkManager.room_closed_by_host.connect(_on_room_closed_by_host)
	NetworkManager.match_started.connect(_on_match_started)
	NetworkManager.match_ended.connect(_on_match_ended)


# ---- 查詢 ----

## 房內人數：Host 是自己加上 Client；Client 加入成功後固定是 2。
func get_player_count() -> int:
	match role:
		Role.HOST:
			return 1 + NetworkManager.get_client_count()
		Role.CLIENT:
			return 2
	return 0


## 這台電腦坐的座位（1 或 2）。
func get_my_slot() -> int:
	if role == Role.CLIENT:
		return 3 - host_slot
	return host_slot


## 對方坐的座位。
func get_peer_slot() -> int:
	return 3 - get_my_slot()


## 按 Esc 開暫停選單時，要不要凍結遊戲（get_tree().paused）。
## Client 沒有遊戲邏輯，等候頁也沒有東西要凍結，這兩處只疊出設定選單，讓玩家可以繼續操作。
func pause_freezes_game() -> bool:
	if role == Role.CLIENT:
		return false
	return phase != Phase.ROOM and phase != Phase.JOINING


func can_start_solo() -> bool:
	return role == Role.HOST and phase == Phase.ROOM and get_player_count() == 1


func can_join_other() -> bool:
	return can_start_solo()


func can_start_match() -> bool:
	return role == Role.HOST and phase == Phase.ROOM and get_player_count() == 2


# ---- 玩家動作 ----

## 進入遊戲：在區網自動開房，自己是 Host，進入等候頁。
## 等候頁單獨執行（F6）時用 change_scene = false，留在目前場景。
func enter_room(change_scene: bool = true) -> void:
	_clear_notice()
	role = Role.HOST
	phase = Phase.ROOM
	_open_room()
	if change_scene:
		_go(LOBBY_SCENE)
	room_changed.emit()


## 點選座位（1 或 2）切換自己的角色，不需要對方同意：
## 房內只有自己時直接入座；有對方時兩人互換。加入者的要求由房主套用後通知雙方。
func claim_slot(slot: int) -> void:
	if phase != Phase.ROOM or slot == get_my_slot() or (slot != 1 and slot != 2):
		return
	if role == Role.HOST:
		_set_host_slot(slot)
	elif role == Role.CLIENT:
		NetworkManager.request_slot_swap()


## 以單機遊玩：關閉區網房間，開始單機遊戲。
func start_solo() -> void:
	if not can_start_solo():
		return
	_clear_notice()
	NetworkManager.leave()
	phase = Phase.SOLO
	_go(GAME_SCENE)
	room_changed.emit()


## 嘗試連線他人房間。成功才成為 Client；失敗會重新建立自己的房間並回到等候頁。
## ENet 一次只能是 Server 或 Client，所以嘗試期間會先關掉自己的房間。
func join_room(ip: String) -> void:
	if not can_join_other():
		return
	_clear_notice()
	NetworkManager.leave()
	phase = Phase.JOINING
	var err: Error = NetworkManager.join_game(ip)
	if err != OK:
		_join_failed("無法連線（%s），請檢查 IP" % error_string(err))
		return
	room_changed.emit()


## 取消正在進行的連線嘗試。
func cancel_join() -> void:
	if phase != Phase.JOINING:
		return
	NetworkManager.leave()
	_join_failed("已取消連線")


## Host 滿 2 人時開始連線遊戲。
func start_match() -> void:
	if not can_start_match():
		return
	_clear_notice()
	phase = Phase.MATCH
	NetworkManager.start_match()
	_go(GAME_SCENE)
	room_changed.emit()


## 連線遊戲結束後回到房間等候頁（Host 呼叫，Client 會一起回去）。
func finish_match() -> void:
	if role != Role.HOST or phase != Phase.MATCH:
		return
	NetworkManager.end_match()
	phase = Phase.ROOM
	_go(LOBBY_SCENE)
	room_changed.emit()


## 離開房間回主選單。Host 離開會關閉整個房間，Client 也會被退回主選單；Client 離開則 Host 留在房內。
func leave_room() -> void:
	var was_host: bool = role == Role.HOST
	_clear_notice()
	role = Role.NONE
	phase = Phase.MENU
	if was_host:
		await NetworkManager.close_room()
	else:
		NetworkManager.leave()
	_go(MENU_SCENE)
	room_changed.emit()


## 單機遊戲結束：回主選單。
func return_to_menu() -> void:
	NetworkManager.leave()
	role = Role.NONE
	phase = Phase.MENU
	_go(MENU_SCENE)
	room_changed.emit()


# ---- 連線事件 ----

func _on_joined_server() -> void:
	role = Role.CLIENT
	phase = Phase.ROOM
	notice = ""
	room_error = ""
	room_changed.emit()


func _on_peer_joined(_id: int) -> void:
	notice = "對方已加入"
	NetworkManager.send_slot_assignment(host_slot)
	room_changed.emit()


func _on_peer_left(_id: int) -> void:
	if role != Role.HOST:
		return
	if phase == Phase.MATCH:
		NetworkManager.match_in_progress = false
		phase = Phase.ROOM
		notice = "對方斷線，已回到房間"
		_go(LOBBY_SCENE)
	else:
		notice = "對方已離開"
	room_changed.emit()


func _set_host_slot(slot: int) -> void:
	if slot == host_slot:
		return
	host_slot = slot
	NetworkManager.send_slot_assignment(host_slot)
	room_changed.emit()


func _on_slot_swap_requested() -> void:
	if role == Role.HOST and phase == Phase.ROOM and get_player_count() == 2:
		_set_host_slot(3 - host_slot)


func _on_slot_assignment_received(slot: int) -> void:
	if role != Role.CLIENT:
		return
	host_slot = slot
	room_changed.emit()


## Client 偵測到 Host 斷線：原房間屬於對方，已連不上，重新建立自己的房間。
func _on_server_lost() -> void:
	if phase == Phase.JOINING:
		_join_failed("連線中斷")
		return
	role = Role.HOST
	phase = Phase.ROOM
	_open_room()
	notice = "與房主斷線，已建立你自己的房間"
	_go(LOBBY_SCENE)
	room_changed.emit()


func _on_room_closed_by_host() -> void:
	role = Role.NONE
	phase = Phase.MENU
	notice = "房主已關閉房間"
	_go(MENU_SCENE)
	room_changed.emit()


func _on_match_started() -> void:
	if role != Role.CLIENT:
		return
	phase = Phase.MATCH
	_go(GAME_SCENE)
	room_changed.emit()


func _on_match_ended() -> void:
	if role != Role.CLIENT:
		return
	phase = Phase.ROOM
	_go(LOBBY_SCENE)
	room_changed.emit()


# ---- 內部 ----

func _open_room() -> void:
	host_slot = 1
	var err: Error = NetworkManager.host_game()
	if err == OK:
		room_error = ""
	else:
		room_error = "建立區網房間失敗（%s），port %d 可能被占用" % [error_string(err), NetworkManager.port]


## 加入失敗：保留（重新建立）自己的房間，留在等候頁並顯示原因。
func _join_failed(reason: String) -> void:
	if phase != Phase.JOINING:
		return
	role = Role.HOST
	phase = Phase.ROOM
	_open_room()
	notice = "加入失敗：" + reason
	_go(LOBBY_SCENE)
	room_changed.emit()


## 換場景前解除暫停：暫停中被斷線或回房間時，新場景不能還卡在暫停。
func _release_pause() -> void:
	if PauseMenu.visible:
		PauseMenu.close()
	get_tree().paused = false


func _clear_notice() -> void:
	notice = ""


## 換場景。目前已經在該場景時不重新載入；場景檔還不存在（例如 client_play）時只警告，不中斷流程。
func _go(path: String) -> void:
	_release_pause()
	# Client 在連線局載入的遊戲場景是副本：不模擬，只顯示 Host 傳來的狀態（NET-19）
	GameManager.replica_mode = path == GAME_SCENE and role == Role.CLIENT
	var current: Node = get_tree().current_scene
	if current != null and current.scene_file_path == path:
		return
	if not ResourceLoader.exists(path):
		push_warning("RoomManager：找不到場景 %s" % path)
		return
	get_tree().change_scene_to_file(path)
