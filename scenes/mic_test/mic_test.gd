extends Control
## 麥克風輸入實驗場景：顯示即時音量（RMS，dB）與音高（Hz、音名），可切換輸入裝置。

const BUS_NAME := "MicInput"
const MIN_DB := -60.0
const NOTE_NAMES: PackedStringArray = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

signal syllable_recognized(kind: StringName)

const INHALE := &"inhale"
const EXHALE := &"exhale"
const INHALE_COLOR := Color(1.0, 0.8, 0.1)
const EXHALE_COLOR := Color(0.25, 0.55, 1.0)

## 辨認結果在指示條上停留的秒數
const RESULT_HOLD_SECONDS := 1.5

## 低於此音量不做音高判定（避免環境噪音誤判）
@export var pitch_gate_db: float = -40.0
@export var min_pitch_hz: float = 80.0
@export var max_pitch_hz: float = 1000.0
## 自相關峰值（0~1）低於此值視為沒有明確音高
@export_range(0.0, 1.0) var min_correlation: float = 0.5

## 字音辨認：音量超過 syllable_onset_db 開始一段發音，低於 syllable_offset_db 持續 syllable_release_seconds 就結束
@export var syllable_onset_db: float = -35.0
@export var syllable_offset_db: float = -42.0
@export var syllable_release_seconds: float = 0.12
## 短於此長度的聲音（敲擊、爆音）直接忽略
@export var syllable_min_seconds: float = 0.12
## 零交越率高於此值視為「氣音（嘶）」；吸的主體是氣音，吐的主體是母音
@export_range(0.0, 0.5) var noisy_zcr: float = 0.12
## 氣音佔整段發音的比例：>= inhale_ratio 判為吸，<= exhale_ratio 判為吐，介於兩者之間不輸出
@export_range(0.0, 1.0) var inhale_ratio: float = 0.5
@export_range(0.0, 1.0) var exhale_ratio: float = 0.25

## 音高分析視窗（原始取樣數）與降採樣倍率，降低 GDScript 運算量
const WINDOW_SIZE := 2048
const DOWNSAMPLE := 4

@onready var _device_option: OptionButton = %DeviceOption
@onready var _volume_bar: ProgressBar = %VolumeBar
@onready var _volume_label: Label = %VolumeLabel
@onready var _pitch_bar: ProgressBar = %PitchBar
@onready var _pitch_label: Label = %PitchLabel
@onready var _zcr_bar: ProgressBar = %ZcrBar
@onready var _zcr_label: Label = %ZcrLabel
@onready var _syllable_label: Label = %SyllableLabel
@onready var _inhale_bar: ProgressBar = %InhaleBar
@onready var _exhale_bar: ProgressBar = %ExhaleBar

var _capture: AudioEffectCapture
var _volume_db: float = MIN_DB
var _window: PackedFloat32Array = PackedFloat32Array()
var _pitch_hz: float = 0.0
var _chunk_zcr: float = 0.0
var _chunk_seconds: float = 0.0
## 進行中的一段發音：每個 chunk 記錄 [秒數, 零交越率, 音量 dB]
var _segment: Array[Vector3] = []
var _quiet_seconds: float = 0.0
## 吸／吐指示條的顯示值（0~1）與結果停留倒數
var _inhale_level: float = 0.0
var _exhale_level: float = 0.0
var _hold_seconds: float = 0.0


func _ready() -> void:
	_setup_bus()
	_setup_devices()
	_volume_bar.min_value = MIN_DB
	_volume_bar.max_value = 0.0
	# 音高條用對數刻度（八度），範圍同偵測範圍
	_pitch_bar.min_value = log(min_pitch_hz)
	_pitch_bar.max_value = log(max_pitch_hz)
	_zcr_bar.max_value = 0.5
	_inhale_bar.add_theme_stylebox_override("fill", _make_fill(INHALE_COLOR))
	_exhale_bar.add_theme_stylebox_override("fill", _make_fill(EXHALE_COLOR))


