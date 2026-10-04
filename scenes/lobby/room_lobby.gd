class_name RoomLobby
extends Control
## 房間等候頁：Host 與 Client 共用，依角色顯示按鈕。流程規則見 docs/lobby-flow.md。
## 這裡只讀 RoomManager 的狀態、呼叫它的函式；換場景都由 RoomManager 處理，所以單獨按 F6 也能測試。
##
## 座位：點選「玩家 1」「玩家 2」切換自己的角色（RoomManager.claim_slot，不需要對方同意）。
## 玩家 1 用音高控制龍的高度，玩家 2 負責吸／吐；誰坐哪個座位與誰是房主無關。
##
## 左下玩家 1（音高）、右下玩家 2（吸／吐）的輸入顯示，讓兩位玩家進遊戲前先測試、一起熟悉：
## - 坐在某個座位的人，本機量該座位的輸入並傳給對方（PlayerPitchInput／PlayerActionInput）。
## - 另一個座位顯示對方傳來的輸入。
## - Host 房內只有自己時（單機），兩個座位的輸入都由本機負責。

@onready var _slot1_button: Button = %Slot1Button
@onready var _slot2_button: Button = %Slot2Button
@onready var _local_ip_label: Label = %LocalIpLabel
@onready var _status_label: Label = %StatusLabel
@onready var _solo_button: Button = %SoloButton
@onready var _join_box: Control = %JoinBox
@onready var _ip_input: LineEdit = %IpInput
@onready var _join_button: Button = %JoinButton
@onready var _start_button: Button = %StartButton
@onready var _leave_button: Button = %LeaveButton
@onready var _panels: PlayerInputPanels = %PlayerPanels

## 等候頁自己的提示（例如沒填 IP），下次房間狀態改變時清除。
var _local_hint: String = ""
var _pitch_input: PlayerPitchInput
var _action_input: PlayerActionInput


func _ready() -> void:
	_slot1_button.pressed.connect(RoomManager.claim_slot.bind(1))
	_slot2_button.pressed.connect(RoomManager.claim_slot.bind(2))
	_solo_button.pressed.connect(RoomManager.start_solo)
	_join_button.pressed.connect(_on_join_pressed)
	_ip_input.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	_start_button.pressed.connect(RoomManager.start_match)
	_leave_button.pressed.connect(_on_leave_pressed)
	RoomManager.room_changed.connect(_on_room_changed)
	NetworkManager.voice_action_received.connect(_on_remote_action)
	NetworkManager.pitch_received.connect(_on_remote_pitch)

	# 自己座位的本機輸入。是否啟用、要不要傳給對方依座位在 _refresh_player_inputs() 設定。
	_pitch_input = PlayerPitchInput.new()
	add_child(_pitch_input)
	_action_input = PlayerActionInput.new()
	_action_input.action_changed.connect(_panels.show_action)
	add_child(_action_input)

	# 單獨執行這個場景（F6）時還沒有房間，自動建立。
	if RoomManager.role == RoomManager.Role.NONE:
		RoomManager.enter_room(false)
	_refresh()


func _process(_delta: float) -> void:
	if RoomManager.phase == RoomManager.Phase.JOINING:
		_refresh_status()
	if _pitch_input.enabled:
		_panels.set_pitch(_pitch_input.level, _pitch_input.lane if _pitch_input.controls_dragon else -1)
	_panels.set_pitch_input_off(_pitch_input.enabled and not MicInput.pitch_input_enabled)


func _exit_tree() -> void:
	MicInput.save_settings()


func _on_room_changed() -> void:
	_local_hint = ""
	_refresh()


func _on_join_pressed() -> void:
	if _ip_input.text.strip_edges().is_empty():
		_local_hint = "請先輸入對方的 IP"
		_refresh_status()
		return
	RoomManager.join_room(_ip_input.text)


func _on_leave_pressed() -> void:
	if RoomManager.phase == RoomManager.Phase.JOINING:
		RoomManager.cancel_join()
	else:
		RoomManager.leave_room()


# ---- 對方的輸入 ----

## 對方坐玩家 1：顯示對方傳來的音高。
func _on_remote_pitch(level: float, lane: int) -> void:
	if not _pitch_input.enabled:
		_panels.set_pitch(level, lane)


## 對方坐玩家 2：顯示對方傳來的吸／吐。
func _on_remote_action(_peer_id: int, action: String) -> void:
	if not _action_input.enabled:
		_panels.show_action(action)


# ---- 畫面 ----

