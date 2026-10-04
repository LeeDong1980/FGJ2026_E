class_name MainMenu
extends Control
## 主選單：「進入遊戲」在區網自動開房並進入等候頁，單機或連線在等候頁選（docs/lobby-flow.md）。
## 換場景一律交給 RoomManager，這裡不自己換場景。

@onready var _start_button: Button = %StartButton
@onready var _quit_button: Button = %QuitButton
@onready var _notice_label: Label = %NoticeLabel


func _ready() -> void:
	_start_button.pressed.connect(func() -> void: RoomManager.enter_room())
	_quit_button.pressed.connect(get_tree().quit)
	# 對方關閉房間等提示
	_notice_label.text = RoomManager.notice
	_notice_label.visible = not RoomManager.notice.is_empty()
	_start_button.grab_focus.call_deferred()
