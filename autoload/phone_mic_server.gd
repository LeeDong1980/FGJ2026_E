class_name PhoneMicServer
extends Node
## 手機網頁麥克風的 server（autoload 名稱 PhoneMic）：同一個 port 同時提供網頁（GET /）與 WebSocket（/ws?player=1 或 2）。
## 每位玩家的聲音分析在 get_source(player)（PhoneVoiceSource，介面與 MicInput 相同）。
## 只監聽 127.0.0.1：手機經由 cloudflared tunnel 連進來，不需要對區網開放，也不會跳 Windows 防火牆視窗。
##
## Cloudflare Quick Tunnel 只能轉一個 port，所以不用 Godot 內建的 WebSocketMultiplayerPeer，
## 改成自己處理 HTTP 與 WebSocket（只支援這裡需要的部分：不分段的文字訊息、ping、close）。
## 手機每段聲音送一次 {"db", "zcr", "hz", "seconds"}，收到後發出 sample_received。
## 延遲監測：手機每秒送 {"ping": 手機時間戳, "rtt": 最近平均來回 ms}，server 立刻原樣傳回並發出 latency_reported；
## 按下延遲測試按鈕時送 {"tap": …}，另外發出 tap_received。

signal player_connected(player: int)
signal player_disconnected(player: int)
signal sample_received(player: int, db: float, zcr: float, hz: float, seconds: float)
## 手機按下延遲測試按鈕（server 已自動把訊息傳回手機）
signal tap_received(player: int)
## 手機回報最近的平均來回時間（ms），每秒一次
signal latency_reported(player: int, round_trip_msec: float)

const PAGE_PATH := "res://scenes/phone_mic/phone_mic.html"
const WS_GUID := "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const MAX_HEADER_BYTES := 8192
const OP_TEXT := 0x1
const OP_CLOSE := 0x8
const OP_PING := 0x9
const OP_PONG := 0xA

@export var port: int = 8080

var _server := TCPServer.new()
## player（1 或 2）-> PhoneVoiceSource
var _sources: Dictionary = {}
var _clients: Array[Client] = []
## player（1 或 2）-> 目前的 WebSocket 連線
var _players: Dictionary = {}
var _page: PackedByteArray


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for player in [1, 2]:
		var source := PhoneVoiceSource.new()
		source.name = "Player%d" % player
		_sources[player] = source
		add_child(source)
	sample_received.connect(func(player: int, db: float, zcr: float, hz: float, seconds: float) -> void:
		_sources[player].push_sample(db, zcr, hz, seconds))
	player_disconnected.connect(func(player: int) -> void: _sources[player].reset())

	_page = FileAccess.get_file_as_bytes(PAGE_PATH)
	if _page.is_empty():
		push_error("PhoneMicServer: 讀不到 %s（匯出時要把 *.html 加進匯出篩選）" % PAGE_PATH)
	var error: Error = _server.listen(port, "127.0.0.1")
	if error != OK:
		push_warning("PhoneMicServer: 無法監聽 port %d（%s）" % [port, error_string(error)])


func _exit_tree() -> void:
	for client in _clients:
		client.tcp.disconnect_from_host()
	_server.stop()


func is_player_connected(player: int) -> bool:
	return _players.has(player)


## 玩家 1 或 2 的手機聲音分析結果。
func get_source(player: int) -> PhoneVoiceSource:
	return _sources[player]


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var client := Client.new()
		client.tcp = _server.take_connection()
		_clients.append(client)

	for client in _clients.duplicate():
		client.tcp.poll()
		if client.tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_drop(client)
			continue
		var available: int = client.tcp.get_available_bytes()
		if available > 0:
			client.buffer.append_array(client.tcp.get_data(available)[1])
		if client.is_websocket:
			_read_frames(client)
		else:
			_read_http(client)


func _drop(client: Client) -> void:
	client.tcp.disconnect_from_host()
	_clients.erase(client)
	if client.player != 0 and _players.get(client.player) == client:
		_players.erase(client.player)
		player_disconnected.emit(client.player)


# --- HTTP ---

