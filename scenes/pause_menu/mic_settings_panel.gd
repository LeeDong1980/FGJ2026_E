extends Control
## 麥克風設定面板：左邊觀察與設定音量、音高、吸／吐的區間，右邊顯示全域控制器（MicInput）的輸出結果。
## 暫停選單與 mic_test 場景共用這個面板。

signal close_requested

## 顯示「繼續遊戲」按鈕（暫停選單使用）
@export var show_close_button: bool = false

const INHALE_COLOR := Color(1.0, 0.8, 0.1)
const EXHALE_COLOR := Color(0.25, 0.55, 1.0)
const VOLUME_COLOR := Color(0.3, 0.7, 0.4)
const PITCH_COLOR := Color(0.65, 0.5, 0.85)
## 音高軸的範圍（Hz），軸本身用對數刻度
const PITCH_AXIS_MIN_HZ := 70.0
const PITCH_AXIS_MAX_HZ := 1000.0
## 沒有按住時輸出條的透明度
const INACTIVE_ALPHA := 0.35

@onready var _controller: MicController = MicInput
@onready var _close_button: Button = %CloseButton
@onready var _device_option: OptionButton = %DeviceOption

@onready var _volume_title: Label = %VolumeTitle
@onready var _volume_meter: RangeMeter = %VolumeMeter
@onready var _volume_hold: HSlider = %VolumeHold
@onready var _volume_hold_label: Label = %VolumeHoldLabel
@onready var _pitch_title: Label = %PitchTitle
@onready var _pitch_meter: RangeMeter = %PitchMeter
@onready var _pitch_hold: HSlider = %PitchHold
@onready var _pitch_hold_label: Label = %PitchHoldLabel
@onready var _gate_title: Label = %GateTitle
@onready var _gate_meter: RangeMeter = %GateMeter
@onready var _zone_title: Label = %ZoneTitle
@onready var _zone_meter: RangeMeter = %ZoneMeter
@onready var _zone_hold: HSlider = %ZoneHold
@onready var _zone_hold_label: Label = %ZoneHoldLabel

@onready var _volume_out_label: Label = %VolumeOutLabel
@onready var _volume_out_bar: ProgressBar = %VolumeOutBar
@onready var _pitch_out_label: Label = %PitchOutLabel
@onready var _pitch_out_bar: ProgressBar = %PitchOutBar
@onready var _action_out_label: Label = %ActionOutLabel
@onready var _inhale_bar: ProgressBar = %InhaleBar
@onready var _exhale_bar: ProgressBar = %ExhaleBar


func _ready() -> void:
	_close_button.visible = show_close_button
	_close_button.pressed.connect(close_requested.emit)
	_setup_devices()
	_setup_meters()
	_setup_hold_sliders()
	_setup_output_bars()


func _exit_tree() -> void:
	_controller.save_settings()


func _process(_delta: float) -> void:
	_update_meters()
	_update_outputs()


func _setup_devices() -> void:
	var devices: PackedStringArray = AudioServer.get_input_device_list()
	for i in devices.size():
		_device_option.add_item(devices[i], i)
		if devices[i] == AudioServer.input_device:
			_device_option.select(i)
	_device_option.item_selected.connect(_on_device_selected)


func _on_device_selected(index: int) -> void:
	AudioServer.input_device = _device_option.get_item_text(index)


## 把控制器目前的設定灌進把手，並把拖曳結果寫回控制器。
func _setup_meters() -> void:
	_volume_meter.low = _controller.volume_min_db
	_volume_meter.high = _controller.volume_max_db
	_volume_meter.label_formatter = _format_db
	_volume_meter.range_changed.connect(func(low: float, high: float) -> void:
		_controller.volume_min_db = low
		_controller.volume_max_db = high)

	_pitch_meter.min_axis = log(PITCH_AXIS_MIN_HZ)
	_pitch_meter.max_axis = log(PITCH_AXIS_MAX_HZ)
	_pitch_meter.low = log(_controller.pitch_min_hz)
	_pitch_meter.high = log(_controller.pitch_max_hz)
	_pitch_meter.label_formatter = func(value: float) -> String: return "%.0f Hz" % exp(value)
	_pitch_meter.range_changed.connect(func(low: float, high: float) -> void:
		_controller.pitch_min_hz = exp(low)
		_controller.pitch_max_hz = exp(high))

	_gate_meter.low = _controller.action_gate_db
	_gate_meter.label_formatter = _format_db
	_gate_meter.range_changed.connect(func(low: float, _high: float) -> void:
		_controller.action_gate_db = low)

	_zone_meter.low = _controller.inhale_max
	_zone_meter.high = _controller.exhale_min
	_zone_meter.range_changed.connect(func(low: float, high: float) -> void:
		_controller.inhale_max = low
		_controller.exhale_min = high)


