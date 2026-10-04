class_name MainMenu
extends Control
## 主選單：只發 signal，不自己換場景；由 SceneFlow（之後換成 Samuel 的流程控制器）決定下一步。
## 「多人」等房間等候頁（room_lobby.tscn）完成後才開放。

signal start_requested
signal multiplayer_requested
signal quit_requested

@onready var _start_button: Button = %StartButton
@onready var _multiplayer_button: Button = %MultiplayerButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_start_button.pressed.connect(start_requested.emit)
	_multiplayer_button.pressed.connect(multiplayer_requested.emit)
	_quit_button.pressed.connect(quit_requested.emit)
	_start_button.grab_focus.call_deferred()
