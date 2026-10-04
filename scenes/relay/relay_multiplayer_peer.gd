class_name RelayMultiplayerPeer
extends MultiplayerPeerExtension
## 經 Cloudflare 中繼連線的 MultiplayerPeer（協定與伺服器見 docs/relay.md、relay_server/）。
## 兩位玩家都只對中繼做出站 wss 連線，不用開 port，所以不同網路、有防火牆也能連。
##
## 一個房間固定 1 位 Host（peer id 1）加 1 位 Client（peer id 2）。
## SceneMultiplayer 與 RPC 的用法和 ENet 相同，只是傳輸全部是可靠有序（WebSocket 是 TCP）。
##
## 用法：Host 呼叫 open_host()，等 room_code_received；Client 呼叫 open_client(url, code)。
## 之後指定給 multiplayer.multiplayer_peer。連線失敗或中途斷線時發出 relay_closed。

## Host 端：中繼已建立房間，code 是房間代碼。
signal room_code_received(code: String)
## 與中繼的連線失敗或結束（REASON_*）。發出時這個 peer 已經關閉。
signal relay_closed(reason: String)

const HOST_ID: int = 1
const CLIENT_ID: int = 2

const REASON_ROOM_NOT_FOUND: String = "room_not_found"
const REASON_ROOM_FULL: String = "room_full"
const REASON_HOST_LEFT: String = "host_left"
## 中繼連不上，或連線途中沒有回應。
const REASON_NETWORK: String = "network"

## 每個 WebSocket 訊息的第一個位元組是類型，其餘是內容。Godot 的封包用 FRAME_DATA 包起來，
## FRAME_PING／FRAME_PONG 是 Host 與 Client 之間互測來回時間與是否還在（中繼只負責轉送）。
const FRAME_DATA: int = 0
const FRAME_PING: int = 1
const FRAME_PONG: int = 2

const CONNECT_TIMEOUT_MSEC: int = 10000
const RELAY_PING_INTERVAL_MSEC: int = 4000
## 超過這麼久沒收到中繼的任何訊息，視為中繼斷線。
const RELAY_TIMEOUT_MSEC: int = 12000
const PEER_PING_INTERVAL_MSEC: int = 1000
## 超過這麼久沒收到對方的任何訊息，視為對方斷線（對應 ENet 的約 6 秒）。
const PEER_TIMEOUT_MSEC: int = 6000
## 中繼單一訊息上限是 64 KB，扣掉類型位元組後留一些空間。
const MAX_PACKET_SIZE: int = 60000

var _ws := WebSocketPeer.new()
var _is_host: bool = false
var _status: MultiplayerPeer.ConnectionStatus = MultiplayerPeer.CONNECTION_DISCONNECTED
var _code: String = ""
var _peer_present: bool = false
var _packets: Array[PackedByteArray] = []
var _target_peer: int = 0
var _transfer_mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _transfer_channel: int = 0
var _refuse_new: bool = false
var _rtt_msec: float = -1.0
var _closed: bool = false

var _connect_started_msec: int = 0
var _last_relay_msg_msec: int = 0
var _last_relay_ping_msec: int = 0
var _last_peer_msg_msec: int = 0
var _last_peer_ping_msec: int = 0


## Host：向中繼要一個房間。回傳 OK 只代表開始連線，結果看 room_code_received 或 relay_closed。
func open_host(relay_url: String) -> Error:
	_is_host = true
	return _open(_join_url(relay_url, "/host"))


## Client：用房間代碼加入。回傳 OK 只代表開始連線，結果看 SceneMultiplayer 的連線 signal 或 relay_closed。
func open_client(relay_url: String, code: String) -> Error:
	_is_host = false
	_code = code
	return _open(_join_url(relay_url, "/join/" + code))


func is_host() -> bool:
	return _is_host


func get_room_code() -> String:
	return _code


## 對方是否在房間內。
func is_peer_present() -> bool:
	return _peer_present


## Host 與 Client 之間的來回時間（msec，最近一次量測）；還沒量到時為 -1。
func get_rtt_msec() -> float:
	return _rtt_msec


static func normalize_code(text: String) -> String:
	return text.strip_edges().to_upper().replace(" ", "").replace("-", "")


## 輸入的文字是不是房間代碼（6 個英數字，不含 . 與 :），用來和 IP 區分。
static func looks_like_code(text: String) -> bool:
	var code: String = normalize_code(text)
	if code.length() != 6:
		return false
	for i in code.length():
		var c: int = code.unicode_at(i)
		var is_digit: bool = c >= 48 and c <= 57
		var is_letter: bool = c >= 65 and c <= 90
		if not (is_digit or is_letter):
			return false
	return true


func _join_url(base: String, path: String) -> String:
	return base.strip_edges().trim_suffix("/") + path


func _open(url: String) -> Error:
	var err: Error = _ws.connect_to_url(url)
	if err != OK:
		return err
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	var now: int = Time.get_ticks_msec()
	_connect_started_msec = now
	_last_relay_msg_msec = now
	_last_relay_ping_msec = now
	return OK


# ---- MultiplayerPeerExtension ----

func _poll() -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	_ws.poll()
	var now: int = Time.get_ticks_msec()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			if now - _connect_started_msec > CONNECT_TIMEOUT_MSEC:
				_fail(REASON_NETWORK)
		WebSocketPeer.STATE_OPEN:
			_read_messages(now)
			if _status != MultiplayerPeer.CONNECTION_DISCONNECTED:
				_send_heartbeats(now)
				_check_timeouts(now)
		WebSocketPeer.STATE_CLOSED:
			_fail(_close_reason())


