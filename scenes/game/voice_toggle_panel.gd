class_name VoiceTogglePanel
extends CanvasLayer
## 左下角的語音輸入開關：「音高」控制換層、「吸／吐」控制語音吸吐。
## 狀態存在 MicInput（pitch_input_enabled、action_input_enabled），會隨 MicInput 設定存檔。


func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(box)

	_add_toggle(box, "音高（換層，低／中／高音 = 1／2／3）", MicInput.pitch_input_enabled,
		func(on: bool) -> void: MicInput.pitch_input_enabled = on)
	_add_toggle(box, "吸／吐（語音）", MicInput.action_input_enabled,
		func(on: bool) -> void: MicInput.action_input_enabled = on)


func _exit_tree() -> void:
	MicInput.save_settings()


func _add_toggle(parent: Control, text: String, initial: bool, on_toggled: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = initial
	# 不拿焦點，避免 Enter（開始遊戲）被按鈕吃掉
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(on_toggled)
	parent.add_child(toggle)
