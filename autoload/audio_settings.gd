extends Node
## 音量設定（autoload，全域名稱 AudioSettings）：總音量、音樂、音效三條 bus 的音量，存在 user://audio_settings.cfg。
## 音樂的 AudioStreamPlayer 把 bus 設成 "Music"，音效設成 "SFX"；兩條都送到 Master，所以總音量會一起影響。
## 介面用 get_volume()／set_volume() 讀寫 0～1 的線性音量，改動後自動延遲存檔。

signal volume_changed(bus_name: StringName, linear: float)

const MASTER := &"Master"
const MUSIC := &"Music"
const SFX := &"SFX"
const BUSES: Array[StringName] = [MASTER, MUSIC, SFX]
const SETTINGS_PATH := "user://audio_settings.cfg"
## 改動後等多久才存檔（秒），拖曳滑桿時不會每幀寫檔
const SAVE_DELAY := 0.5

## 各 bus 的預設音量（0～1）
@export var default_volumes: Dictionary[StringName, float] = {MASTER: 1.0, MUSIC: 0.8, SFX: 0.8}

var _volumes: Dictionary[StringName, float] = {}
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)
	_load_settings()


func _exit_tree() -> void:
	if _save_timer != null and not _save_timer.is_stopped():
		save_settings()


func get_volume(bus_name: StringName) -> float:
	return _volumes.get(bus_name, 1.0)


## 設定 bus 音量（0～1），0 時直接靜音。
func set_volume(bus_name: StringName, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_volumes[bus_name] = linear
	var index: int = AudioServer.get_bus_index(bus_name)
	if index != -1:
		AudioServer.set_bus_volume_linear(index, linear)
		AudioServer.set_bus_mute(index, linear <= 0.0)
	volume_changed.emit(bus_name, linear)
	if _save_timer != null:
		_save_timer.start()


func save_settings() -> void:
	var config := ConfigFile.new()
	for bus_name in BUSES:
		config.set_value("volume", bus_name, get_volume(bus_name))
	config.save(SETTINGS_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for bus_name in BUSES:
		set_volume(bus_name, config.get_value("volume", bus_name, default_volumes.get(bus_name, 1.0)))
	_save_timer.stop()


## 沒有 default_bus_layout.tres 時（例如被刪掉）補上 Music、SFX bus，都送到 Master。
func _ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, MASTER)
