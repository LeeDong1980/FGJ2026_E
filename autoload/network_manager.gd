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
## 收到對方（坐玩家 1 的那一位）目前的音高。level 是 0～1，lane 是對應的層（0 是最低層，-1 是還沒有）。
## 等候頁與連線局的 HUD 用來顯示；連線局中 Host 也用 lane 控制龍。Host 與 Client 都會收到。
signal pitch_received(level: float, lane: int)
## Client 端：房主決定的座位分配。host_slot 是房主坐的座位（1 或 2），Client 坐另一個。
signal slot_assignment_received(host_slot: int)
## Host 端：Client 要求交換座位。
signal slot_swap_requested
## Client 端：收到 Host 傳來的遊戲狀態（畫面同步）。full 是完整狀態，event 是單一事件，snapshot 是定時快照。
## 內容的格式見 scenes/game/game_state_sender.gd。
signal state_full_received(state: Dictionary)
signal state_event_received(event: Dictionary)
signal state_snapshot_received(snapshot: Dictionary)
## Host 端：Client 的遊戲畫面載入完成，要求完整狀態。
signal state_requested
## Client 端：房主暫停或繼續遊戲（暫停時 Host 會忽略 Client 的吸／吐）。
signal host_pause_changed(paused: bool)
## 收到對方（坐玩家 2 的那一位）的吸／吐動作改變（ACTION_INHALE、ACTION_EXHALE、ACTION_NONE）。
## Client 送給 Host 的動作，Host 收到後會回覆確認；Host 在等候頁也會傳給 Client 顯示（peer_id 固定 1）。
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
## Client 的轉頭（玩家 1 大叫或按 4）與換元素（玩家 2 按 L），用 send_voice_word() 送出，Host 收 voice_word_received。
const WORD_TURN: String = "turn"
const WORD_ELEMENT: String = "element"
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


## 坐玩家 1 的人把自己的音高傳給對方（Host 傳給 Client，Client 傳給 Host）。
## 等候頁讓雙方一起測試，連線局中對方的 lane 會控制龍。不可靠傳輸，掉包不補送，要持續送。
func send_pitch(level: float, lane: int) -> void:
	if not is_online():
		return
	if is_host():
		for id: int in _accepted_peers:
			_rpc_pitch_down.rpc_id(id, level, lane)
	else:
		_rpc_pitch_up.rpc_id(1, level, lane)


## Host 把座位分配通知 Client（host_slot 是房主坐的座位，1 或 2）。
func send_slot_assignment(host_slot: int) -> void:
	if not is_host():
		return
	for id: int in _accepted_peers:
		_rpc_slot_assignment.rpc_id(id, host_slot)


## Client 要求交換座位，由 Host 決定並回傳新的分配。
func request_slot_swap() -> void:
	if not is_online() or is_host():
		return
	_rpc_slot_swap_request.rpc_id(1)


## Host 把完整遊戲狀態傳給 Client：Client 載入完成要求時、開局時、之後定期補送。可靠傳輸。
func send_state_full(state: Dictionary) -> void:
	if not is_host():
		return
	for id: int in _accepted_peers:
		_rpc_state_full.rpc_id(id, state)


## Host 把一個遊戲事件傳給 Client（食材生成、計數改變、勝敗…）。可靠傳輸，依序送達。
func send_state_event(event: Dictionary) -> void:
	if not is_host():
		return
	for id: int in _accepted_peers:
		_rpc_state_event.rpc_id(id, event)


## Host 定時把連續變動的狀態（龍的位置、食材位置與進度）傳給 Client。不可靠傳輸，掉包由下一個快照補上。
func send_state_snapshot(snapshot: Dictionary) -> void:
	if not is_host():
		return
	for id: int in _accepted_peers:
		_rpc_state_snapshot.rpc_id(id, snapshot)


## Client 的遊戲畫面載入完成，要求 Host 傳完整狀態。
func request_state() -> void:
	if not is_online() or is_host():
		return
	_rpc_state_request.rpc_id(1)


## Host 暫停或繼續遊戲時通知 Client，讓對方畫面顯示提示。
func send_pause_state(paused: bool) -> void:
	if not is_host():
		return
	for id: int in _accepted_peers:
		_rpc_pause_state.rpc_id(id, paused)


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


## 坐玩家 2 的人送出吸／吐動作的開始與結束（ACTION_*）。可靠傳輸，噴火要靠它知道何時放開。
## Client 送給 Host（有確認）；Host 只在等候頁需要傳給 Client 顯示（沒有確認）。
func send_voice_action(action: String) -> void:
	if not is_online():
		return
	if is_host():
		for id: int in _accepted_peers:
			_rpc_voice_action_down.rpc_id(id, action)
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


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_pitch_down(level: float, lane: int) -> void:
	pitch_received.emit(level, lane)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_pitch_up(level: float, lane: int) -> void:
	if multiplayer.is_server():
		pitch_received.emit(level, lane)


@rpc("authority", "call_remote", "reliable")
func _rpc_slot_assignment(host_slot: int) -> void:
	slot_assignment_received.emit(host_slot)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_slot_swap_request() -> void:
	if multiplayer.is_server():
		slot_swap_requested.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_voice_action_down(action: String) -> void:
	voice_action_received.emit(1, action)


@rpc("authority", "call_remote", "reliable")
func _rpc_state_full(state: Dictionary) -> void:
	state_full_received.emit(state)


@rpc("authority", "call_remote", "reliable")
func _rpc_state_event(event: Dictionary) -> void:
	state_event_received.emit(event)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_state_snapshot(snapshot: Dictionary) -> void:
	state_snapshot_received.emit(snapshot)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_state_request() -> void:
	if multiplayer.is_server():
		state_requested.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_pause_state(paused: bool) -> void:
	host_pause_changed.emit(paused)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_voice_action(seq: int, action: String) -> void:
	if not multiplayer.is_server():
		return
	var id: int = multiplayer.get_remote_sender_id()
	voice_action_received.emit(id, action)
	_rpc_voice_ack.rpc_id(id, KIND_ACTION, seq)
