extends Control
## 遠端連線（中繼）測試：F6 單獨執行。一台按「公開房間」拿到代碼，另一台輸入代碼加入，
## 之後互送編號封包，驗證雙向傳輸、順序與來回時間。完整流程用等候頁（room_lobby）。
##
## 自動模式（給腳本測試，不開畫面操作）：命令列加
##   -- --auto=host | --auto=join --code=ABC234 | --auto=watch --code=ABC234 | --auto=diag [--relay-url=ws://127.0.0.1:8787]
## room_host／room_join：改走 RoomManager（等候頁用的流程）：Host 公開房間、對方加入與離開後取消公開，檢查回到區網房間。
## watch：加入後不結束，等 Host 消失，偵測到與房主斷線就算成功（驗證 Host 離開時 Client 會被通知）。
## 結果印在輸出，最後一行是 RESULT: OK 或 RESULT: FAIL（附原因），結束碼 0／1。

const SEND_COUNT: int = 20
const SEND_INTERVAL_SEC: float = 0.05
const AUTO_TIMEOUT_SEC: float = 40.0

var _log: RichTextLabel
var _url_input: LineEdit
var _code_input: LineEdit
var _publish_button: Button
var _join_button: Button
var _info: Label

var _received: Array[int] = []
var _sent_done: bool = false
var _auto: String = ""
var _auto_code: String = ""
var _auto_started_msec: int = 0
var _auto_peer_joined: bool = false
var _auto_finished: bool = false


func _ready() -> void:
	_build_ui()
	_url_input.text = NetworkManager.relay_url
	NetworkManager.public_room_opened.connect(_on_room_opened)
	NetworkManager.public_room_failed.connect(func(reason: String) -> void: _say("公開房間失敗：%s" % reason); _auto_fail("公開房間失敗：" + reason))
	NetworkManager.peer_joined.connect(_on_peer_joined)
	NetworkManager.peer_left.connect(func(_id: int) -> void: _say("對方離開"))
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.join_rejected.connect(func(reason: String) -> void: _say("加入被拒絕：%s" % reason); _auto_fail("join_rejected:" + reason))
	NetworkManager.join_failed.connect(func() -> void: _say("加入失敗"); _auto_fail("join_failed"))
	NetworkManager.server_lost.connect(func() -> void:
		_say("與房主斷線")
		if _auto == "watch":
			_auto_done(true, "")
		else:
			_auto_fail("server_lost"))
	NetworkManager.room_closed_by_host.connect(func() -> void: _say("房主關閉房間"))

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--auto="):
			_auto = arg.trim_prefix("--auto=")
		elif arg.begins_with("--code="):
			_auto_code = arg.trim_prefix("--code=")
	if not _auto.is_empty():
		_auto_started_msec = Time.get_ticks_msec()
		_start_auto.call_deferred()


func _process(_delta: float) -> void:
	var rtt: float = NetworkManager.get_rtt_msec()
	_info.text = "relay：%s　房間代碼：%s　來回：%s" % [
		"使用中" if NetworkManager.is_public_room() or NetworkManager.is_online() else "未連線",
		NetworkManager.get_room_code() if NetworkManager.get_room_code() != "" else "-",
		("%d ms" % int(rtt)) if rtt >= 0.0 else "-",
	]
	if not _auto.is_empty() and not _auto_finished and Time.get_ticks_msec() - _auto_started_msec > AUTO_TIMEOUT_SEC * 1000.0:
		_auto_fail("逾時（%d 秒）" % int(AUTO_TIMEOUT_SEC))


# ---- 操作 ----

func _on_publish_pressed() -> void:
	NetworkManager.relay_url = _url_input.text.strip_edges()
	var err: Error = NetworkManager.host_public_game()
	_say("公開房間…" if err == OK else "無法開始：%s" % error_string(err))


func _on_join_pressed() -> void:
	NetworkManager.relay_url = _url_input.text.strip_edges()
	var err: Error = NetworkManager.join_game(_code_input.text)
	_say("加入 %s…" % _code_input.text if err == OK else "無法開始：%s" % error_string(err))


func _on_diag_pressed() -> void:
	var diag := RelayDiagnostics.new()
	add_child(diag)
	diag.progress.connect(func(report: String) -> void: _log.text = report)
	diag.finished.connect(func(report: String, _ok: bool) -> void: print(report))
	var ok: bool = await diag.run(_url_input.text.strip_edges())
	diag.queue_free()
	if _auto == "diag":
		_auto_done(ok, "診斷未通過" if not ok else "")


func _on_leave_pressed() -> void:
	NetworkManager.close_room() if NetworkManager.is_host() else NetworkManager.leave()
	_say("已離開")


func _on_room_opened(code: String) -> void:
	_say("房間代碼：%s" % code)
	if _auto == "host":
		print("CODE=%s" % code)


func _on_peer_joined(_id: int) -> void:
	_say("對方已加入（Host 端）")
	_auto_peer_joined = true
	_start_sending()


func _on_joined_server() -> void:
	_say("已加入房間（Client 端）")
	_start_sending()


