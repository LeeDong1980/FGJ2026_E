class_name NetworkGameBridge
extends Node
## 連線局的 Host 端橋接。遊戲邏輯只在 Host 執行，玩家 1（音高換層）與玩家 2（吸／吐）誰坐哪個座位
## 由等候頁決定（RoomManager.host_slot），這裡依座位決定輸入從哪裡來。
## 只在 RoomManager 判定「Host 的連線局」時啟用；單機與直接 F6 執行遊戲場景（main.tscn）時什麼都不做。
##
## 啟用時：
## - 房主坐玩家 1：房主用本機音高換層、大叫或鍵盤 4 換元素；停用本機鍵盤 J／K／L 吸吐轉頭與語音吸吐，這些都只來自 Client
##   （inhale 呼叫 suck()，exhale／none 呼叫 spit_pressed()／spit_released()，字音 turn 呼叫 turn_head()）；
##   鍵盤 1／2／3 換層保留當保底。
## - 房主坐玩家 2：房主用本機 J／K／L、語音吸吐；停用本機音高、數字鍵換層與大叫／4 換元素，換層來自 Client 傳來的音高（lane），
##   音高比例也餵給 HUD 的音高條；換元素來自 Client 的字音 element。
## - 轉頭（L）跟著吸／吐，屬於玩家 2；換元素（大叫或 4）跟著換層，屬於玩家 1。
## - 直接開局，不顯示開始介面（開局時 UIGameBridge 會校正聲音並顯示遊玩介面）。
## - 遊戲結束時改顯示「回到房間」，按下後呼叫 RoomManager.finish_match()，Client 會一起回到等候頁。
##   等 UI-15（ResultScreen 只發 signal）完成後，這個臨時的結束畫面可以拿掉。

const LANE_ACTIONS: Array[StringName] = [&"lane_1", &"lane_2", &"lane_3"]
## 開局前最久等 Client 的畫面載入完成（它載入完會要求完整狀態）多少秒，超過就直接開始。
const CLIENT_READY_TIMEOUT: float = 8.0

@export var game_manager: GameManager
@export var dragon: Dragon
@export var keyboard_input: KeyboardInput
@export var voice_action_input: VoiceActionInput
@export var pitch_lane_input: PitchLaneInput
@export var shout_element_input: ShoutElementInput
@export var ui_bridge: UIGameBridge
@export var ui_root: UIRoot
## 【暫時的診斷顯示】在畫面左上角顯示 Client 最後送來的輸入，確認封包有沒有收到。語音參數調好後可關閉或移除。
@export var show_debug: bool = true

var _host_slot: int = 1
var _remote_action: String = NetworkManager.ACTION_NONE
var _received_count: int = 0
var _debug_label: Label
var _was_paused: bool = false
var _client_ready: bool = false


func _ready() -> void:
	if not _is_host_match():
		set_process_unhandled_input(false)
		return
	# Host 暫停時本節點也要持續運作，才能在暫停與繼續的瞬間補上噴火的放開與接續。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_host_slot = RoomManager.host_slot
	NetworkManager.voice_word_received.connect(_on_remote_word)
	if _host_slot == 1:
		_disable_local_action_input()
		NetworkManager.voice_action_received.connect(_on_remote_action)
	else:
		_disable_local_pitch_input()
		NetworkManager.pitch_received.connect(_on_remote_pitch)
	if show_debug:
		_build_debug_label()
	game_manager.game_won.connect(_show_end.bind(true))
	game_manager.game_lost.connect(_show_end.bind(false))
	NetworkManager.state_requested.connect(func() -> void: _client_ready = true)
	_start_when_client_ready()


## 等所有子節點（含 UIGameBridge）都 ready，也等 Client 的畫面載入完成，再開局，兩邊才從同一個時間點開始。
func _start_when_client_ready() -> void:
	await get_tree().process_frame
	var waited: float = 0.0
	while not _client_ready and waited < CLIENT_READY_TIMEOUT:
		await get_tree().process_frame
		waited += get_process_delta_time()
	game_manager.start_game()


