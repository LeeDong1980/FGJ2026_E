class_name RelayDiagnostics
extends Node
## 連線診斷：依序檢查能不能連到中繼伺服器，失敗時說明可能的原因。
## 1. HTTPS：DNS、TLS、防火牆（GET /health）  2. WebSocket 握手（/echo）  3. 來回時間（echo 5 次）
## 呼叫 run() 後用 await 等結果，或接 progress／finished。診斷只碰 /health 與 /echo，不會建立房間。

## 進行中的報告（每完成一步更新一次），給畫面顯示。
signal progress(report: String)
signal finished(report: String, ok: bool)

const STEP_TIMEOUT_SEC: float = 8.0
const ECHO_COUNT: int = 5
const SLOW_RTT_MSEC: float = 150.0

var _lines: PackedStringArray = []


## 回傳 true 表示三項都通過。
func run(relay_url: String) -> bool:
	_lines.clear()
	_add("中繼伺服器：%s" % relay_url)
	var ok: bool = await _check_https(relay_url)
	if ok:
		ok = await _check_websocket_and_echo(relay_url)
	_add("")
	_add("結果：連線正常，可以使用公開房間" if ok else "結果：目前這個網路無法使用公開房間")
	finished.emit("\n".join(_lines), ok)
	return ok


func _add(line: String) -> void:
	_lines.append(line)
	progress.emit("\n".join(_lines))


func _http_url(relay_url: String) -> String:
	return relay_url.replace("wss://", "https://").replace("ws://", "http://").trim_suffix("/")


func _check_https(relay_url: String) -> bool:
	var http := HTTPRequest.new()
	http.timeout = STEP_TIMEOUT_SEC
	add_child(http)
	var started: int = Time.get_ticks_msec()
	var err: Error = http.request(_http_url(relay_url) + "/health")
	if err != OK:
		http.queue_free()
		_add("✗ 1. HTTPS：無法送出要求（%s）" % error_string(err))
		return false
	var response: Array = await http.request_completed
	http.queue_free()
	var result: int = response[0]
	var code: int = response[1]
	var elapsed: int = Time.get_ticks_msec() - started
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_add("✓ 1. HTTPS 連線正常（%d ms）" % elapsed)
		return true
	_add("✗ 1. HTTPS：%s" % _http_failure_text(result, code))
	return false


func _http_failure_text(result: int, code: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "找不到伺服器位址。請確認網路已連線，或 DNS／VPN 是否擋住。"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "連不上伺服器。防火牆、公司或學校網路、VPN 可能擋住了對外連線。"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "加密連線失敗。電腦的日期時間是否正確？公司網路可能攔截了加密連線。"
		HTTPRequest.RESULT_TIMEOUT:
			return "等了 %d 秒沒有回應。網路太慢，或被防火牆丟棄封包。" % int(STEP_TIMEOUT_SEC)
		HTTPRequest.RESULT_SUCCESS:
			return "伺服器回應異常（HTTP %d）。請確認中繼伺服器網址是否正確。" % code
	return "失敗（錯誤碼 %d）。" % result


func _check_websocket_and_echo(relay_url: String) -> bool:
	var ws := WebSocketPeer.new()
	if ws.connect_to_url(relay_url.trim_suffix("/") + "/echo") != OK:
		_add("✗ 2. WebSocket：網址格式錯誤")
		return false
	var deadline: int = Time.get_ticks_msec() + int(STEP_TIMEOUT_SEC * 1000.0)
	while ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED or Time.get_ticks_msec() > deadline:
			_add("✗ 2. WebSocket：握手失敗。網路可以開網頁，但擋住了即時連線（WebSocket），請換網路或關閉 VPN／代理伺服器。")
			return false
		await get_tree().process_frame
	_add("✓ 2. WebSocket 握手成功")

	var rtts: Array[float] = []
	for i in ECHO_COUNT:
		var sent: int = Time.get_ticks_msec()
		ws.send_text("echo %d" % i)
		var got: bool = false
		deadline = sent + int(STEP_TIMEOUT_SEC * 1000.0)
		while not got and Time.get_ticks_msec() < deadline and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.poll()
			if ws.get_available_packet_count() > 0:
				ws.get_packet()
				got = true
			else:
				await get_tree().process_frame
		if not got:
			ws.close()
			_add("✗ 3. 來回測試：第 %d 次沒有收到回應，連線不穩或中途被切斷。" % (i + 1))
			return false
		rtts.append(float(Time.get_ticks_msec() - sent))
		await get_tree().create_timer(0.1).timeout
	ws.close()

	var total: float = 0.0
	for rtt: float in rtts:
		total += rtt
	var average: float = total / rtts.size()
	var slowest: float = rtts.max()
	if average > SLOW_RTT_MSEC:
		_add("△ 3. 來回時間平均 %d ms（最慢 %d ms），偏高，遊戲可能會有延遲感。" % [average, slowest])
	else:
		_add("✓ 3. 來回時間平均 %d ms（最慢 %d ms）" % [average, slowest])
	return true
