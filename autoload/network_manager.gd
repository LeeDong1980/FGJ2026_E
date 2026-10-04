extends Node
## 區網雙機連線：Host 建立房間（也是玩家），Client 輸入 IP 加入。
## 目前只支援 2 人（1 個 Host + 1 個 Client）。
## 房間流程（單機、加入、開局、斷線後去哪）由 RoomManager 負責，這裡只管連線與封包。

signal hosting_started
## Client 端：Host 已接受加入（不是只有 ENet 連上）。
signal joined_server
## Client 端：ENet 連不上 Host。
signal join_failed
## Client 端：Host 拒絕加入，reason 是給玩家看的原因（REASON_FULL、REASON_IN_MATCH）。
signal join_rejected(reason: String)
## Client 端：超過 join_timeout_sec 還沒加入成功。
signal join_timed_out
## Host 端：有 Client 被接受加入。被拒絕的連線不會發出。
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal disconnected
## Client 端：加入成功後，Host 突然斷線或網路中斷。
signal server_lost
## Client 端：Host 主動關閉房間。
signal room_closed_by_host
## Client 端：Host 開始或結束連線局。
signal match_started
signal match_ended
## Host 端：Client 的吸／吐動作改變（ACTION_INHALE、ACTION_EXHALE、ACTION_NONE）。Host 收到後會回覆確認。
signal voice_action_received(peer_id: int, action: String)
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
## 實際接受的 Client 只有 1 個；多留名額是為了讓多出來的連線收到「房間已滿」的原因，再被中斷。
const MAX_CONNECTIONS: int = 3
const ACK_TIMEOUT_MSEC: int = 2000
const KIND_VOLUME: String = "volume"
const KIND_WORD: String = "word"
const KIND_ACTION: String = "action"
const ACTION_NONE: String = "none"
const ACTION_INHALE: String = "inhale"
const ACTION_EXHALE: String = "exhale"
const REASON_FULL: String = "房間已滿"
const REASON_IN_MATCH: String = "對方遊戲中"
## 送出拒絕原因或關房通知後，等這麼久再中斷連線，讓可靠封包先送完。
const FLUSH_DELAY_SEC: float = 0.3
## ENet 判定對方斷線的時間（msec）。預設最久要 30 秒，區網太久，縮短成約 6 秒。
const PEER_TIMEOUT_MIN_MSEC: int = 3000
const PEER_TIMEOUT_MAX_MSEC: int = 6000

## 「嘗試連線」的秒數上限，超過就視為加入失敗。
@export var join_timeout_sec: float = 20.0

var port: int = DEFAULT_PORT
## Host 端：連線局進行中。有人連進來時回覆「對方遊戲中」。由 RoomManager 設定。
var match_in_progress: bool = false

var _seq: Dictionary = {KIND_VOLUME: 0, KIND_WORD: 0, KIND_ACTION: 0}
var _pending: Dictionary = {}  # "kind:seq" -> 送出時間（msec）
var _last_volume_seq: Dictionary = {}  # peer_id -> 最後收到的音量封包序號
var _accepted_peers: Array[int] = []
var _join_started_msec: int = -1


func _ready() -> void:
	# 流程與逾時不能因為暫停選單（get_tree().paused）而停住。
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void: _shorten_timeout(1))
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(_delta: float) -> void:
	if _join_started_msec >= 0 and get_join_remaining_sec() <= 0.0:
		_abort_join()
		join_timed_out.emit()
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
	var err: Error = peer.create_server(port, MAX_CONNECTIONS)
	if err != OK:
		return err
	_accepted_peers.clear()
	multiplayer.multiplayer_peer = peer
	hosting_started.emit()
	return OK