func _close() -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close(1000, "leave")
		_ws.poll()
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_closed = true
	_packets.clear()


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _is_host and peer == CLIENT_ID:
		_kick_peer()
	elif not _is_host and peer == HOST_ID:
		_fail(REASON_HOST_LEFT)


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _get_unique_id() -> int:
	return HOST_ID if _is_host else CLIENT_ID


func _is_server() -> bool:
	return _is_host


func _is_server_relay_supported() -> bool:
	return false


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse_new = enable


func _is_refusing_new_connections() -> bool:
	return _refuse_new


func _get_max_packet_size() -> int:
	return MAX_PACKET_SIZE


func _set_target_peer(peer: int) -> void:
	_target_peer = peer


func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = channel


func _get_transfer_channel() -> int:
	return _transfer_channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_transfer_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _transfer_mode


func _get_available_packet_count() -> int:
	return _packets.size()


func _get_packet_script() -> PackedByteArray:
	if _packets.is_empty():
		return PackedByteArray()
	return _packets.pop_front()


## 房間只有兩個人，封包一定來自對方。
func _get_packet_peer() -> int:
	return _other_id()


func _get_packet_channel() -> int:
	return 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _put_packet_script(buffer: PackedByteArray) -> Error:
	var other: int = _other_id()
	if _target_peer < 0 and -_target_peer == other:
		return OK  # 「除了某人以外」而那個人就是對方：沒有人要收
	if _target_peer > 0 and _target_peer != other:
		return ERR_INVALID_PARAMETER
	if _status != MultiplayerPeer.CONNECTION_CONNECTED or not _peer_present:
		return OK if _target_peer == 0 else ERR_UNCONFIGURED
	var frame := PackedByteArray([FRAME_DATA])
	frame.append_array(buffer)
	return _ws.send(frame)


# ---- 收訊息 ----

func _read_messages(now: int) -> void:
	while _ws.get_ready_state() == WebSocketPeer.STATE_OPEN and _ws.get_available_packet_count() > 0:
		var bytes: PackedByteArray = _ws.get_packet()
		_last_relay_msg_msec = now
		if _ws.was_string_packet():
			_on_control(bytes.get_string_from_utf8(), now)
		else:
			_on_frame(bytes, now)
		if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			return


func _on_control(text: String, now: int) -> void:
	if text == "pong":
		return
	var message: Variant = JSON.parse_string(text)
	if message is not Dictionary:
		return
	match str(message.get("type", "")):
		"hosted":
			_code = str(message.get("code", ""))
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			room_code_received.emit(_code)
		"joined":
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			_peer_arrived(now)
		"peer_joined":
			_peer_arrived(now)
		"peer_left":
			_peer_gone()


func _on_frame(bytes: PackedByteArray, now: int) -> void:
	if bytes.is_empty():
		return
	_last_peer_msg_msec = now
	match bytes[0]:
		FRAME_DATA:
			if _peer_present:
				_packets.append(bytes.slice(1))
		FRAME_PING:
			var pong := PackedByteArray([FRAME_PONG])
			pong.append_array(bytes.slice(1))
			_ws.send(pong)
		FRAME_PONG:
			if bytes.size() >= 9:
				_rtt_msec = float(now - int(bytes.decode_u64(1)))


func _peer_arrived(now: int) -> void:
	_peer_present = true
	_last_peer_msg_msec = now
	_last_peer_ping_msec = 0
	_rtt_msec = -1.0
	peer_connected.emit(_other_id())


func _peer_gone() -> void:
	if not _peer_present:
		return
	_peer_present = false
	_packets.clear()
	_rtt_msec = -1.0
	peer_disconnected.emit(_other_id())


# ---- 心跳與逾時 ----

func _send_heartbeats(now: int) -> void:
	if now - _last_relay_ping_msec >= RELAY_PING_INTERVAL_MSEC:
		_last_relay_ping_msec = now
		_ws.send_text("ping")
	if _peer_present and now - _last_peer_ping_msec >= PEER_PING_INTERVAL_MSEC:
		_last_peer_ping_msec = now
		var ping := PackedByteArray([FRAME_PING])
		ping.resize(9)
		ping.encode_u64(1, now)
		_ws.send(ping)


func _check_timeouts(now: int) -> void:
	if now - _last_relay_msg_msec > RELAY_TIMEOUT_MSEC:
		_fail(REASON_NETWORK)
	elif _peer_present and now - _last_peer_msg_msec > PEER_TIMEOUT_MSEC:
		if _is_host:
			_kick_peer()
		else:
			_fail(REASON_HOST_LEFT)


## Host 發現 Client 沒回應：通知中繼把它的連線關掉，才能讓下一位加入。
func _kick_peer() -> void:
	_ws.send_text(JSON.stringify({"type": "kick"}))
	_peer_gone()


func _close_reason() -> String:
	match _ws.get_close_reason():
		REASON_ROOM_NOT_FOUND:
			return REASON_ROOM_NOT_FOUND
		REASON_ROOM_FULL:
			return REASON_ROOM_FULL
		REASON_HOST_LEFT:
			return REASON_HOST_LEFT
	return REASON_NETWORK


func _fail(reason: String) -> void:
	if _closed:
		return
	_peer_gone()
	_close()
	relay_closed.emit(reason)


func _other_id() -> int:
	return CLIENT_ID if _is_host else HOST_ID