func _process(_delta: float) -> void:
	var paused: bool = get_tree().paused
	if paused == _was_paused:
		return
	_was_paused = paused
	if paused:
		game_manager.spit_released()
	elif _remote_action == NetworkManager.ACTION_EXHALE:
		game_manager.spit_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or _host_slot != 1:
		return
	for i in LANE_ACTIONS.size():
		if event.is_action_pressed(LANE_ACTIONS[i]):
			dragon.set_target_lane(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"toggle_element"):
		game_manager.toggle_element()
		get_viewport().set_input_as_handled()


func _is_host_match() -> bool:
	return RoomManager.role == RoomManager.Role.HOST and RoomManager.phase == RoomManager.Phase.MATCH


func _disable_local_action_input() -> void:
	keyboard_input.process_mode = Node.PROCESS_MODE_DISABLED
	# 語音吸吐是接 MicInput.action_changed signal，停用節點擋不住，要把連線拆掉。
	voice_action_input.process_mode = Node.PROCESS_MODE_DISABLED
	for connection: Dictionary in MicInput.action_changed.get_connections():
		if (connection["callable"] as Callable).get_object() == voice_action_input:
			MicInput.action_changed.disconnect(connection["callable"])


## 房主坐玩家 2：本機音高不用，數字鍵不換層、大叫與 4 不換元素，這些交給 Client。
func _disable_local_pitch_input() -> void:
	pitch_lane_input.queue_free()
	shout_element_input.process_mode = Node.PROCESS_MODE_DISABLED
	keyboard_input.allow_player1_keys = false


## Client 坐玩家 1：用對方傳來的層控制龍，音高比例給 HUD 顯示。lane 為 -1 表示對方還沒有音高。
func _on_remote_pitch(level: float, lane: int) -> void:
	_received_count += 1
	if _debug_label != null:
		_debug_label.text = "Client 音高：%.0f%%，層 %d（已收到 %d 個封包）" % [level * 100.0, lane + 1, _received_count]
	ui_bridge.remote_pitch_level = level
	if lane >= 0 and not get_tree().paused:
		dragon.set_target_lane(lane)


## Client 的動作改變：inhale 吸一次；exhale 開始吐或噴火，直到換成別的動作才放開。
func _on_remote_action(_peer_id: int, action: String) -> void:
	_received_count += 1
	if _debug_label != null:
		_debug_label.text = "Client 動作：%s（已收到 %d 個封包）" % [action, _received_count]
	if action == _remote_action:
		return
	var was_exhale: bool = _remote_action == NetworkManager.ACTION_EXHALE
	_remote_action = action
	if get_tree().paused:
		return  # 暫停中只記下 Client 目前的動作，繼續遊戲時再接上
	if was_exhale:
		game_manager.spit_released()
	match action:
		NetworkManager.ACTION_INHALE:
			game_manager.suck()
		NetworkManager.ACTION_EXHALE:
			game_manager.spit_pressed()


## Client 的字音：玩家 2 按 L 轉頭；玩家 1 大叫或按 4 換元素。只接對方座位該有的字音。
func _on_remote_word(_peer_id: int, _seq: int, word: String) -> void:
	if get_tree().paused:
		return
	if word == NetworkManager.WORD_TURN and _host_slot == 1:
		game_manager.turn_head()
	elif word == NetworkManager.WORD_ELEMENT and _host_slot == 2:
		game_manager.toggle_element()


func _build_debug_label() -> void:
	var layer := CanvasLayer.new()
	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 40)
	_debug_label.text = "Client %s：尚未收到封包" % ("動作" if _host_slot == 1 else "音高")
	layer.add_child(_debug_label)
	add_child(layer)


func _show_end(won: bool) -> void:
	if _remote_action == NetworkManager.ACTION_EXHALE:
		game_manager.spit_released()
	_remote_action = NetworkManager.ACTION_NONE
	ui_root.hide_all()
	add_child(_build_end_overlay(won))


func _build_end_overlay(won: bool) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 10
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "成功！" if won else "失敗…"
	title.add_theme_font_size_override("font_size", 72)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var detail := Label.new()
	detail.text = "完成 %d / %d 鍋　清空 %d / %d 次" % [
		game_manager.completed_count, game_manager.pots_to_win,
		game_manager.cleared_count, game_manager.clears_to_lose]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail)

	var button := Button.new()
	button.text = "回到房間"
	button.pressed.connect(RoomManager.finish_match)
	box.add_child(button)
	button.grab_focus.call_deferred()
	return layer
