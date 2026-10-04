class_name AudioSettingsPanel
extends PanelContainer
## 音量設定面板：總音量、音樂、音效三條滑桿，直接讀寫 AudioSettings。暫停選單與主選單共用。

signal close_requested

## 顯示「關閉」按鈕（主選單的彈出視窗使用）
@export var show_close_button: bool = false

@onready var _close_button: Button = %CloseButton
@onready var _sliders: Dictionary[StringName, HSlider] = {
	AudioSettings.MASTER: %MasterSlider,
	AudioSettings.MUSIC: %MusicSlider,
	AudioSettings.SFX: %SfxSlider,
}
@onready var _value_labels: Dictionary[StringName, Label] = {
	AudioSettings.MASTER: %MasterValue,
	AudioSettings.MUSIC: %MusicValue,
	AudioSettings.SFX: %SfxValue,
}


func _ready() -> void:
	_close_button.visible = show_close_button
	_close_button.pressed.connect(close_requested.emit)
	for bus_name in _sliders:
		var slider: HSlider = _sliders[bus_name]
		slider.set_value_no_signal(AudioSettings.get_volume(bus_name) * 100.0)
		_update_label(bus_name)
		slider.value_changed.connect(func(value: float) -> void:
			AudioSettings.set_volume(bus_name, value / 100.0)
			_update_label(bus_name))
	# 另一個面板（主選單／暫停選單）改了音量時跟著更新
	AudioSettings.volume_changed.connect(_on_volume_changed)


func _on_volume_changed(bus_name: StringName, linear: float) -> void:
	if not _sliders.has(bus_name):
		return
	_sliders[bus_name].set_value_no_signal(linear * 100.0)
	_update_label(bus_name)


func _update_label(bus_name: StringName) -> void:
	_value_labels[bus_name].text = "%d%%" % roundi(_sliders[bus_name].value)


## 打開視窗時把焦點放在第一條滑桿，方便用方向鍵調整。
func focus_first_slider() -> void:
	_sliders[AudioSettings.MASTER].grab_focus()