func _process(delta: float) -> void:
	var has_new_chunk: bool = _consume_capture()
	_volume_bar.value = _volume_db
	_volume_label.text = "%.1f dB" % _volume_db

	if _volume_db >= pitch_gate_db and _window.size() >= WINDOW_SIZE:
		_pitch_hz = _detect_pitch_hz()
	else:
		_pitch_hz = 0.0
	if _pitch_hz > 0.0:
		_pitch_bar.value = log(_pitch_hz)
		_pitch_label.text = "%.1f Hz  %s" % [_pitch_hz, _note_name(_pitch_hz)]
	else:
		_pitch_bar.value = _pitch_bar.min_value
		_pitch_label.text = "--"

	_zcr_bar.value = _chunk_zcr
	_zcr_label.text = "ZCR %.3f" % _chunk_zcr
	if has_new_chunk:
		_update_syllable()
	_update_syllable_bars(delta)


## 建立靜音的 MicInput bus，掛 Capture 效果取得原始取樣，並由麥克風串流播放進去。
func _setup_bus() -> void:
	var bus_index: int = AudioServer.get_bus_index(BUS_NAME)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, BUS_NAME)
		AudioServer.add_bus_effect(bus_index, AudioEffectCapture.new())
		AudioServer.set_bus_mute(bus_index, true)
	_capture = AudioServer.get_bus_effect(bus_index, 0) as AudioEffectCapture

	var player := AudioStreamPlayer.new()
	player.stream = AudioStreamMicrophone.new()
	player.bus = BUS_NAME
	add_child(player)
	player.play()


func _setup_devices() -> void:
	var devices: PackedStringArray = AudioServer.get_input_device_list()
	for i in devices.size():
		_device_option.add_item(devices[i], i)
		if devices[i] == AudioServer.input_device:
			_device_option.select(i)
	_device_option.item_selected.connect(_on_device_selected)


func _on_device_selected(index: int) -> void:
	AudioServer.input_device = _device_option.get_item_text(index)


## 取出 capture buffer 內目前所有取樣：更新音量（RMS，dB）並推進音高分析視窗。
func _consume_capture() -> bool:
	var frames: int = _capture.get_frames_available()
	if frames == 0:
		return false
	var buffer: PackedVector2Array = _capture.get_buffer(frames)
	var sum_squares: float = 0.0
	var mono := PackedFloat32Array()
	var crossings: int = 0
	mono.resize(buffer.size())
	for i in buffer.size():
		var sample: float = (buffer[i].x + buffer[i].y) * 0.5
		mono[i] = sample
		if i > 0 and (sample >= 0.0) != (mono[i - 1] >= 0.0):
			crossings += 1
		sum_squares += sample * sample
	_volume_db = maxf(linear_to_db(sqrt(sum_squares / buffer.size())), MIN_DB)
	_chunk_zcr = float(crossings) / buffer.size()
	_chunk_seconds = buffer.size() / AudioServer.get_mix_rate()

	_window.append_array(mono)
	if _window.size() > WINDOW_SIZE:
		_window = _window.slice(_window.size() - WINDOW_SIZE)
	return true


## 自相關法判定音高，回傳 Hz；沒有明確音高時回傳 0。
func _detect_pitch_hz() -> float:
	var rate: float = AudioServer.get_mix_rate() / DOWNSAMPLE
	var count: int = WINDOW_SIZE / DOWNSAMPLE
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var total: float = 0.0
		for j in DOWNSAMPLE:
			total += _window[i * DOWNSAMPLE + j]
		samples[i] = total / DOWNSAMPLE

	var min_lag: int = maxi(int(rate / max_pitch_hz), 2)
	var max_lag: int = mini(int(rate / min_pitch_hz), count / 2)
	var span: int = count - max_lag

	var energy: float = 0.0
	for i in span:
		energy += samples[i] * samples[i]
	if energy <= 0.0:
		return 0.0

	# 正規化自相關：在 [min_lag, max_lag] 找第一個夠高的峰，避免抓到倍頻
	var correlations := PackedFloat32Array()
	correlations.resize(max_lag + 2)
	var best_corr: float = 0.0
	for lag in range(min_lag - 1, max_lag + 2):
		if lag > count - span:
			break
		var sum: float = 0.0
		var lag_energy: float = 0.0
		for i in span:
			sum += samples[i] * samples[i + lag]
			lag_energy += samples[i + lag] * samples[i + lag]
		var denom: float = sqrt(energy * lag_energy)
		var corr: float = sum / denom if denom > 0.0 else 0.0
		correlations[lag] = corr
		if lag >= min_lag and lag <= max_lag:
			best_corr = maxf(best_corr, corr)
	if best_corr < min_correlation:
		return 0.0

	var threshold: float = best_corr * 0.9
	var best_lag: int = -1
	for lag in range(min_lag, max_lag + 1):
		var corr: float = correlations[lag]
		if corr >= threshold and corr >= correlations[lag - 1] and corr >= correlations[lag + 1]:
			best_lag = lag
			break
	if best_lag == -1:
		return 0.0

	# 拋物線內插，取得次取樣精度
	var prev: float = correlations[best_lag - 1]
	var curr: float = correlations[best_lag]
	var next: float = correlations[best_lag + 1]
	var curvature: float = prev - 2.0 * curr + next
	var shift: float = 0.5 * (prev - next) / curvature if curvature != 0.0 else 0.0
	return rate / (best_lag + shift)


