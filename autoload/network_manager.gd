extends Node
## 區網雙機連線：Host 建立房間（也是玩家），Client 輸入 IP 加入。
## 目前只支援 2 人（1 個 Host + 1 個 Client）。

signal hosting_started
signal joined_server
signal join_failed
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal disconnected

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 1

var port: int = DEFAULT_PORT


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: joined_server.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


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


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	join_failed.emit()


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	disconnected.emit()
