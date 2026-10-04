extends CanvasLayer
## 暫停選單（autoload）：遊戲中按 Esc 暫停場景並叫出麥克風設定，再按 Esc 或「繼續遊戲」回到遊戲。
## 連線局：Host 暫停會凍結 Host 的遊戲並通知 Client；Client 的 Esc 只疊出設定選單，不凍結，
## Client 仍可繼續回報吸／吐（見 RoomManager.pause_freezes_game）。

## 這次開啟時有沒有凍結遊戲，關閉時才知道要不要通知對方繼續。
var _froze_game: bool = false

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
	_froze_game = RoomManager.pause_freezes_game()
	if _froze_game:
		get_tree().paused = true
		NetworkManager.send_pause_state(true)


func close() -> void:
	visible = false
	_panel.process_mode = Node.PROCESS_MODE_DISABLED
	if _froze_game:
		_froze_game = false
		get_tree().paused = false
		NetworkManager.send_pause_state(false)
	MicInput.save_settings()
