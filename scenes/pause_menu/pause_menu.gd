extends CanvasLayer
## 暫停選單（autoload）：遊戲中按 Esc 暫停場景並叫出麥克風設定，再按 Esc 或「繼續遊戲」回到遊戲。

@onready var _panel: Control = %MicSettingsPanel


func _ready() -> void:
	visible = false
	_panel.process_mode = Node.PROCESS_MODE_DISABLED
	_panel.close_requested.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()


func open() -> void:
	visible = true
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


func close() -> void:
	visible = false
	_panel.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = false
	MicInput.save_settings()