func _read_http(client: Client) -> void:
	var text: String = client.buffer.get_string_from_utf8()
	var end: int = text.find("\r\n\r\n")
	if end == -1:
		if client.buffer.size() > MAX_HEADER_BYTES:
			_drop(client)
		return
	client.buffer = client.buffer.slice(text.left(end + 4).to_utf8_buffer().size())

	var lines: PackedStringArray = text.left(end).split("\r\n")
	var request: PackedStringArray = lines[0].split(" ")
	var path: String = request[1] if request.size() > 1 else "/"
	var headers: Dictionary = {}
	for i in range(1, lines.size()):
		var colon: int = lines[i].find(":")
		if colon > 0:
			headers[lines[i].left(colon).strip_edges().to_lower()] = lines[i].substr(colon + 1).strip_edges()

	if headers.get("upgrade", "").to_lower() == "websocket" and path.begins_with("/ws"):
		_accept_websocket(client, path, headers.get("sec-websocket-key", ""))
	elif path == "/" or path.begins_with("/?"):
		_send_http(client, "200 OK", "text/html; charset=utf-8", _page)
	else:
		_send_http(client, "404 Not Found", "text/plain", "not found".to_utf8_buffer())


func _send_http(client: Client, status: String, content_type: String, body: PackedByteArray) -> void:
	var header: String = "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [status, content_type, body.size()]
	client.tcp.put_data(header.to_utf8_buffer() + body)
	_drop(client)


func _accept_websocket(client: Client, path: String, key: String) -> void:
	var player: int = int(path.get_slice("player=", 1).get_slice("&", 0)) if "player=" in path else 0
	if key.is_empty() or player not in [1, 2]:
		_send_http(client, "400 Bad Request", "text/plain", "player must be 1 or 2".to_utf8_buffer())
		return
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA1)
	hashing.update((key + WS_GUID).to_utf8_buffer())
	var accept: String = Marshalls.raw_to_base64(hashing.finish())
	client.tcp.put_data(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n" % accept).to_utf8_buffer())
	client.is_websocket = true
	client.player = player

	# 同一位玩家重新整理網頁時，舊連線直接換掉
	var old: Client = _players.get(player)
	_players[player] = client
	if old != null:
		old.player = 0
		_drop(old)
	else:
		player_connected.emit(player)


# --- WebSocket ---

func _read_frames(client: Client) -> void:
	while true:
		var data: PackedByteArray = client.buffer
		if data.size() < 2:
			return
		var opcode: int = data[0] & 0x0F
		var masked: bool = (data[1] & 0x80) != 0
		var length: int = data[1] & 0x7F
		var offset: int = 2
		if length == 126:
			if data.size() < 4:
				return
			length = (data[2] << 8) | data[3]
			offset = 4
		elif length == 127:
			_drop(client)  # 手機不會送這麼大的訊息
			return
		var mask_offset: int = offset
		if masked:
			offset += 4
		if data.size() < offset + length:
			return

		var payload: PackedByteArray = data.slice(offset, offset + length)
		if masked:
			for i in length:
				payload[i] ^= data[mask_offset + i % 4]
		client.buffer = data.slice(offset + length)

		match opcode:
			OP_TEXT:
				_on_message(client, payload.get_string_from_utf8())
			OP_PING:
				_send_frame(client, OP_PONG, payload)
			OP_CLOSE:
				_send_frame(client, OP_CLOSE, PackedByteArray())
				_drop(client)
				return


func _send_frame(client: Client, opcode: int, payload: PackedByteArray) -> void:
	var header := PackedByteArray([0x80 | opcode])
	if payload.size() < 126:
		header.append(payload.size())
	else:
		header.append_array([126, payload.size() >> 8, payload.size() & 0xFF])
	client.tcp.put_data(header + payload)


func _on_message(client: Client, text: String) -> void:
	var message: Variant = JSON.parse_string(text)
	if message is not Dictionary or client.player == 0:
		return
	if message.has("ping") or message.has("tap"):
		# 延遲監測：原封不動傳回，手機用自己的時間戳算來回時間
		_send_frame(client, OP_TEXT, text.to_utf8_buffer())
		if message.has("rtt"):
			latency_reported.emit(client.player, float(message.rtt))
		if message.has("tap"):
			tap_received.emit(client.player)
		return
	sample_received.emit(
		client.player,
		float(message.get("db", MicController.MIN_DB)),
		float(message.get("zcr", 0.0)),
		float(message.get("hz", 0.0)),
		float(message.get("seconds", 0.0)),
	)


class Client:
	var tcp: StreamPeerTCP
	var buffer := PackedByteArray()
	var is_websocket: bool = false
	## 1 或 2；0 表示還不是玩家連線
	var player: int = 0
