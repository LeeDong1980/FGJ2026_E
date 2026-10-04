class_name TunnelDirectory
extends Node
## 房間代碼目錄（Cloudflare Worker，見 relay_server/）：Host 登記 tunnel 網址並取得房間代碼，
## Client 用代碼查出網址後直連。目錄只在加入時查一次，遊戲封包不經過它，所以它的延遲不影響遊戲。
##
## Host：publish(relay_url, tunnel_url) → 等 code_ready。這個連線要一直保持：關閉（或 Host 離開）房間就消失。
## Client：resolve(relay_url, code) → 等 resolved（網址）或 resolve_failed（原因）。

## Host：房間代碼已取得且網址已登記。
signal code_ready(code: String)
## Host：向目錄登記失敗，或途中與目錄斷線（代碼失效，但已連上的遊戲不受影響）。
signal publish_failed(reason: String)
## Client：查到 Host 的 tunnel 網址（https://xxx.trycloudflare.com）。
signal resolved(tunnel_url: String)
signal resolve_failed(reason: String)

const TIMEOUT_MSEC: int = 10000
const PING_INTERVAL_MSEC: int = 4000
const REASON_NOT_FOUND: String = "找不到這個房間代碼，請確認是否輸入正確"
const REASON_UNREACHABLE: String = "連不上目錄伺服器，請檢查網路（可按「連線診斷」）"

var code: String = ""

var _ws: WebSocketPeer
var _tunnel_url: String = ""
var _started_msec: int = 0
var _last_ping_msec: int = 0
var _published: bool = false
var _failed: bool = false


## Host：向目錄註冊房間並登記 tunnel 網址。
func publish(relay_url: String, tunnel_url: String) -> Error:
	_tunnel_url = tunnel_url
	_ws = WebSocketPeer.new()
	var err: Error = _ws.connect_to_url(relay_url.trim_suffix("/") + "/host")
	if err == OK:
		_started_msec = Time.get_ticks_msec()
		_last_ping_msec = _started_msec
	return err


func stop() -> void:
	if _ws != null:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_ws.close(1000, "leave")
			_ws.poll()
		_ws = null


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var now: int = Time.get_ticks_msec()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			if now - _started_msec > TIMEOUT_MSEC:
				_fail_publish()
		WebSocketPeer.STATE_OPEN:
			while _ws != null and _ws.get_available_packet_count() > 0:
				_on_message(_ws.get_packet().get_string_from_utf8())
			if _ws != null and not _published and now - _started_msec > TIMEOUT_MSEC:
				_fail_publish()
			elif _ws != null and now - _last_ping_msec >= PING_INTERVAL_MSEC:
				_last_ping_msec = now
				_ws.send_text("ping")
		WebSocketPeer.STATE_CLOSED:
			_fail_publish()


func _on_message(text: String) -> void:
	if text == "pong":
		return
	var message: Variant = JSON.parse_string(text)
	if message is not Dictionary:
		return
	match str(message.get("type", "")):
		"hosted":
			code = str(message.get("code", ""))
			_ws.send_text(JSON.stringify({"type": "publish", "url": _tunnel_url}))
		"published":
			_published = true
			code_ready.emit(code)
		"peer_joined", "peer_left":
			pass  # 目錄的備援轉送路徑，原型先不用


func _fail_publish() -> void:
	if _failed:
		return
	_failed = true
	_ws = null
	publish_failed.emit(REASON_UNREACHABLE)


## Client：用房間代碼查 Host 的 tunnel 網址。
func resolve(relay_url: String, room_code: String) -> Error:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_MSEC / 1000.0
	add_child(http)
	http.request_completed.connect(_on_resolve_completed.bind(http))
	var base: String = relay_url.replace("wss://", "https://").replace("ws://", "http://").trim_suffix("/")
	var err: Error = http.request("%s/resolve/%s" % [base, room_code.strip_edges().to_upper()])
	if err != OK:
		http.queue_free()
	return err


func _on_resolve_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		resolve_failed.emit(REASON_UNREACHABLE)
		return
	if response_code == 404:
		resolve_failed.emit(REASON_NOT_FOUND)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if response_code != 200 or data is not Dictionary or str(data.get("url", "")).is_empty():
		resolve_failed.emit(REASON_UNREACHABLE)
		return
	resolved.emit(str(data["url"]))
