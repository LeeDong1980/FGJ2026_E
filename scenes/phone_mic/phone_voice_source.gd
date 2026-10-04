class_name PhoneVoiceSource
extends Node
## 一支手機的聲音輸出：欄位與 signal 和 MicInput 相同（volume_*、pitch_*、voicedness、action、last_action、action_changed），
## 遊戲橋接可以直接拿來取代 MicInput。由 PhoneMic（autoload/phone_mic_server.gd）建立，用 PhoneMic.get_source(1 或 2) 取得。
##
## 手機已經算好原始量（dB、零交越率、Hz），這裡只做換算、按住與吸／吐判定。
## 所有區間與閥值直接讀 MicInput 的設定，暫停選單調的數值對手機一樣有效。
## 判定邏輯對應 autoload/mic_controller.gd 的 _on_chunk() 與 _update_outputs()，改那邊時這裡也要跟著改。

signal action_changed(action: StringName)

## 超過這麼久沒收到手機的聲音，就當作沒有聲音（斷線、網路卡住）
const STALE_SECONDS := 0.25

var volume_db: float = MicController.MIN_DB
var volume_value: float = 0.0
var volume_active: bool = false
var pitch_hz: float = 0.0
var pitch_value: float = 0.0
var pitch_active: bool = false
var voicedness: float = 100.0
var action: StringName = &""
var last_action: StringName = &""

var _raw_hz: float = 0.0
var _since_sample: float = INF
var _volume_hold := MicController.HoldGate.new()
var _pitch_hold := MicController.HoldGate.new()
var _action_hold := MicController.HoldGate.new()
var _noisy_ema: float = 0.0
var _since_loud: float = INF
var _zone: StringName = &""
var _zone_seconds: float = 0.0
var _lock: StringName = &""
var _wanted: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## 收到手機的一段聲音（PhoneMic 呼叫）。
func push_sample(db: float, zcr: float, hz: float, seconds: float) -> void:
	volume_db = db
	_raw_hz = hz
	_since_sample = 0.0
	_on_chunk(zcr, db, seconds)


## 斷線時清空，放開按住中的動作。
func reset() -> void:
	volume_db = MicController.MIN_DB
	_raw_hz = 0.0
	_wanted = &""
	_set_action(&"")


func _process(delta: float) -> void:
	_since_sample += delta
	if _since_sample > STALE_SECONDS:
		volume_db = MicController.MIN_DB
		_raw_hz = 0.0
		_wanted = &""
	_update_outputs(delta)


func _on_chunk(zcr: float, db: float, seconds: float) -> void:
	if db < MicInput.action_gate_db:
		_zone = &""
		_zone_seconds = 0.0
		_wanted = &""
		return

	if _since_loud > MicInput.segment_gap_seconds:
		# 新的一次發音：從「母音」起算，開頭的爆音不會直接落進吸區
		_noisy_ema = 0.0
		_lock = &""
	_since_loud = 0.0

	var noisy: float = 1.0 if zcr >= MicInput.noisy_zcr else 0.0
	_noisy_ema += (noisy - _noisy_ema) * (1.0 - exp(-seconds / maxf(MicInput.analysis_seconds, 0.001)))
	voicedness = (1.0 - _noisy_ema) * 100.0

	var zone: StringName = &""
	if voicedness <= MicInput.inhale_max:
		zone = MicController.INHALE
	elif voicedness >= MicInput.exhale_min:
		zone = MicController.EXHALE
	if zone == _zone:
		_zone_seconds += seconds
	else:
		_zone = zone
		_zone_seconds = seconds

	var qualifies: bool = zone != &"" and (
		zone == action
		or (_zone_seconds >= MicInput.action_min_seconds and (_lock == &"" or _lock == zone))
	)
	_wanted = zone if qualifies else &""


func _update_outputs(delta: float) -> void:
	_since_loud += delta

	var volume_present: bool = volume_db >= MicInput.volume_min_db
	if volume_present:
		volume_value = _to_percent(volume_db, MicInput.volume_min_db, MicInput.volume_max_db)
	_volume_hold.update(volume_present, MicInput.volume_release_seconds, delta)
	volume_active = _volume_hold.active

	pitch_hz = _raw_hz if volume_db >= MicInput.pitch_gate_db else 0.0
	if pitch_hz > 0.0:
		pitch_value = _to_percent(log(pitch_hz), log(MicInput.pitch_min_hz), log(MicInput.pitch_max_hz))
	_pitch_hold.update(pitch_hz > 0.0, MicInput.pitch_release_seconds, delta)
	pitch_active = _pitch_hold.active

	if _wanted != &"" and _wanted != action:
		_lock = _wanted
		_set_action(_wanted)
	_action_hold.update(_wanted != &"", MicInput.action_release_seconds, delta)
	if not _action_hold.active and action != &"":
		_set_action(&"")


func _set_action(new_action: StringName) -> void:
	if new_action == action:
		return
	action = new_action
	if action != &"":
		last_action = action
	action_changed.emit(action)


func _to_percent(value: float, from: float, to: float) -> float:
	return clampf(inverse_lerp(from, to, value), 0.0, 1.0) * 100.0
