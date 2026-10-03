class_name StartScreen
extends Control
## 遊戲開始介面。按下「開始遊戲」時發出 start_pressed，由遊戲流程校正聲音並開始遊玩。

signal start_pressed

@onready var _start_button: Button = %StartButton


func _ready() -> void:
	_start_button.pressed.connect(start_pressed.emit)
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_start_button.grab_focus.call_deferred()
