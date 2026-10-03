extends Control
## 語音封包傳輸測試：Client（B）送出音量與「吸／吐」，Host（A）顯示收到的內容。
## 這裡用滑桿和按鈕模擬 voice-input；真正的麥克風輸入之後呼叫同樣的
## NetworkManager.send_voice_volume() / send_voice_word() 即可。

const STREAM_INTERVAL: float = 0.05  # 持續傳送音量的間隔（20 Hz）
const SILENCE_WARN_SEC: float = 3.0

@onready var _role_label: Label = %RoleLabel
@onready var _host_panel: Control = %HostPanel
@onready var _client_panel: Control = %ClientPanel
@onready var _peer_label: Label = %PeerLabel
@onready var _volume_bar: ProgressBar = %VolumeBar
@onready var _word_label: Label = %WordLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _age_label: Label = %AgeLabel
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _stream_check: CheckButton = %StreamCheck
@onready var _suck_button: Button = %SuckButton
@onready var _spit_button: Button = %SpitButton
@onready var _ack_label: Label = %AckLabel
@onready var _log: RichTextLabel = %Log

var _volume_count: int = 0
var _word_count: int = 0
var _lost_count: int = 0
var _last_receive_msec: int = -1
var _stream_timer: float = 0.0
var _ack_ok: int = 0
var _ack_timeout: int = 0


func _ready() -> void:
	_suck_button.pressed.connect(func() -> void: _send_word("吸"))
	_spit_button.pressed.connect(func() -> void: _send_word("吐"))
	NetworkManager.hosting_started.connect(_on_hosting_started)
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.join_failed.connect(_on_join_failed)
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.disconnected.connect(_on_disconnected)
	NetworkManager.voice_volume_received.connect(_on_volume_received)
	NetworkManager.voice_word_received.connect(_on_word_received)
	NetworkManager.voice_packets_lost.connect(_on_packets_lost)
	NetworkManager.voice_ack_received.connect(_on_ack_received)
	NetworkManager.voice_ack_timeout.connect(_on_ack_timeout)
	_show_role(false, false)


func _process(delta: float) -> void:
	if NetworkManager.is_host():
		_update_host_age()
	elif NetworkManager.is_online():
		_update_client(delta)


func _show_role(online: bool, is_host: bool) -> void:
	_host_panel.visible = online and is_host
	_client_panel.visible = online and not is_host
	if not online:
		_role_label.text = "尚未連線：左邊建立房間（A）或輸入 A 的 IP 加入（B）"
	elif is_host:
		_role_label.text = "你是 Host（A）：等待 Client 傳來語音輸入封包"
	else:
		_role_label.text = "你是 Client（B）：送出語音輸入封包給 Host"


func _log_line(text: String, color: Color = Color.WHITE) -> void:
	var stamp: String = Time.get_time_string_from_system()
	_log.append_text("[color=#%s][%s] %s[/color]\n" % [color.to_html(false), stamp, text])


func _reset_counters() -> void:
	_volume_count = 0
	_word_count = 0
	_lost_count = 0
	_last_receive_msec = -1
	_ack_ok = 0
	_ack_timeout = 0
	_volume_bar.value = 0.0
	_word_label.text = "最後收到的字音：（尚無）"
	_ack_label.text = "Host 確認：（尚無）"
	_refresh_stats()


func _refresh_stats() -> void:
	_stats_label.text = "音量封包：%d　字音封包：%d　掉包：%d" % [_volume_count, _word_count, _lost_count]


# ---- 連線狀態 ----

func _on_hosting_started() -> void:
	_reset_counters()
	_show_role(true, true)
	_peer_label.text = "Client：尚未連上"
	_log_line("房間已建立，等待 Client 加入", Color.LIGHT_GREEN)


func _on_joined_server() -> void:
	_reset_counters()
	_show_role(true, false)
	_log_line("已連上 Host", Color.LIGHT_GREEN)


func _on_join_failed() -> void:
	_log_line("連線失敗：連不上 Host。請檢查 IP、是否同一個網路、Host 防火牆是否放行 UDP %d" % NetworkManager.port, Color.TOMATO)


func _on_peer_joined(id: int) -> void:
	if NetworkManager.is_host():
		_peer_label.text = "Client：已連上（peer %d）" % id
		_log_line("Client 已加入（peer %d）" % id, Color.LIGHT_GREEN)


func _on_peer_left(id: int) -> void:
	if NetworkManager.is_host():
		_peer_label.text = "Client：已離線"
		_log_line("Client 已離線（peer %d）" % id, Color.TOMATO)


func _on_disconnected() -> void:
	_show_role(false, false)
	_stream_check.button_pressed = false
	_log_line("已中斷連線（Host 關閉或網路斷線）", Color.TOMATO)


# ---- Host：接收 ----

func _on_volume_received(_peer_id: int, _seq: int, volume: float) -> void:
	_volume_count += 1
	_last_receive_msec = Time.get_ticks_msec()
	_volume_bar.value = volume
	_refresh_stats()


func _on_word_received(_peer_id: int, seq: int, word: String) -> void:
	_word_count += 1
	_last_receive_msec = Time.get_ticks_msec()
	_word_label.text = "最後收到的字音：「%s」（#%d）" % [word, seq]
	_log_line("收到字音「%s」#%d" % [word, seq], Color.SKY_BLUE)
	_refresh_stats()


func _on_packets_lost(_peer_id: int, count: int) -> void:
	_lost_count += count
	_log_line("音量封包掉了 %d 個（序號不連續）" % count, Color.ORANGE)
	_refresh_stats()


func _update_host_age() -> void:
	if _last_receive_msec < 0:
		_age_label.text = "尚未收到任何封包"
		_age_label.modulate = Color.WHITE
		return
	var age: float = (Time.get_ticks_msec() - _last_receive_msec) / 1000.0
	_age_label.text = "距離上次收到封包：%.1f 秒" % age
	_age_label.modulate = Color.TOMATO if age > SILENCE_WARN_SEC else Color.WHITE


# ---- Client：傳送 ----

func _update_client(delta: float) -> void:
	_stream_timer += delta
	if _stream_check.button_pressed and _stream_timer >= STREAM_INTERVAL:
		_stream_timer = 0.0
		NetworkManager.send_voice_volume(_volume_slider.value)
	var rtt: float = NetworkManager.get_rtt_msec()
	_ack_label.text = "Host 確認：成功 %d　逾時 %d　網路延遲 %s" % [
		_ack_ok, _ack_timeout, ("%d ms" % int(rtt)) if rtt >= 0.0 else "—"]


func _send_word(word: String) -> void:
	if not NetworkManager.is_online() or NetworkManager.is_host():
		return
	NetworkManager.send_voice_word(word)
	_log_line("送出字音「%s」" % word)


func _on_ack_received(kind: String, seq: int, rtt_msec: int) -> void:
	_ack_ok += 1
	if kind == NetworkManager.KIND_WORD:
		_log_line("Host 已確認字音 #%d（%d ms）" % [seq, rtt_msec], Color.LIGHT_GREEN)


func _on_ack_timeout(kind: String, seq: int) -> void:
	_ack_timeout += 1
	var kind_text: String = "字音" if kind == NetworkManager.KIND_WORD else "音量"
	_log_line("Host 沒有確認%s封包 #%d（超過 %d 秒）：Host 可能沒收到、已離線或網路中斷" % [
		kind_text, seq, NetworkManager.ACK_TIMEOUT_MSEC / 1000], Color.TOMATO)
