extends Control
## Quick Tunnel 連線原型（F6 單獨執行）：Host 在本機開 WebSocket 伺服器，用 cloudflared 公開成
## https://xxx.trycloudflare.com，並向目錄登記取得房間代碼；Client 輸入代碼查出網址後直連。
## 驗證資料通道有沒有走近的機房（Host 畫面顯示 cloudflared 連到的機房），並量玩家之間的來回時間。
## 需要 cloudflared 執行檔：tools/cloudflared/cloudflared（見 docs/relay.md「Quick Tunnel 原型」）。
##
## 自動模式（給腳本測試）：命令列加
##   -- --auto=host | --auto=hold（同 host，但不因對方離開或逾時而結束，除錯用）| --auto=join --code=ABC234 [--relay-url=…（目錄伺服器，預設 NetworkManager.relay_url）]
## 結果印在輸出，最後一行是 RESULT: OK 或 RESULT: FAIL（附原因），結束碼 0／1。

const PORT: int = 7780
const PING_COUNT: int = 20
const PING_INTERVAL_SEC: float = 0.1
## 剛建立的 tunnel 網址 DNS 還沒傳開時連不上，所以連線失敗時重試。
const CONNECT_ATTEMPTS: int = 8
const CONNECT_ATTEMPT_SEC: float = 5.0
const AUTO_TIMEOUT_SEC: float = 90.0

var _log: RichTextLabel
var _info: Label
var _code_input: LineEdit
var _tunnel: CloudflaredTunnel
var _directory: TunnelDirectory
var _tunnel_url: String = ""
var _room_code: String = ""
var _is_host: bool = false
var _rtts: Array[float] = []
var _connect_attempt: int = 0
var _connect_started_msec: int = 0
var _connecting: bool = false
var _had_client: bool = false
var _auto: String = ""
var _auto_code: String = ""
## 除錯：--url=ws://127.0.0.1:7780 直接連這個網址，不經過目錄。
var _direct_url: String = ""
var _auto_started_msec: int = 0
var _auto_finished: bool = false


func _ready() -> void:
	_build_ui()
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(func() -> void: _say("與房主斷線"); _auto_done(false, "server_disconnected"))
	NetworkManager.joined_server.connect(func() -> void: _say("NetworkManager 加入流程完成（joined_server）"))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--auto="):
			_auto = arg.trim_prefix("--auto=")
		elif arg.begins_with("--code="):
			_auto_code = arg.trim_prefix("--code=")
		elif arg.begins_with("--url="):
			_direct_url = arg.trim_prefix("--url=")
	if not _auto.is_empty():
		_auto_started_msec = Time.get_ticks_msec()
		_start_auto.call_deferred()


func _process(_delta: float) -> void:
	var parts: PackedStringArray = []
	if _tunnel != null:
		parts.append("tunnel：%s（機房 %s）" % [_tunnel_url if not _tunnel_url.is_empty() else "建立中…", _tunnel.location if not _tunnel.location.is_empty() else "?"])
	if not _room_code.is_empty():
		parts.append("房間代碼：%s" % _room_code)
	if not _rtts.is_empty():
		parts.append("來回：%d ms" % int(_rtts[-1]))
	_info.text = "　".join(parts)
	if _connecting and (Time.get_ticks_msec() - _connect_started_msec) / 1000.0 > CONNECT_ATTEMPT_SEC:
		_on_connection_failed()
	if not _auto.is_empty() and _auto != "hold" and not _auto_finished and (Time.get_ticks_msec() - _auto_started_msec) / 1000.0 > AUTO_TIMEOUT_SEC:
		_auto_done(false, "逾時（%d 秒）" % int(AUTO_TIMEOUT_SEC))


# ---- Host ----

func _on_host_pressed() -> void:
	_is_host = true
	var peer := WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_server(PORT, "127.0.0.1")
	if err != OK:
		_say("無法在 127.0.0.1:%d 監聽（%s）" % [PORT, error_string(err)])
		_auto_done(false, "listen_failed")
		return
	multiplayer.multiplayer_peer = peer
	_say("本機監聽 127.0.0.1:%d，啟動 cloudflared…" % PORT)
	_tunnel = CloudflaredTunnel.new()
	add_child(_tunnel)
	_tunnel.url_ready.connect(_on_tunnel_ready)
	_tunnel.failed.connect(func(reason: String) -> void: _say("tunnel 失敗：" + reason); _auto_done(false, "tunnel: " + reason))
	_tunnel.start(PORT)


func _on_tunnel_ready(url: String) -> void:
	_tunnel_url = url
	_say("tunnel 已就緒：%s（cloudflared 連到機房 %s）" % [url, _tunnel.location])
	_directory = TunnelDirectory.new()
	add_child(_directory)
	_directory.code_ready.connect(_on_code_ready)
	_directory.publish_failed.connect(func(reason: String) -> void: _say("目錄登記失敗：" + reason); _auto_done(false, "directory: " + reason))
	_directory.publish(NetworkManager.relay_url, url)


