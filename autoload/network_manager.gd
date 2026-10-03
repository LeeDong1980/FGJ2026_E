extends Node
## 區網雙機連線：Host 建立房間（也是玩家），Client 輸入 IP 加入。
## 目前只支援 2 人（1 個 Host + 1 個 Client）。

signal hosting_started
signal joined_server
signal join_failed
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal disconnected
## Host 端：收到 Client 的語音輸入封包
signal voice_volume_received(peer_id: int, seq: int, volume: float)
signal voice_word_received(peer_id: int, seq: int, word: String)
## Host 端：偵測到音量封包掉包（序號不連續）
signal voice_packets_lost(peer_id: int, count: int)
## Client 端：Host 已確認收到封包，rtt_msec 為來回時間
signal voice_ack_received(kind: String, seq: int, rtt_msec: int)
## Client 端：封包送出後超過 ACK_TIMEOUT_MSEC 沒有收到 Host 確認
signal voice_ack_timeout(kind: String, seq: int)

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 1
const ACK_TIMEOUT_MSEC: int = 2000
const KIND_VOLUME: String = "volume"
const KIND_WORD: String = "word"

var port: int = DEFAULT_PORT

var _seq: Dictionary = {KIND_VOLUME: 0, KIND_WORD: 0}
var _pending: Dictionary = {}  # "kind:seq" -> 送出時間（msec）
var _last_volume_seq: Dictionary = {}  # peer_id -> 最後收到的音量封包序號


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: joined_server.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(_delta: float) -> void:
	if _pending.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	for key: String in _pending.keys():
		if now - int(_pending[key]) > ACK_TIMEOUT_MSEC:
			_pending.erase(key)
			var parts: PackedStringArray = key.split(":")
			voice_ack_timeout.emit(parts[0], int(parts[1]))


func host_game() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	hosting_started.emit()
	return OK


func join_game(ip: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip.strip_edges(), port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	multiplayer.multiplayer_peer = null
	_reset_voice_state()
	disconnected.emit()


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func is_online() -> bool:
	return multiplayer.has_multiplayer_peer()


## 本機的區網 IPv4 位址（排除 127.x 與 169.254.x），給 Host 顯示讓 Client 輸入。
func get_local_ips() -> PackedStringArray:
	var result := PackedStringArray()
	for address: String in IP.get_local_addresses():
		var parts: PackedStringArray = address.split(".")
		if parts.size() != 4:
			continue
		if address.begins_with("127.") or address.begins_with("169.254."):
			continue
		result.append(address)
	return result


## Client 送出音量（0.0～1.0）。不可靠傳輸，掉包不補送，適合高頻率持續傳送。
func send_voice_volume(volume: float) -> void:
	if not is_online() or is_host():
		return
	var seq: int = _next_seq(KIND_VOLUME)
	_rpc_voice_volume.rpc_id(1, seq, volume)


## Client 送出字音（"吸"／"吐"）。可靠傳輸，保證送達且不重複。
func send_voice_word(word: String) -> void:
	if not is_online() or is_host():
		return
	var seq: int = _next_seq(KIND_WORD)
	_rpc_voice_word.rpc_id(1, seq, word)


## Client 到 Host 的來回時間（msec）；尚未連上時回傳 -1。
func get_rtt_msec() -> float:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null or is_host():
		return -1.0
	var packet_peer: ENetPacketPeer = peer.get_peer(1)
	if packet_peer == null:
		return -1.0
	return packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)


func _next_seq(kind: String) -> int:
	var seq: int = int(_seq[kind]) + 1
	_seq[kind] = seq
	_pending["%s:%d" % [kind, seq]] = Time.get_ticks_msec()
	return seq


func _reset_voice_state() -> void:
	_seq = {KIND_VOLUME: 0, KIND_WORD: 0}
	_pending.clear()
	_last_volume_seq.clear()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_voice_volume(seq: int, volume: float) -> void:
	if not multiplayer.is_server():
		return
	var id: int = multiplayer.get_remote_sender_id()
	var last: int = int(_last_volume_seq.get(id, 0))
	if seq > last + 1:
		voice_packets_lost.emit(id, seq - last - 1)
	_last_volume_seq[id] = maxi(seq, last)
	voice_volume_received.emit(id, seq, volume)
	_rpc_voice_ack.rpc_id(id, KIND_VOLUME, seq)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_voice_word(seq: int, word: String) -> void:
	if not multiplayer.is_server():
		return
	var id: int = multiplayer.get_remote_sender_id()
	voice_word_received.emit(id, seq, word)
	_rpc_voice_ack.rpc_id(id, KIND_WORD, seq)


@rpc("authority", "call_remote", "reliable")
func _rpc_voice_ack(kind: String, seq: int) -> void:
	var key: String = "%s:%d" % [kind, seq]
	if not _pending.has(key):
		return  # 已經逾時回報過
	var rtt: int = Time.get_ticks_msec() - int(_pending[key])
	_pending.erase(key)
	voice_ack_received.emit(kind, seq, rtt)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	join_failed.emit()


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	_reset_voice_state()
	disconnected.emit()