# ---- 測試封包 ----

func _start_sending() -> void:
	_sent_done = false
	for i in SEND_COUNT:
		_rpc_numbered.rpc(i)
		await get_tree().create_timer(SEND_INTERVAL_SEC).timeout
		if not NetworkManager.is_online():
			return
	_sent_done = true
	_check_auto_complete()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_numbered(index: int) -> void:
	_received.append(index)
	if _received.size() == SEND_COUNT:
		_say("收到 %d 個封包，順序%s" % [SEND_COUNT, "正確" if _in_order() else "錯誤"])
		_check_auto_complete()


func _in_order() -> bool:
	for i in _received.size():
		if _received[i] != i:
			return false
	return true


# ---- 自動模式 ----

func _start_auto() -> void:
	match _auto:
		"host":
			_on_publish_pressed()
		"join", "watch":
			_code_input.text = _auto_code
			_on_join_pressed()
		"diag":
			_on_diag_pressed()
		"room_host":
			RoomManager.room_changed.connect(_on_room_host_changed)
			RoomManager.enter_room(false)
			RoomManager.publish_room()
		"room_join":
			RoomManager.enter_room(false)
			RoomManager.room_changed.connect(_on_room_join_changed)
			RoomManager.join_room(_auto_code)
		_:
			_auto_fail("未知的 --auto 值：" + _auto)


var _room_host_stage: int = 0


## Host：拿到代碼 → 對方加入 → 對方離開 → 取消公開，回到區網房間。
func _on_room_host_changed() -> void:
	match _room_host_stage:
		0:
			if RoomManager.get_room_code() != "":
				_room_host_stage = 1
				print("CODE=%s" % RoomManager.get_room_code())
		1:
			if RoomManager.get_player_count() == 2:
				_room_host_stage = 2
		2:
			if RoomManager.get_player_count() == 1:
				_room_host_stage = 3
				RoomManager.unpublish_room()
				var lan_ok: bool = NetworkManager.is_host() and not RoomManager.is_room_public() \
						and NetworkManager.multiplayer.multiplayer_peer is ENetMultiplayerPeer
				_auto_done(lan_ok, "" if lan_ok else "取消公開後沒有回到區網房間")


## Client：用代碼加入成功（role 變成 CLIENT），或失敗時帶著原因。
func _on_room_join_changed() -> void:
	if RoomManager.role == RoomManager.Role.CLIENT:
		_auto_done(true, "")
	elif RoomManager.phase == RoomManager.Phase.ROOM and RoomManager.notice.begins_with("加入失敗"):
		_auto_done(false, RoomManager.notice)


func _check_auto_complete() -> void:
	if _auto.is_empty() or _auto == "watch" or _auto_finished or not _sent_done or _received.size() < SEND_COUNT:
		return
	_auto_done(_in_order(), "" if _in_order() else "封包順序錯誤")


func _auto_fail(reason: String) -> void:
	if not _auto.is_empty():
		_auto_done(false, reason)


func _auto_done(ok: bool, reason: String) -> void:
	if _auto.is_empty() or _auto_finished:
		return
	_auto_finished = true
	print("RESULT: OK" if ok else "RESULT: FAIL %s" % reason)
	# 讓最後一批封包有機會送出再結束。斷線後 RoomManager 可能已經換掉這個場景，所以用 autoload 的 tree。
	# 場景被換掉後，屬於這個場景的 await 會被取消，所以把計時器直接綁在 SceneTree.quit 上。
	var tree: SceneTree = NetworkManager.get_tree()
	tree.create_timer(0.5).timeout.connect(tree.quit.bind(0 if ok else 1))


# ---- 畫面 ----

func _say(text: String) -> void:
	print("[relay_test] ", text)
	if _log != null and _auto != "diag":
		_log.append_text(text + "\n")


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "遠端連線（中繼）測試"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_url_input = LineEdit.new()
	_url_input.placeholder_text = "中繼伺服器網址，例如 wss://….workers.dev"
	box.add_child(_url_input)

	var row1 := HBoxContainer.new()
	box.add_child(row1)
	_publish_button = Button.new()
	_publish_button.text = "公開房間（Host）"
	_publish_button.pressed.connect(_on_publish_pressed)
	row1.add_child(_publish_button)
	var diag_button := Button.new()
	diag_button.text = "連線診斷"
	diag_button.pressed.connect(_on_diag_pressed)
	row1.add_child(diag_button)
	var leave_button := Button.new()
	leave_button.text = "離開"
	leave_button.pressed.connect(_on_leave_pressed)
	row1.add_child(leave_button)

	var row2 := HBoxContainer.new()
	box.add_child(row2)
	_code_input = LineEdit.new()
	_code_input.placeholder_text = "房間代碼"
	_code_input.custom_minimum_size.x = 220
	row2.add_child(_code_input)
	_join_button = Button.new()
	_join_button.text = "用代碼加入（Client）"
	_join_button.pressed.connect(_on_join_pressed)
	row2.add_child(_join_button)

	_info = Label.new()
	box.add_child(_info)

	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	box.add_child(_log)
