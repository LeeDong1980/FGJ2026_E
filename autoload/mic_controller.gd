class_name MicController
extends Node
## 麥克風輸入控制器：把麥克風聲音轉成三種輸出，所有區間與閥值都能在遊戲中即時調整。
##
## 1. 音量：[volume_min_db, volume_max_db] 轉成 0~100（volume_value）
## 2. 音高：[pitch_min_hz, pitch_max_hz] 轉成 0~100（pitch_value，對數刻度）
## 3. 吸／吐：氣音軸 0~100（0 = 嘶聲、100 = 母音）。<= inhale_max 為 inhale，>= exhale_min 為 exhale，中間不輸出
##
## 三種輸出都是「按住」模式：聲音持續就持續輸出（*_active 為 true），
## 聲音中斷超過 *_release_seconds 才放開。放開後數值維持最後的值，不會歸零。
##
## 這是 autoload（全域名稱 MicInput）：切換場景時設定與狀態都保留，設定也會存到 user://mic_settings.cfg。

signal action_changed(action: StringName)
## 麥克風收音狀態改變（LISTENING 收音中、NO_SIGNAL 一直收不到訊號而停止、DISABLED 已停用）
signal mic_status_changed(status: MicStatus)

enum MicStatus { LISTENING, NO_SIGNAL, DISABLED }

const BUS_NAME := "MicInput"
const SETTINGS_PATH := "user://mic_settings.cfg"
## 會被存檔的設定
const SAVED_PROPERTIES: PackedStringArray = [
	"volume_min_db", "volume_max_db", "volume_release_seconds",
	"pitch_min_hz", "pitch_max_hz", "pitch_release_seconds", "pitch_gate_db",
	"action_gate_db", "inhale_max", "exhale_min", "action_release_seconds",
	"mic_enabled", "pitch_input_enabled", "action_input_enabled",
]
const MIN_DB := -60.0
## 開始收音後這麼久都沒有任何訊號，就視為麥克風無法使用並停止收音
const NO_SIGNAL_TIMEOUT := 1.5
const INHALE := &"inhale"
const EXHALE := &"exhale"

## 音高分析視窗（原始取樣數）與降採樣倍率，降低 GDScript 運算量
const WINDOW_SIZE := 2048
const DOWNSAMPLE := 4
## 音高偵測的頻率範圍（與玩家設定的輸出區間無關）
const DETECT_MIN_HZ := 70.0
const DETECT_MAX_HZ := 1000.0

@export_group("Volume")
## 小音量（輸出 0）與大音量（輸出 100）；低於小音量視為沒有聲音
@export var volume_min_db: float = -45.0
@export var volume_max_db: float = -15.0
@export var volume_release_seconds: float = 0.1

@export_group("Pitch")
## 低音（輸出 0）與高音（輸出 100）
@export var pitch_min_hz: float = 100.0
@export var pitch_max_hz: float = 500.0
@export var pitch_release_seconds: float = 0.1
## 低於此音量不做音高判定（避免環境噪音誤判）
@export var pitch_gate_db: float = -35.0
## 自相關峰值（0~1）低於此值視為沒有明確音高
@export_range(0.0, 1.0) var min_correlation: float = 0.5

@export_group("Action")
## 音量閥值：低於此音量不判定吸／吐
@export var action_gate_db: float = -35.0
## 氣音軸上，<= inhale_max 為吸區，>= exhale_min 為吐區
@export_range(0.0, 100.0) var inhale_max: float = 50.0
@export_range(0.0, 100.0) var exhale_min: float = 75.0
@export var action_release_seconds: float = 0.1
## 零交越率高於此值視為氣音（嘶）
@export_range(0.0, 0.5) var noisy_zcr: float = 0.12
## 氣音軸的平滑時間，越長越穩但反應越慢
@export var analysis_seconds: float = 0.08
## 落在吸區／吐區至少這麼久才輸出，用來忽略爆音與過短的聲音
@export var action_min_seconds: float = 0.08
## 聲音中斷超過此時間，視為新的一次發音；同一次發音內不會從吸切到吐（或反過來）
@export var segment_gap_seconds: float = 0.15

