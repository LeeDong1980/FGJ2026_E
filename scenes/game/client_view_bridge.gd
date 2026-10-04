class_name ClientViewBridge
extends Node
## Client 端的畫面同步橋接（NET-19）：連線局的 Client 載入同一個遊戲場景，但 GameManager 是副本（GameManager.replica），
## 由 GameStateReceiver 接收 Host 的狀態，畫面元件不用改就顯示一樣的畫面。只在副本模式啟用。
##
## 啟用時：
## - 停用本機所有遊戲輸入（鍵盤、音高換層、語音吸吐、大叫換元素）。Client 的輸入由輸入診斷疊層（client_play）依座位送給 Host。
## - 建立 GameStateReceiver 接收狀態。
## - 輸入診斷疊層（client_play.tscn）預設隱藏，按 F3 顯示或隱藏；語音調參數時用得到。
## - 房主暫停時凍結遊戲畫面並顯示「房主已暫停」；Client 自己的 Esc 只疊出設定選單，不凍結。
## - 遊戲結束時顯示成功／失敗，等房主按「回到房間」。

const CLIENT_PLAY_SCENE: PackedScene = preload("res://scenes/game/client_play.tscn")
const TOGGLE_KEY: Key = KEY_F3

@export var game_manager: GameManager
@export var dragon: Dragon
@export var keyboard_input: KeyboardInput
@export var voice_action_input: VoiceActionInput
@export var pitch_lane_input: PitchLaneInput
@export var shout_element_input: ShoutElementInput
@export var ui_root: UIRoot
@export var ui_bridge: UIGameBridge

var _overlay: Control
var _pause_banner: Label


func _ready() -> void:
	# GameManager 的 _ready 在子節點之後才跑，所以這裡看靜態旗標，不看 game_manager.replica
	if not GameManager.replica_mode:
		set_process_unhandled_input(false)
		return
	# 房主暫停時凍結 GameManager 底下整個畫面，本節點與疊層要繼續運作
	process_mode = Node.PROCESS_MODE_ALWAYS
	_disable_local_inputs()
	var receiver := GameStateReceiver.new()
	receiver.game_manager = game_manager
	receiver.dragon = dragon
	receiver.ui_bridge = ui_bridge
	add_child(receiver)
	_build_overlay()
	_build_pause_banner()
	NetworkManager.host_pause_changed.connect(_on_host_pause_changed)
	game_manager.game_won.connect(_show_end.bind(true))
	game_manager.game_lost.connect(_show_end.bind(false))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
		_overlay.visible = not _overlay.visible
		get_viewport().set_input_as_handled()


func _disable_local_inputs() -> void:
	keyboard_input.process_mode = Node.PROCESS_MODE_DISABLED
	voice_action_input.process_mode = Node.PROCESS_MODE_DISABLED
	shout_element_input.process_mode = Node.PROCESS_MODE_DISABLED
	# 音高換層會直接改本機龍的目標層，副本不能自己動
	pitch_lane_input.queue_free()


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_overlay = CLIENT_PLAY_SCENE.instantiate() as Control
	_overlay.visible = false
	layer.add_child(_overlay)


func _build_pause_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	_pause_banner = Label.new()
	_pause_banner.text = "房主已暫停遊戲"
	_pause_banner.visible = false
	_pause_banner.add_theme_font_size_override("font_size", 64)
	_pause_banner.add_theme_constant_override("outline_size", 16)
	_pause_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_pause_banner.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	_pause_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(_pause_banner)
	add_child(layer)


func _on_host_pause_changed(paused: bool) -> void:
	game_manager.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	_pause_banner.visible = paused


func _show_end(won: bool) -> void:
	# UIGameBridge 先顯示了它的結果畫面（按鈕會讓 Client 離開房間），這裡換成等房主的版本
	ui_root.hide_all()
	var layer := CanvasLayer.new()
	layer.layer = 70
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

	var wait := Label.new()
	wait.text = "等待房主回到房間…"
	wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(wait)

	var leave := Button.new()
	leave.text = "離開房間"
	leave.pressed.connect(RoomManager.leave_room)
	box.add_child(leave)
	add_child(layer)
