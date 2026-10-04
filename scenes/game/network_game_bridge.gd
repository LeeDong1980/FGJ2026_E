class_name NetworkGameBridge
extends Node
## 連線局的 Host 端橋接：Host 是玩家 A（音高換層），Client 是玩家 B（吸／吐，經 NetworkManager 傳來）。
## 只在 RoomManager 判定「Host 的連線局」時啟用；單機與直接 F6 執行 game.tscn 時什麼都不做。
##
## 啟用時：
## - 停用本機鍵盤 J／K 吸吐與語音吸吐（吸吐只來自 Client）；鍵盤 1／2／3 換層保留，當作音高不穩時的保底。
## - 直接開局，不顯示開始介面（開局時 UIGameBridge 會校正聲音並顯示遊玩介面）。
## - Client 的 inhale 呼叫 suck()，exhale／none 呼叫 spit_pressed()／spit_released()。
## - 遊戲結束時改顯示「回到房間」，按下後呼叫 RoomManager.finish_match()，Client 會一起回到等候頁。
##   等 UI-15（ResultScreen 只發 signal）完成後，這個臨時的結束畫面可以拿掉。

const LANE_ACTIONS: Array[StringName] = [&"lane_1", &"lane_2", &"lane_3"]

@export var game_manager: GameManager
@export var dragon: Dragon
@export var keyboard_input: KeyboardInput
@export var voice_action_input: VoiceActionInput
@export var ui_root: UIRoot
## 在畫面左上角顯示 Client 最後送來的動作，確認封包有沒有收到。
@export var show_debug: bool = true

var _remote_action: String = NetworkManager.ACTION_NONE
var _received_count: int = 0
var _debug_label: Label


func _ready() -> void:
	if not _is_host_match():
		set_process_unhandled_input(false)
		return
	_disable_local_action_input()
	if show_debug:
		_build_debug_label()
	NetworkManager.voice_action_received.connect(_on_remote_action)
	game_manager.game_won.connect(_show_end.bind(true))
	game_manager.game_lost.connect(_show_end.bind(false))
	# 等所有子節點（含 UIGameBridge）都 ready 之後再開局，才收得到 game_started。
	game_manager.start_game.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	for i in LANE_ACTIONS.size():
		if event.is_action_pressed(LANE_ACTIONS[i]):
			dragon.set_target_lane(i)
			get_viewport().set_input_as_handled()
			return


func _is_host_match() -> bool:
	return RoomManager.role == RoomManager.Role.HOST and RoomManager.phase == RoomManager.Phase.MATCH


func _disable_local_action_input() -> void:
	keyboard_input.process_mode = Node.PROCESS_MODE_DISABLED
	# 語音吸吐是接 MicInput.action_changed signal，停用節點擋不住，要把連線拆掉。
	voice_action_input.process_mode = Node.PROCESS_MODE_DISABLED
	for connection: Dictionary in MicInput.action_changed.get_connections():
		if (connection["callable"] as Callable).get_object() == voice_action_input:
			MicInput.action_changed.disconnect(connection["callable"])


## Client 的動作改變：inhale 吸一次；exhale 開始吐或噴火，直到換成別的動作才放開。
func _on_remote_action(_peer_id: int, action: String) -> void:
	_received_count += 1
	if _debug_label != null:
		_debug_label.text = "Client 動作：%s（已收到 %d 個封包）" % [action, _received_count]
	if action == _remote_action:
		return
	if _remote_action == NetworkManager.ACTION_EXHALE:
		game_manager.spit_released()
	_remote_action = action
	match action:
		NetworkManager.ACTION_INHALE:
			game_manager.suck()
		NetworkManager.ACTION_EXHALE:
			game_manager.spit_pressed()


func _build_debug_label() -> void:
	var layer := CanvasLayer.new()
	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 40)
	_debug_label.text = "Client 動作：尚未收到封包"
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
