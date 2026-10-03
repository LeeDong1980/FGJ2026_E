extends Control
## 麥克風輸入實驗場景：顯示即時音量（RMS，dB），可切換輸入裝置。

const BUS_NAME := "MicInput"
const MIN_DB := -60.0

@onready var _device_option: OptionButton = %DeviceOption
@onready var _volume_bar: ProgressBar = %VolumeBar
@onready var _volume_label: Label = %VolumeLabel

var _capture: AudioEffectCapture
var _volume_db: float = MIN_DB


func _ready() -> void:
	_setup_bus()
	_setup_devices()
	_volume_bar.min_value = MIN_DB
	_volume_bar.max_value = 0.0


func _process(_delta: float) -> void:
	_volume_db = _read_volume_db()
	_volume_bar.value = _volume_db
	_volume_label.text = "%.1f dB" % _volume_db


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


## 取出 capture buffer 內目前所有取樣，回傳 RMS 音量（dB）。
func _read_volume_db() -> float:
	var frames: int = _capture.get_frames_available()
	if frames == 0:
		return _volume_db
	var buffer: PackedVector2Array = _capture.get_buffer(frames)
	var sum_squares: float = 0.0
	for frame in buffer:
		var mono: float = (frame.x + frame.y) * 0.5
		sum_squares += mono * mono
	var rms: float = sqrt(sum_squares / buffer.size())
	return maxf(linear_to_db(rms), MIN_DB)
