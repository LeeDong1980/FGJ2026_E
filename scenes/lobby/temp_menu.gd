extends Control
## 暫用主選單：等主選單從 game.tscn 的 StartScreen 拆出來（UI-14）後，由正式的 main_menu.tscn 取代。

@onready var _enter_button: Button = %EnterButton
@onready var _quit_button: Button = %QuitButton
@onready var _notice_label: Label = %NoticeLabel


func _ready() -> void:
	_enter_button.pressed.connect(func() -> void: RoomManager.enter_room())
	_quit_button.pressed.connect(get_tree().quit)
	_notice_label.text = RoomManager.notice
	_enter_button.grab_focus.call_deferred()
