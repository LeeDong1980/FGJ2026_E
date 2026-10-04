class_name CloudflaredTunnel
extends Node
## 啟動 cloudflared Quick Tunnel，把本機的 port 公開成 https://xxx.trycloudflare.com（不需要 Cloudflare 帳號）。
## Host 在本機開 WebSocket 伺服器（127.0.0.1），Client 連這個網址，資料走 Cloudflare 台北機房。
## 只需要出站連線，不開 port，也不會跳 Windows 防火牆視窗。
##
## 用法：add_child(tunnel) 後 start(port)，等 url_ready 或 failed。節點離開場景樹時會關掉 cloudflared。
## cloudflared 執行檔的位置見 find_binary()。

## 網址已建立且 tunnel 已連上 Cloudflare，Client 可以開始連。
signal url_ready(url: String)
## 啟動失敗、逾時，或建立後 cloudflared 中途結束（此時 tunnel 已經不通）。reason 是給玩家看的原因。
signal failed(reason: String)

const READY_TIMEOUT_SEC: float = 40.0
const URL_PATTERN: String = "https://[a-z0-9-]+\\.trycloudflare\\.com"
const REGISTERED_MARK: String = "Registered tunnel connection"
const LOCATION_PATTERN: String = "location=([a-z0-9]+)"

## 找不到執行檔時的原因。
const REASON_NO_BINARY: String = "找不到 cloudflared 執行檔"

var url: String = ""
## cloudflared 連上的 Cloudflare 機房代碼（例如 khh01、tpe01），診斷延遲用。
var location: String = ""

var _pid: int = -1
var _thread: Thread
var _stderr: FileAccess
var _stdio: FileAccess
var _url_regex := RegEx.create_from_string(URL_PATTERN)
var _location_regex := RegEx.create_from_string(LOCATION_PATTERN)
var _lines: Array[String] = []
var _lines_mutex := Mutex.new()
var _started_msec: int = 0
## 已經發出 url_ready 或 failed 其中之一；建立後若 cloudflared 結束還會再發一次 failed。
var _finished: bool = false
var _ready: bool = false
var _stopping: bool = false
## 命令列加 --tunnel-debug 時，把 cloudflared 的輸出全部印出來。
var _debug: bool = OS.get_cmdline_user_args().has("--tunnel-debug")


## cloudflared 執行檔的位置，依序找：命令列 --cloudflared=路徑、遊戲旁的 cloudflared/ 資料夾（匯出版）、
## 專案的 tools/cloudflared/（開發時）、系統 PATH 的 cloudflared。找不到回傳空字串。
static func find_binary() -> String:
	var exe_name: String = "cloudflared.exe" if OS.get_name() == "Windows" else "cloudflared"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cloudflared="):
			return arg.trim_prefix("--cloudflared=")
	var candidates: PackedStringArray = [
		OS.get_executable_path().get_base_dir().path_join("cloudflared").path_join(exe_name),
		ProjectSettings.globalize_path("res://tools/cloudflared").path_join(exe_name),
	]
	for path: String in candidates:
		if FileAccess.file_exists(path):
			return path
	var output: Array = []
	var finder: String = "where" if OS.get_name() == "Windows" else "which"
	if OS.execute(finder, [exe_name], output) == 0 and not output.is_empty():
		return str(output[0]).strip_edges().get_slice("\n", 0)
	return ""


func start(local_port: int) -> Error:
	var binary: String = find_binary()
	if binary.is_empty():
		_fail(REASON_NO_BINARY)
		return ERR_FILE_NOT_FOUND
	var process: Dictionary = OS.execute_with_pipe(binary, [
		"tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:%d" % local_port,
	])
	if process.is_empty():
		_fail("無法啟動 cloudflared")
		return ERR_CANT_CREATE
	_pid = process["pid"]
	_stderr = process["stderr"]
	_stdio = process["stdio"]
	_started_msec = Time.get_ticks_msec()
	# 從管線讀取會卡住直到有資料，所以放在另一個執行緒，主執行緒只處理讀到的行。
	_thread = Thread.new()
	_thread.start(_read_lines)
	return OK


func stop() -> void:
	_stopping = true
	if _pid > 0:
		OS.kill(_pid)
		_pid = -1
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


func is_running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid)


func _exit_tree() -> void:
	stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		stop()


func _process(_delta: float) -> void:
	if _ready and _pid > 0 and not OS.is_process_running(_pid):
		_pid = -1
		_ready = false
		failed.emit("cloudflared 中途結束，連線已中斷")
		return
	if _finished or _pid <= 0:
		return
	_lines_mutex.lock()
	var lines: Array[String] = _lines.duplicate()
	_lines.clear()
	_lines_mutex.unlock()
	for line: String in lines:
		_handle_line(line)
	if _finished:
		return
	if not OS.is_process_running(_pid):
		_fail("cloudflared 意外結束")
	elif (Time.get_ticks_msec() - _started_msec) / 1000.0 > READY_TIMEOUT_SEC:
		_fail("建立 tunnel 逾時（%d 秒）。網路可能擋住 Cloudflare（UDP／TCP 7844）" % int(READY_TIMEOUT_SEC))


func _read_lines() -> void:
	while not _stopping and _stderr != null and _stderr.is_open():
		var line: String = _stderr.get_line()
		if line.is_empty():
			if _stderr.get_error() != OK or _stderr.eof_reached():
				return
			OS.delay_msec(50)
			continue
		_lines_mutex.lock()
		_lines.append(line)
		_lines_mutex.unlock()


func _handle_line(line: String) -> void:
	if _debug:
		print("[cloudflared] ", line)
	if url.is_empty():
		var found: RegExMatch = _url_regex.search(line)
		if found != null:
			url = found.get_string()
	var location_match: RegExMatch = _location_regex.search(line)
	if location_match != null:
		location = location_match.get_string(1)
	if line.contains(REGISTERED_MARK) and not url.is_empty():
		_finished = true
		_ready = true
		url_ready.emit(url)


func _fail(reason: String) -> void:
	if _finished:
		return
	_finished = true
	stop()
	failed.emit(reason)
