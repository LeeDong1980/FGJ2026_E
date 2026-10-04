class_name ClientPlay
extends Control
## Client 的遊玩畫面。不執行遊戲邏輯，依座位（等候頁決定，RoomManager.get_my_slot）回報輸入給 Host：
## - 玩家 1（音高換層、換元素）：麥克風音高換成層，傳給 Host 控制龍（PlayerPitchInput）；
##   換元素是大叫（音量超過 ShoutDetector 門檻）或鍵盤 4，送字音 WORD_ELEMENT。
## - 玩家 2（吸／吐、轉頭）：麥克風與鍵盤 J（吸）、K（吐，按住）的動作傳給 Host（PlayerActionInput）；
##   轉頭是鍵盤 L，送字音 WORD_TURN。
## Host 端由 NetworkGameBridge 接收（voice_action_received、voice_word_received、pitch_received），座位決定接哪一種。

const LANE_COUNT: int = 3
const ACTION_TEXT: Dictionary = {
	NetworkManager.ACTION_NONE: "—",
	NetworkManager.ACTION_INHALE: "吸",
	NetworkManager.ACTION_EXHALE: "吐",
}

@onready var _title_label: Label = %Title
@onready var _hint_label: Label = %Hint
@onready var _pitch_box: Control = %PitchBox
@onready var _pitch_meter: VolumeMeter = %PitchMeter
@onready var _action_label: Label = %ActionLabel
@onready var _volume_bar: ProgressBar = %VolumeBar
@onready var _voice_toggle: CheckButton = %VoiceToggle
@onready var _mic_label: Label = %MicLabel
@onready var _debug_label: Label = %DebugLabel
@onready var _paused_label: Label = %PausedLabel
@onready var _net_label: Label = %NetLabel
@onready var _leave_button: Button = %LeaveButton

var _slot: int = 2
var _pitch_input: PlayerPitchInput
var _action_input: PlayerActionInput
var _sent_count: int = 0
var _ack_count: int = 0
var _timeout_count: int = 0
var _shout := ShoutDetector.new()


func _ready() -> void:
	# 暫停選單開著時也要持續回報，否則 Host 會一直收不到「放開」。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_slot = RoomManager.get_my_slot()
	_leave_button.pressed.connect(RoomManager.leave_room)
	NetworkManager.host_pause_changed.connect(func(paused: bool) -> void: _paused_label.visible = paused)
	if _slot == 1:
		_setup_player1()
	else:
		_setup_player2()


func _process(delta: float) -> void:
	if _slot == 1:
		_pitch_meter.level = _pitch_input.level
		_pitch_meter.current_lane = _pitch_input.lane if _pitch_input.controls_dragon else -1
		_pitch_meter.modulate.a = 1.0 if _pitch_input.controls_dragon else 0.45
		_update_element(delta)
	else:
		_update_turn()
		_volume_bar.value = MicInput.volume_value
	_mic_label.text = _mic_text()
	_debug_label.text = _debug_text()
	_net_label.text = _net_text()


func _exit_tree() -> void:
	MicInput.save_settings()


# ---- 玩家 1：音高換層 ----

func _setup_player1() -> void:
	_title_label.text = "你是玩家 1｜高度、火／冰"
	_hint_label.text = "遊戲畫面在房主的電腦上。對麥克風發出高低音控制龍的高度：低音飛低、高音飛高。大叫或按 4 切換火／冰。"
	_pitch_box.visible = true
	_action_label.visible = false
	_volume_bar.visible = false
	_voice_toggle.text = "音高輸入"
	_voice_toggle.button_pressed = MicInput.pitch_input_enabled
	_voice_toggle.toggled.connect(func(on: bool) -> void: MicInput.pitch_input_enabled = on)
	_pitch_meter.thresholds = _even_thresholds(LANE_COUNT)
	# 音高與層由共用元件量好並傳給 Host（層改變時立刻送，平時每秒約 15 次）
	_pitch_input = PlayerPitchInput.new()
	_pitch_input.send_to_peer = true
	add_child(_pitch_input)


func _even_thresholds(lane_count: int) -> PackedFloat32Array:
	var thresholds := PackedFloat32Array()
	for i in range(1, lane_count):
		thresholds.append(float(i) / lane_count)
	return thresholds


# ---- 玩家 2：吸／吐 ----

