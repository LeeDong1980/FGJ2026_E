class_name ClientPlay
extends Control
## Client 的遊玩畫面（玩家 B：吸／吐）。不執行遊戲邏輯，只把吸／吐動作的開始與結束傳給 Host。
## 動作來源：麥克風（MicInput.inhale／exhale，受「吸／吐」語音開關控制）與鍵盤 J（吸）、K（吐，按住）。
## Host 端收 NetworkManager.voice_action_received（ACTION_INHALE／ACTION_EXHALE／ACTION_NONE）。

const ACTION_TEXT: Dictionary = {
	NetworkManager.ACTION_NONE: "—",
	NetworkManager.ACTION_INHALE: "吸",
	NetworkManager.ACTION_EXHALE: "吐",
}

@onready var _action_label: Label = %ActionLabel
@onready var _volume_bar: ProgressBar = %VolumeBar
@onready var _voice_toggle: CheckButton = %VoiceToggle
@onready var _mic_label: Label = %MicLabel
@onready var _net_label: Label = %NetLabel
@onready var _leave_button: Button = %LeaveButton

var _sent_action: String = NetworkManager.ACTION_NONE


func _ready() -> void:
	# 暫停選單開著時也要持續回報，否則 Host 會一直收不到「放開」。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_leave_button.pressed.connect(RoomManager.leave_room)
	_voice_toggle.button_pressed = MicInput.action_input_enabled
	_voice_toggle.toggled.connect(func(on: bool) -> void: MicInput.action_input_enabled = on)
	_show_action(_sent_action)


func _process(_delta: float) -> void:
	_update_action()
	_volume_bar.value = MicInput.volume_value
	_mic_label.text = _mic_text()
	_net_label.text = _net_text()


func _exit_tree() -> void:
	MicInput.save_settings()
	NetworkManager.send_voice_action(NetworkManager.ACTION_NONE)


## 鍵盤優先於麥克風；吐優先於吸。動作改變時才送封包。
func _update_action() -> void:
	var action: String = NetworkManager.ACTION_NONE
	if not get_tree().paused:
		action = _keyboard_action()
		if action == NetworkManager.ACTION_NONE:
			action = _mic_action()
	if action == _sent_action:
		return
	_sent_action = action
	NetworkManager.send_voice_action(action)
	_show_action(action)


func _keyboard_action() -> String:
	if Input.is_action_pressed(&"spit"):
		return NetworkManager.ACTION_EXHALE
	if Input.is_action_pressed(&"suck"):
		return NetworkManager.ACTION_INHALE
	return NetworkManager.ACTION_NONE


func _mic_action() -> String:
	if not MicInput.action_input_enabled:
		return NetworkManager.ACTION_NONE
	match MicInput.action:
		MicController.INHALE:
			return NetworkManager.ACTION_INHALE
		MicController.EXHALE:
			return NetworkManager.ACTION_EXHALE
	return NetworkManager.ACTION_NONE


func _show_action(action: String) -> void:
	_action_label.text = ACTION_TEXT.get(action, "—")


func _mic_text() -> String:
	if not MicInput.action_input_enabled:
		return "語音吸／吐已關閉，請打開上方開關，或用鍵盤 J／K"
	match MicInput.mic_status:
		MicController.MicStatus.NO_SIGNAL:
			return "麥克風沒有訊號，請按 Esc 開設定重新偵測，或用鍵盤 J／K"
		MicController.MicStatus.DISABLED:
			return "麥克風已停用，請用鍵盤 J／K"
	return "麥克風收音中"


func _net_text() -> String:
	var rtt: float = NetworkManager.get_rtt_msec()
	return "與房主的網路延遲：%s" % (("%d ms" % int(rtt)) if rtt >= 0.0 else "—")
