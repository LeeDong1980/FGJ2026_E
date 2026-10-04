class_name MainMenu
extends Control
## 主選單：「進入遊戲」在區網自動開房並進入等候頁，單機或連線在等候頁選（docs/lobby-flow.md）。
## 換場景一律交給 RoomManager，這裡不自己換場景。

@onready var _start_button: Button = %StartButton
@onready var _quit_button: Button = %QuitButton
@onready var _audio_button: Button = %AudioButton
@onready var _audio_overlay: Control = %AudioOverlay
@onready var _audio_panel: AudioSettingsPanel = %AudioSettingsPanel
@onready var _notice_label: Label = %NoticeLabel


func _ready() -> void:
	_start_button.pressed.connect(func() -> void: RoomManager.enter_room())
	_quit_button.pressed.connect(get_tree().quit)
	_audio_button.pressed.connect(_open_audio_settings)
	_audio_panel.close_requested.connect(_close_audio_settings)
	# 對方關閉房間等提示
	_notice_label.text = RoomManager.notice
	_notice_label.visible = not RoomManager.notice.is_empty()
	_start_button.grab_focus.call_deferred()


## 音量視窗開著時，Esc 只關掉視窗，不叫出暫停選單。
func _unhandled_input(event: InputEvent) -> void:
	if _audio_overlay.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_audio_settings()


func _open_audio_settings() -> void:
	_audio_overlay.visible = true
	Sound.play(&"open")
	_audio_panel.focus_first_slider()


func _close_audio_settings() -> void:
	_audio_overlay.visible = false
	Sound.play(&"close")
	_audio_button.grab_focus()