func _on_code_ready(code: String) -> void:
	_room_code = code
	_say("房間代碼：%s（把它告訴對方）" % code)
	print("CODE=%s" % code)
	print("LOCATION=%s" % _tunnel.location)


func _on_peer_connected(id: int) -> void:
	if _is_host:
		_had_client = true
		_say("對方已連上（peer %d）" % id)


func _on_peer_disconnected(id: int) -> void:
	if _is_host and _had_client:
		_say("對方離開（peer %d）" % id)
		if _auto != "hold":
			_auto_done(true, "")


# ---- Client ----

func _on_join_pressed() -> void:
	_is_host = false
	_say("查詢房間代碼 %s…" % _code_input.text)
	_directory = TunnelDirectory.new()
	add_child(_directory)
	_directory.resolved.connect(_on_resolved)
	_directory.resolve_failed.connect(func(reason: String) -> void: _say("查詢失敗：" + reason); _auto_done(false, "resolve: " + reason))
	_directory.resolve(NetworkManager.relay_url, _code_input.text)


func _on_resolved(url: String) -> void:
	_tunnel_url = url
	_say("查到 Host 的網址：%s" % url)
	_connect_attempt = 0
	_try_connect()


func _try_connect() -> void:
	_connect_attempt += 1
	var peer := WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_client(_tunnel_url.replace("https://", "wss://"))
	if err != OK:
		_say("無法開始連線（%s）" % error_string(err))
		_auto_done(false, "create_client")
		return
	multiplayer.multiplayer_peer = peer
	_connecting = true
	_connect_started_msec = Time.get_ticks_msec()
	_say("連線中…（第 %d 次）" % _connect_attempt)


func _on_connection_failed() -> void:
	_connecting = false
	multiplayer.multiplayer_peer = null
	if _connect_attempt >= CONNECT_ATTEMPTS:
		_say("連不上 Host，已重試 %d 次" % CONNECT_ATTEMPTS)
		_auto_done(false, "connect_failed")
		return
	_say("連線失敗，2 秒後重試（新 tunnel 的網址可能還沒傳開）")
	await get_tree().create_timer(2.0).timeout
	_try_connect()


func _on_connected() -> void:
	if _is_host:
		return
	_connecting = false
	_say("已連上 Host（直連 tunnel），開始量來回時間")
	for i in PING_COUNT:
		_rpc_ping.rpc_id(1, Time.get_ticks_usec(), i)
		await get_tree().create_timer(PING_INTERVAL_SEC).timeout


@rpc("any_peer", "call_remote", "reliable")
func _rpc_ping(sent_usec: int, index: int) -> void:
	if multiplayer.is_server():
		_rpc_pong.rpc_id(multiplayer.get_remote_sender_id(), sent_usec, index)


@rpc("authority", "call_remote", "reliable")
func _rpc_pong(sent_usec: int, index: int) -> void:
	_rtts.append((Time.get_ticks_usec() - sent_usec) / 1000.0)
	if index == PING_COUNT - 1:
		var sorted: Array[float] = _rtts.duplicate()
		sorted.sort()
		_say("玩家對玩家來回（%d 次）：中位數 %d ms，最小 %d，最大 %d" % [sorted.size(), int(sorted[sorted.size() / 2]), int(sorted[0]), int(sorted[-1])])
		print("RTT_MEDIAN=%d" % int(sorted[sorted.size() / 2]))
		_auto_done(true, "")


# ---- 自動模式 ----

func _start_auto() -> void:
	match _auto:
		"host", "hold":
			_on_host_pressed()
		"join":
			if not _direct_url.is_empty():
				_on_resolved(_direct_url)
			else:
				_code_input.text = _auto_code
				_on_join_pressed()
		_:
			_auto_done(false, "未知的 --auto 值：" + _auto)


func _auto_done(ok: bool, reason: String) -> void:
	if _auto.is_empty() or _auto_finished:
		return
	_auto_finished = true
	print("RESULT: OK" if ok else "RESULT: FAIL %s" % reason)
	# 讓最後一批封包有機會送出，離開場景樹時 cloudflared 會被關掉。
	get_tree().create_timer(0.5).timeout.connect(get_tree().quit.bind(0 if ok else 1))


# ---- 畫面 ----

func _say(text: String) -> void:
	print("[tunnel_test] ", text)
	if _log != null:
		_log.append_text(text + "\n")


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "Quick Tunnel 連線原型"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var row1 := HBoxContainer.new()
	box.add_child(row1)
	var host_button := Button.new()
	host_button.text = "建立房間（Host）"
	host_button.pressed.connect(_on_host_pressed)
	row1.add_child(host_button)

	var row2 := HBoxContainer.new()
	box.add_child(row2)
	_code_input = LineEdit.new()
	_code_input.placeholder_text = "房間代碼"
	_code_input.custom_minimum_size.x = 220
	row2.add_child(_code_input)
	var join_button := Button.new()
	join_button.text = "用代碼加入（Client）"
	join_button.pressed.connect(_on_join_pressed)
	row2.add_child(join_button)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	box.add_child(_info)

	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	box.add_child(_log)