func _refresh() -> void:
	var is_host: bool = RoomManager.role == RoomManager.Role.HOST
	var is_client: bool = RoomManager.role == RoomManager.Role.CLIENT
	var joining: bool = RoomManager.phase == RoomManager.Phase.JOINING
	var count: int = RoomManager.get_player_count()

	_refresh_seats(is_host, is_client, joining, count)
	_local_ip_label.text = _local_ip_text(is_host)

	# 以單機遊玩、加入別人房間：只有 Host，且房內只有自己時可按。
	_solo_button.visible = is_host or joining
	_solo_button.disabled = not RoomManager.can_start_solo()
	_join_box.visible = is_host or joining
	_join_button.disabled = not RoomManager.can_join_other()
	_ip_input.editable = RoomManager.can_join_other()

	# 開始遊戲：Host 滿 2 人才可按；Client 只顯示「等待房主開始」。
	_start_button.text = "開始遊戲" if is_host or joining else "等待房主開始"
	_start_button.disabled = not RoomManager.can_start_match()

	_leave_button.text = "取消連線" if joining else "離開"
	_refresh_player_inputs(is_host, joining, count)
	_refresh_status()


func _refresh_seats(is_host: bool, is_client: bool, joining: bool, count: int) -> void:
	var mine: int = RoomManager.get_my_slot()
	var clickable: bool = RoomManager.phase == RoomManager.Phase.ROOM
	var buttons: Array[Button] = [_slot1_button, _slot2_button]
	for i in buttons.size():
		var slot: int = i + 1
		buttons[i].text = "玩家 %d｜%s" % [slot, _seat_owner_text(slot == mine, is_host, is_client, joining, count)]
		buttons[i].theme_type_variation = &"SeatMine" if slot == mine else &"SeatOther"
		buttons[i].disabled = not clickable


func _seat_owner_text(is_mine: bool, is_host: bool, is_client: bool, joining: bool, count: int) -> String:
	if is_mine:
		return "你（房主）" if is_host else "你"
	if is_client:
		return "房主"
	if joining:
		return "連線中…"
	if count >= 2:
		return "對方（已加入）"
	return "等待加入…"


## 自己座位的輸入由本機負責並傳給對方；Host 房內只有自己（單機）時兩個座位都由本機負責。
func _refresh_player_inputs(is_host: bool, joining: bool, count: int) -> void:
	var alone: bool = is_host and count == 1
	var has_peer: bool = count == 2
	var mine: int = RoomManager.get_my_slot()
	var player1_is_mine: bool = alone or mine == 1
	var player2_is_mine: bool = alone or mine == 2

	_pitch_input.enabled = player1_is_mine and not joining
	_pitch_input.send_to_peer = has_peer and mine == 1
	_action_input.enabled = player2_is_mine and not joining
	_action_input.send_to_peer = has_peer and mine == 2

	_panels.set_player1("你的音高：對麥克風發出高低音" if player1_is_mine else "對方的音高", player1_is_mine)
	var player2_caption: String = "對方的吸／吐"
	if alone:
		player2_caption = "單機時由你操作：喊「吸」「吐」，或按 J／K"
	elif player2_is_mine:
		player2_caption = "你的吸／吐：喊「吸」「吐」，或按 J／K"
	_panels.set_player2(player2_caption, player2_is_mine)
	if not player1_is_mine:
		_panels.set_pitch(0.0, -1)
		_panels.set_pitch_input_off(false)


func _local_ip_text(is_host: bool) -> String:
	if not is_host or not NetworkManager.is_host():
		return ""
	return "本機 IP：%s　Port：%d" % [", ".join(NetworkManager.get_local_ips()), NetworkManager.port]


func _refresh_status() -> void:
	_status_label.text = _status_text()


func _status_text() -> String:
	if RoomManager.phase == RoomManager.Phase.JOINING:
		return "連線中…（剩 %d 秒）" % ceili(NetworkManager.get_join_remaining_sec())
	if not _local_hint.is_empty():
		return _local_hint
	var lines: PackedStringArray = []
	if not RoomManager.notice.is_empty():
		lines.append(RoomManager.notice)
	if not RoomManager.room_error.is_empty():
		lines.append(RoomManager.room_error)
	if RoomManager.role == RoomManager.Role.CLIENT:
		lines.append("已加入房間，等待房主開始遊戲")
	elif RoomManager.get_player_count() >= 2:
		lines.append("對方已加入，可以開始遊戲")
	else:
		lines.append("等待對方輸入你的 IP 加入，或選擇單機、加入別人的房間")
	return "\n".join(lines)