func _note_name(hz: float) -> String:
	var midi: int = roundi(69.0 + 12.0 * log(hz / 440.0) / log(2.0))
	return "%s%d" % [NOTE_NAMES[posmod(midi, 12)], midi / 12 - 1]



## 依目前 chunk 推進發音分段：開始、累積、結束時分類。進行中時即時更新指示條。
func _update_syllable() -> void:
	if _segment.is_empty():
		if _volume_db >= syllable_onset_db:
			_segment.append(Vector3(_chunk_seconds, _chunk_zcr, _volume_db))
			_quiet_seconds = 0.0
		else:
			return
	else:
		_segment.append(Vector3(_chunk_seconds, _chunk_zcr, _volume_db))
		if _volume_db < syllable_offset_db:
			_quiet_seconds += _chunk_seconds
		else:
			_quiet_seconds = 0.0
		if _quiet_seconds >= syllable_release_seconds:
			_finish_segment()
			return

	# 進行中：氣音比例越高越偏左（吸），越低越偏右（吐）
	var ratio: float = _segment_stats().x
	_inhale_level = ratio
	_exhale_level = 1.0 - ratio
	_hold_seconds = 0.0


## 目前這段發音的統計，回傳 Vector3(氣音比例, 有效秒數, 峰值 dB)。
## 氣音比例：只看接近峰值（20 dB 以內）的 chunk，高 ZCR 所佔時間比例。
func _segment_stats() -> Vector3:
	var peak_db: float = MIN_DB
	var total_seconds: float = 0.0
	for chunk in _segment:
		peak_db = maxf(peak_db, chunk.z)
		total_seconds += chunk.x
	total_seconds -= _quiet_seconds

	var voiced_seconds: float = 0.0
	var noisy_seconds: float = 0.0
	for chunk in _segment:
		if chunk.z >= peak_db - 20.0:
			voiced_seconds += chunk.x
			if chunk.y >= noisy_zcr:
				noisy_seconds += chunk.x
	var ratio: float = noisy_seconds / voiced_seconds if voiced_seconds > 0.0 else 0.0
	return Vector3(ratio, total_seconds, peak_db)


## 發音結束：分類並輸出 signal，指示條停留在最終結果。
func _finish_segment() -> void:
	var stats: Vector3 = _segment_stats()
	_segment.clear()
	_quiet_seconds = 0.0
	if stats.y < syllable_min_seconds:
		_inhale_level = 0.0
		_exhale_level = 0.0
		return

	var ratio: float = stats.x
	var kind: StringName = &""
	if ratio >= inhale_ratio:
		kind = INHALE
	elif ratio <= exhale_ratio:
		kind = EXHALE
	_syllable_label.text = "%s（氣音比例 %.2f，%.2f 秒）" % [kind if kind != &"" else "unknown", ratio, stats.y]
	_inhale_level = ratio
	_exhale_level = 1.0 - ratio
	_hold_seconds = RESULT_HOLD_SECONDS
	if kind != &"":
		syllable_recognized.emit(kind)


## 更新左（吸，黃）右（吐，藍）指示條；結果停留結束後淡出。
func _update_syllable_bars(delta: float) -> void:
	if _segment.is_empty():
		if _hold_seconds > 0.0:
			_hold_seconds -= delta
		else:
			_inhale_level = move_toward(_inhale_level, 0.0, delta * 2.0)
			_exhale_level = move_toward(_exhale_level, 0.0, delta * 2.0)
	_inhale_bar.value = _inhale_level
	_exhale_bar.value = _exhale_level


func _make_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style
