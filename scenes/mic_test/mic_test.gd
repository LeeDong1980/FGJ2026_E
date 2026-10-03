extends Control
## 麥克風輸入實驗場景：顯示即時音量（RMS，dB）與音高（Hz、音名），可切換輸入裝置。

const BUS_NAME := "MicInput"
const MIN_DB := -60.0
const NOTE_NAMES: PackedStringArray = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

## 低於此音量不做音高判定（避免環境噪音誤判）
@export var pitch_gate_db: float = -40.0
@export var min_pitch_hz: float = 80.0
@export var max_pitch_hz: float = 1000.0
## 自相關峰值（0~1）低於此值視為沒有明確音高
@export_range(0.0, 1.0) var min_correlation: float = 0.5

## 音高分析視窗（原始取樣數）與降採樣倍率，降低 GDScript 運算量
const WINDOW_SIZE := 2048
const DOWNSAMPLE := 4

@onready var _device_option: OptionButton = %DeviceOption
@onready var _volume_bar: ProgressBar = %VolumeBar
@onready var _volume_label: Label = %VolumeLabel
@onready var _pitch_bar: ProgressBar = %PitchBar
@onready var _pitch_label: Label = %PitchLabel

var _capture: AudioEffectCapture
var _volume_db: float = MIN_DB
var _window: PackedFloat32Array = PackedFloat32Array()
var _pitch_hz: float = 0.0


func _ready() -> void:
	_setup_bus()
	_setup_devices()
	_volume_bar.min_value = MIN_DB
	_volume_bar.max_value = 0.0
	# 音高條用對數刻度（八度），範圍同偵測範圍
	_pitch_bar.min_value = log(min_pitch_hz)
	_pitch_bar.max_value = log(max_pitch_hz)


func _process(_delta: float) -> void:
	_consume_capture()
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
func _consume_capture() -> void:
	var frames: int = _capture.get_frames_available()
	if frames == 0:
		return
	var buffer: PackedVector2Array = _capture.get_buffer(frames)
	var sum_squares: float = 0.0
	var mono := PackedFloat32Array()
	mono.resize(buffer.size())
	for i in buffer.size():
		var sample: float = (buffer[i].x + buffer[i].y) * 0.5
		mono[i] = sample
		sum_squares += sample * sample
	_volume_db = maxf(linear_to_db(sqrt(sum_squares / buffer.size())), MIN_DB)

	_window.append_array(mono)
	if _window.size() > WINDOW_SIZE:
		_window = _window.slice(_window.size() - WINDOW_SIZE)


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