func join_game(ip: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip.strip_edges(), port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_join_started_msec = Time.get_ticks_msec()
	return OK


## 立刻中斷連線（關閉房間或離開房間）。Host 想先通知 Client，改用 close_room()。
func leave() -> void:
	_close_peer()
	_accepted_peers.clear()
	_join_started_msec = -1
	match_in_progress = false
	_reset_voice_state()
	disconnected.emit()


## Host 關閉房間：先通知 Client（讓對方知道是房主主動關的，不是斷線），稍等再中斷。
func close_room() -> void:
	if is_host() and not _accepted_peers.is_empty():
		for id: int in _accepted_peers:
			_rpc_room_closed.rpc_id(id)
		await get_tree().create_timer(FLUSH_DELAY_SEC).timeout
	leave()


## Host 開始連線局：之後再有人連進來會得到「對方遊戲中」。
func start_match() -> void:
	if not is_host():
		return
	match_in_progress = true
	for id: int in _accepted_peers:
		_rpc_match_started.rpc_id(id)


## Host 結束連線局，回到房間等候。
func end_match() -> void:
	if not is_host():
		return
	match_in_progress = false
	for id: int in _accepted_peers:
		_rpc_match_ended.rpc_id(id)


## Host 端：目前房內被接受的 Client 數（0 或 1）。
func get_client_count() -> int:
	return _accepted_peers.size()


## Client 端：距離加入逾時還剩幾秒；不在連線中時回傳 0。
func get_join_remaining_sec() -> float:
	if _join_started_msec < 0:
		return 0.0
	return join_timeout_sec - (Time.get_ticks_msec() - _join_started_msec) / 1000.0


## Client 送出吸／吐動作的開始與結束（ACTION_*）。可靠傳輸，噴火要靠它知道何時放開。
func send_voice_action(action: String) -> void:
	if not is_online() or is_host():
		return
	var seq: int = _next_seq(KIND_ACTION)
	_rpc_voice_action.rpc_id(1, seq, action)


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
	_seq = {KIND_VOLUME: 0, KIND_WORD: 0, KIND_ACTION: 0}
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


func _close_peer() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func _shorten_timeout(id: int) -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var packet_peer: ENetPacketPeer = peer.get_peer(id) if peer != null else null
	if packet_peer != null:
		packet_peer.set_timeout(32, PEER_TIMEOUT_MIN_MSEC, PEER_TIMEOUT_MAX_MSEC)


func _abort_join() -> void:
	_join_started_msec = -1
	_close_peer()


## Host 端：決定接受或拒絕新連線。
func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var reason: String = ""
	if match_in_progress:
		reason = REASON_IN_MATCH
	elif not _accepted_peers.is_empty():
		reason = REASON_FULL
	if reason != "":
		_rpc_join_rejected.rpc_id(id, reason)
		_disconnect_later(id)
		return
	_accepted_peers.append(id)
	_shorten_timeout(id)
	_rpc_join_accepted.rpc_id(id)
	peer_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not _accepted_peers.has(id):
		return  # 被拒絕的連線離開，不算房內的人
	_accepted_peers.erase(id)
	_last_volume_seq.erase(id)
	peer_left.emit(id)


func _disconnect_later(id: int) -> void:
	await get_tree().create_timer(FLUSH_DELAY_SEC).timeout
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer != null and multiplayer.is_server():
		peer.disconnect_peer(id)


func _on_connection_failed() -> void:
	_join_started_msec = -1
	_close_peer()
	join_failed.emit()


func _on_server_disconnected() -> void:
	var was_joined: bool = _join_started_msec < 0
	_join_started_msec = -1
	_close_peer()
	_reset_voice_state()
	disconnected.emit()
	if was_joined:
		server_lost.emit()
	else:
		join_failed.emit()  # 還沒被接受就被斷線


@rpc("authority", "call_remote", "reliable")
func _rpc_join_accepted() -> void:
	_join_started_msec = -1
	joined_server.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_join_rejected(reason: String) -> void:
	_abort_join()
	join_rejected.emit(reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_room_closed() -> void:
	leave()
	room_closed_by_host.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_match_started() -> void:
	match_started.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_match_ended() -> void:
	match_ended.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_voice_action(seq: int, action: String) -> void:
	if not multiplayer.is_server():
		return
	var id: int = multiplayer.get_remote_sender_id()
	voice_action_received.emit(id, action)
	_rpc_voice_ack.rpc_id(id, KIND_ACTION, seq)