func _setup_hold_sliders() -> void:
	_bind_hold_slider(_volume_hold, _volume_hold_label, _controller.volume_release_seconds,
			func(value: float) -> void: _controller.volume_release_seconds = value)
	_bind_hold_slider(_pitch_hold, _pitch_hold_label, _controller.pitch_release_seconds,
			func(value: float) -> void: _controller.pitch_release_seconds = value)
	_bind_hold_slider(_zone_hold, _zone_hold_label, _controller.action_release_seconds,
			func(value: float) -> void: _controller.action_release_seconds = value)


func _bind_hold_slider(slider: HSlider, label: Label, initial: float, apply: Callable) -> void:
	slider.value = initial
	label.text = "%.2f 秒" % initial
	slider.value_changed.connect(func(value: float) -> void:
		label.text = "%.2f 秒" % value
		apply.call(value))


func _setup_output_bars() -> void:
	_volume_out_bar.max_value = 100.0
	_pitch_out_bar.max_value = 100.0
	_volume_out_bar.add_theme_stylebox_override("fill", _make_fill(VOLUME_COLOR))
	_pitch_out_bar.add_theme_stylebox_override("fill", _make_fill(PITCH_COLOR))
	_inhale_bar.add_theme_stylebox_override("fill", _make_fill(INHALE_COLOR))
	_exhale_bar.add_theme_stylebox_override("fill", _make_fill(EXHALE_COLOR))


## 左邊：即時值（白線）與讀數。
func _update_meters() -> void:
	var c: MicController = _controller
	var volume_live: bool = c.volume_db >= c.volume_min_db
	_volume_meter.live_value = c.volume_db
	_volume_meter.live_active = volume_live
	_volume_title.text = "音量　現在 %.1f dB　（小聲 %.0f ～ 大聲 %.0f dB）" % [c.volume_db, c.volume_min_db, c.volume_max_db]

	_pitch_meter.live_value = log(c.pitch_hz) if c.pitch_hz > 0.0 else _pitch_meter.min_axis
	_pitch_meter.live_active = c.pitch_hz > 0.0
	var pitch_text: String = "%.0f Hz" % c.pitch_hz if c.pitch_hz > 0.0 else "--"
	_pitch_title.text = "音高　現在 %s　（低音 %.0f ～ 高音 %.0f Hz）" % [pitch_text, c.pitch_min_hz, c.pitch_max_hz]

	_gate_meter.live_value = c.volume_db
	_gate_meter.live_active = c.volume_db >= c.action_gate_db
	_gate_title.text = "吸／吐 音量閥值　%.1f dB（低於此音量不判定）" % c.action_gate_db

	_zone_meter.live_value = c.voicedness
	_zone_meter.live_active = c.volume_db >= c.action_gate_db
	_zone_title.text = "氣音區間　現在 %.0f　（吸區 ≤ %.0f，吐區 ≥ %.0f，中間不輸出）" % [c.voicedness, c.inhale_max, c.exhale_min]


## 右邊：控制器輸出。沒有按住時變淡，數值維持最後的值。
func _update_outputs() -> void:
	var c: MicController = _controller
	_volume_out_bar.value = c.volume_value
	_volume_out_bar.modulate.a = 1.0 if c.volume_active else INACTIVE_ALPHA
	_volume_out_label.text = "音量　%.0f / 100　%s" % [c.volume_value, "按住中" if c.volume_active else ""]

	_pitch_out_bar.value = c.pitch_value
	_pitch_out_bar.modulate.a = 1.0 if c.pitch_active else INACTIVE_ALPHA
	_pitch_out_label.text = "音高　%.0f / 100　%s" % [c.pitch_value, "按住中" if c.pitch_active else ""]

	_inhale_bar.value = 1.0 if c.action == MicController.INHALE else 0.0
	_exhale_bar.value = 1.0 if c.action == MicController.EXHALE else 0.0
	_action_out_label.text = "吸／吐：%s" % (str(c.action) if c.action != &"" else "--")


func _format_db(value: float) -> String:
	return "%.0f dB" % value


func _make_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style