## 目前音量（dB），即時值
var volume_db: float = MIN_DB
## 音量輸出 0~100 與是否按住中
var volume_value: float = 0.0
var volume_active: bool = false
## 目前音高（Hz），沒有明確音高時為 0
var pitch_hz: float = 0.0
var pitch_value: float = 0.0
var pitch_active: bool = false
## 氣音軸即時值 0~100（0 = 嘶聲、100 = 母音），音量低於閥值時維持最後的值
var voicedness: float = 100.0
## 目前按住的動作：&"inhale"、&"exhale" 或 &""（沒有）
var action: StringName = &""
## 最後一次按住的動作，放開後仍保留（給 UI 顯示最後辨識到的字音）
var last_action: StringName = &""
## 麥克風收音狀態與開關（開關會存檔）
var mic_status: MicStatus = MicStatus.LISTENING
var mic_enabled: bool = true
## 遊戲端是否採用音高（換層）與吸／吐（語音）輸出；只是給遊戲橋接讀的開關，不影響收音與分析，會存檔
var pitch_input_enabled: bool = true
var action_input_enabled: bool = true

var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _silent_seconds: float = 0.0
var _heard_signal: bool = false
var _window: PackedFloat32Array = PackedFloat32Array()
var _chunk_zcr: float = 0.0
var _chunk_seconds: float = 0.0
var _volume_hold := HoldGate.new()
var _pitch_hold := HoldGate.new()
var _action_hold := HoldGate.new()
var _noisy_ema: float = 0.0
var _since_loud: float = INF
var _zone: StringName = &""
var _zone_seconds: float = 0.0
var _lock: StringName = &""
var _wanted: StringName = &""


func _ready() -> void:
	# 暫停選單開啟時（tree.paused）仍要持續收音與分析，讓設定畫面能即時回饋
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	_setup_bus()
	if mic_enabled:
		start_microphone()
	else:
		mic_status = MicStatus.DISABLED


func _process(delta: float) -> void:
	if _consume_capture():
		_on_chunk(_chunk_zcr, volume_db, _chunk_seconds)
	_watch_for_signal(delta)
	_update_outputs(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()


## 把目前的設定與輸入裝置存到 user://。
func save_settings() -> void:
	var config := ConfigFile.new()
	for property in SAVED_PROPERTIES:
		config.set_value("mic", property, get(property))
	config.set_value("mic", "input_device", AudioServer.input_device)
	config.save(SETTINGS_PATH)


## 讀取存檔；沒有存檔就維持 @export 的預設值。
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for property in SAVED_PROPERTIES:
		if config.has_section_key("mic", property):
			set(property, config.get_value("mic", property))
	var device: String = config.get_value("mic", "input_device", "")
	if device in AudioServer.get_input_device_list():
		AudioServer.input_device = device


## 建立靜音的 MicInput bus，掛 Capture 效果取得原始取樣；麥克風串流由 start_microphone() 開始播放。
func _setup_bus() -> void:
	var bus_index: int = AudioServer.get_bus_index(BUS_NAME)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, BUS_NAME)
		AudioServer.add_bus_effect(bus_index, AudioEffectCapture.new())
		AudioServer.set_bus_mute(bus_index, true)
	_capture = AudioServer.get_bus_effect(bus_index, 0) as AudioEffectCapture

	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = BUS_NAME
	add_child(_mic_player)


## 開始（或重新開始）收音，並重新計算「有沒有訊號」的等待時間。
func start_microphone() -> void:
	_mic_player.stop()
	_capture.clear_buffer()
	_silent_seconds = 0.0
	_heard_signal = false
	_mic_player.play()
	_set_mic_status(MicStatus.LISTENING)


## 停止收音。停止後 Godot 不會再向系統索取麥克風，也就不會繼續印出驅動層的錯誤。
func stop_microphone(status: MicStatus = MicStatus.DISABLED) -> void:
	_mic_player.stop()
	_capture.clear_buffer()
	_window.clear()
	volume_db = MIN_DB
	_set_mic_status(status)


## 啟用或停用麥克風（會存檔）。
func set_mic_enabled(enabled: bool) -> void:
	mic_enabled = enabled
	if enabled:
		start_microphone()
	else:
		stop_microphone(MicStatus.DISABLED)


## 重新偵測：停用中則不動作，否則重新開始收音。
func restart_microphone() -> void:
	if mic_enabled:
		start_microphone()


## 切換輸入裝置並重新開始收音。
func set_input_device(device: String) -> void:
	AudioServer.input_device = device
	restart_microphone()


func _set_mic_status(status: MicStatus) -> void:
	if status == mic_status:
		return
	mic_status = status
	mic_status_changed.emit(status)