func _setup_player2() -> void:
	_title_label.text = "你是玩家 2｜吸 / 吐"
	_hint_label.text = "遊戲畫面在房主的電腦上。對麥克風喊「吸」「吐」，或按 J（吸）、K（吐，按住）；按 L 轉頭。"
	_voice_toggle.button_pressed = MicInput.action_input_enabled
	_voice_toggle.toggled.connect(func(on: bool) -> void: MicInput.action_input_enabled = on)
	NetworkManager.voice_ack_received.connect(_on_ack_received)
	NetworkManager.voice_ack_timeout.connect(_on_ack_timeout)
	# 吸／吐的本機輸入（鍵盤與語音）交給共用元件，動作改變時它會自己送給 Host。
	_action_input = PlayerActionInput.new()
	_action_input.send_to_peer = true
	_action_input.action_changed.connect(_on_action_changed)
	add_child(_action_input)
	_show_action(NetworkManager.ACTION_NONE)


func _on_action_changed(action: String) -> void:
	_sent_count += 1
	_show_action(action)


## 玩家 2：按 L 時送出轉頭。
func _update_turn() -> void:
	if not get_tree().paused and Input.is_action_just_pressed(&"turn_head"):
		NetworkManager.send_voice_word(NetworkManager.WORD_TURN)


## 玩家 1：大叫或按 4 時送出換元素。
func _update_element(delta: float) -> void:
	_shout.threshold = MicInput.shout_threshold
	_shout.release = MicInput.shout_release
	var shouted := _shout.update(MicInput.volume_value, delta)
	if get_tree().paused:
		return
	if shouted or Input.is_action_just_pressed(&"toggle_element"):
		NetworkManager.send_voice_word(NetworkManager.WORD_ELEMENT)


func _on_ack_received(kind: String, _seq: int, _rtt_msec: int) -> void:
	if kind == NetworkManager.KIND_ACTION:
		_ack_count += 1


func _on_ack_timeout(kind: String, _seq: int) -> void:
	if kind == NetworkManager.KIND_ACTION:
		_timeout_count += 1


func _show_action(action: String) -> void:
	_action_label.text = ACTION_TEXT.get(action, "—")


# ---- 狀態文字 ----

func _mic_text() -> String:
	var enabled: bool = MicInput.pitch_input_enabled if _slot == 1 else MicInput.action_input_enabled
	if not enabled:
		return "%s已關閉，請打開上方開關%s" % ["音高輸入" if _slot == 1 else "語音吸／吐", "" if _slot == 1 else "，或用鍵盤 J／K"]
	match MicInput.mic_status:
		MicController.MicStatus.NO_SIGNAL:
			return "麥克風沒有訊號，請按 Esc 開設定重新偵測" + ("" if _slot == 1 else "，或用鍵盤 J／K")
		MicController.MicStatus.DISABLED:
			return "麥克風已停用" + ("" if _slot == 1 else "，請用鍵盤 J／K")
	return "麥克風收音中"


func _net_text() -> String:
	var rtt: float = NetworkManager.get_rtt_msec()
	var latency: String = ("%d ms" % int(rtt)) if rtt >= 0.0 else "—"
	if _slot == 1:
		return "與房主的網路延遲：%s" % latency
	return "與房主的網路延遲：%s\n動作封包：已送出 %d、Host 已確認 %d、沒收到確認 %d" % [
		latency, _sent_count, _ack_count, _timeout_count]


## 【暫時的診斷顯示】語音參數調好（MIC-07）後可移除，連同 .tscn 的 DebugLabel 與動作封包統計。
## 玩家 1：音高與層。玩家 2：麥克風判定的每一關，語音沒反應時看哪一關沒過：
## 音量要超過閥值 → 氣音落在吸區（<= 吸上限）或吐區（>= 吐下限）→ 持續夠久才輸出動作。
func _debug_text() -> String:
	if _slot == 1:
		return "音高 %.0f Hz（%.0f／100）%s → 目前層 %d" % [
			MicInput.pitch_hz, MicInput.pitch_value, "" if MicInput.pitch_active else "（無音高）", _pitch_input.lane + 1]
	var gate_ok: bool = MicInput.volume_db >= MicInput.action_gate_db
	return "音量 %.0f dB（閥值 %.0f dB，%s）\n氣音 %.0f（吸區 ≤ %.0f，吐區 ≥ %.0f）\n麥克風判定：%s" % [
		MicInput.volume_db, MicInput.action_gate_db, "已過" if gate_ok else "未過",
		MicInput.voicedness, MicInput.inhale_max, MicInput.exhale_min,
		str(MicInput.action) if MicInput.action != &"" else "—"]