## 開始收音後一直收不到任何訊號（取樣全是 0）就停止收音。
## 部分裝置（例如 Windows 上聲道數不支援的麥克風）會讓 Godot 的音訊驅動每個迴圈都印一次錯誤，
## 這種情況下取樣永遠是 0；及早停止收音，錯誤就只會出現很短一陣，並留下一則警告。
func _watch_for_signal(delta: float) -> void:
	if mic_status != MicStatus.LISTENING or _heard_signal:
		return
	_silent_seconds += delta
	if _silent_seconds >= NO_SIGNAL_TIMEOUT:
		push_warning("MicInput: %.1f 秒內沒有收到任何麥克風訊號，已停止收音。可能是裝置不支援、被系統封鎖或權限未允許；請在暫停選單換輸入裝置或按「重新偵測」。" % NO_SIGNAL_TIMEOUT)
		stop_microphone(MicStatus.NO_SIGNAL)


## 取出 capture buffer 內目前所有取樣：更新音量（RMS，dB）、零交越率，並推進音高分析視窗。
func _consume_capture() -> bool:
	var frames: int = _capture.get_frames_available()
	if frames == 0:
		return false
	var buffer: PackedVector2Array = _capture.get_buffer(frames)
	var sum_squares: float = 0.0
	var crossings: int = 0
	var peak: float = 0.0
	var mono := PackedFloat32Array()
	mono.resize(buffer.size())
	for i in buffer.size():
		var sample: float = (buffer[i].x + buffer[i].y) * 0.5
		mono[i] = sample
		sum_squares += sample * sample
		peak = maxf(peak, absf(sample))
		if i > 0 and (sample >= 0.0) != (mono[i - 1] >= 0.0):
			crossings += 1
	volume_db = maxf(linear_to_db(sqrt(sum_squares / buffer.size())), MIN_DB)
	if peak > 0.0:
		_heard_signal = true
	_chunk_zcr = float(crossings) / buffer.size()
	_chunk_seconds = buffer.size() / AudioServer.get_mix_rate()

	_window.append_array(mono)
	if _window.size() > WINDOW_SIZE:
		_window = _window.slice(_window.size() - WINDOW_SIZE)
	return true


## 每收到一段新取樣就更新一次氣音軸與吸／吐的候選結果。
func _on_chunk(zcr: float, db: float, seconds: float) -> void:
	if db < action_gate_db:
		_zone = &""
		_zone_seconds = 0.0
		_wanted = &""
		return

	if _since_loud > segment_gap_seconds:
		# 新的一次發音：從「母音」起算，開頭的爆音不會直接落進吸區
		_noisy_ema = 0.0
		_lock = &""
	_since_loud = 0.0

	var noisy: float = 1.0 if zcr >= noisy_zcr else 0.0
	_noisy_ema += (noisy - _noisy_ema) * (1.0 - exp(-seconds / maxf(analysis_seconds, 0.001)))
	voicedness = (1.0 - _noisy_ema) * 100.0

	var zone: StringName = &""
	if voicedness <= inhale_max:
		zone = INHALE
	elif voicedness >= exhale_min:
		zone = EXHALE
	if zone == _zone:
		_zone_seconds += seconds
	else:
		_zone = zone
		_zone_seconds = seconds

	var qualifies: bool = zone != &"" and (
		zone == action
		or (_zone_seconds >= action_min_seconds and (_lock == &"" or _lock == zone))
	)
	_wanted = zone if qualifies else &""


## 每個 frame 更新三個通道的輸出與按住狀態。
func _update_outputs(delta: float) -> void:
	_since_loud += delta

	# 音量
	var volume_present: bool = volume_db >= volume_min_db
	if volume_present:
		volume_value = _to_percent(volume_db, volume_min_db, volume_max_db)
	_volume_hold.update(volume_present, volume_release_seconds, delta)
	volume_active = _volume_hold.active

	# 音高
	pitch_hz = 0.0
	if volume_db >= pitch_gate_db and _window.size() >= WINDOW_SIZE:
		pitch_hz = _detect_pitch_hz()
	if pitch_hz > 0.0:
		pitch_value = _to_percent(log(pitch_hz), log(pitch_min_hz), log(pitch_max_hz))
	_pitch_hold.update(pitch_hz > 0.0, pitch_release_seconds, delta)
	pitch_active = _pitch_hold.active

	# 吸／吐
	if _wanted != &"" and _wanted != action:
		_lock = _wanted
		_set_action(_wanted)
	_action_hold.update(_wanted != &"", action_release_seconds, delta)
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

	var min_lag: int = maxi(int(rate / DETECT_MAX_HZ), 2)
	var max_lag: int = mini(int(rate / DETECT_MIN_HZ), count / 2)
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


## 「按住」判定：有訊號就按住，訊號中斷超過 release_seconds 才放開。
class HoldGate:
	var active: bool = false
	var _gap: float = 0.0

	func update(present: bool, release_seconds: float, delta: float) -> void:
		if present:
			_gap = 0.0
			active = true
			return
		_gap += delta
		if _gap >= release_seconds:
			active = false
