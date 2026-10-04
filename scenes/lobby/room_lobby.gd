class_name RoomLobby
extends Control
## 房間等候頁：Host 與 Client 共用，依角色顯示按鈕。流程規則見 docs/lobby-flow.md。
## 這裡只讀 RoomManager 的狀態、呼叫它的函式；換場景都由 RoomManager 處理，所以單獨按 F6 也能測試。

@onready var _player_label: Label = %PlayerLabel
@onready var _local_ip_label: Label = %LocalIpLabel
@onready var _status_label: Label = %StatusLabel
@onready var _solo_button: Button = %SoloButton
@onready var _join_box: Control = %JoinBox
@onready var _ip_input: LineEdit = %IpInput
@onready var _join_button: Button = %JoinButton
@onready var _start_button: Button = %StartButton
@onready var _leave_button: Button = %LeaveButton

## 等候頁自己的提示（例如沒填 IP），下次房間狀態改變時清除。
var _local_hint: String = ""


func _ready() -> void:
	_solo_button.pressed.connect(RoomManager.start_solo)
	_join_button.pressed.connect(_on_join_pressed)
	_ip_input.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	_start_button.pressed.connect(RoomManager.start_match)
	_leave_button.pressed.connect(_on_leave_pressed)
	RoomManager.room_changed.connect(_on_room_changed)
	# 單獨執行這個場景（F6）時還沒有房間，自動建立。
	if RoomManager.role == RoomManager.Role.NONE:
		RoomManager.enter_room(false)
	_refresh()


func _process(_delta: float) -> void:
	if RoomManager.phase == RoomManager.Phase.JOINING:
		_refresh_status()


func _on_room_changed() -> void:
	_local_hint = ""
	_refresh()


func _on_join_pressed() -> void:
	if _ip_input.text.strip_edges().is_empty():
		_local_hint = "請先輸入對方的 IP"
		_refresh_status()
		return
	RoomManager.join_room(_ip_input.text)


func _on_leave_pressed() -> void:
	if RoomManager.phase == RoomManager.Phase.JOINING:
		RoomManager.cancel_join()
	else:
		RoomManager.leave_room()


func _refresh() -> void:
	var is_host: bool = RoomManager.role == RoomManager.Role.HOST
	var joining: bool = RoomManager.phase == RoomManager.Phase.JOINING

	_player_label.text = "房內玩家：%d / 2" % RoomManager.get_player_count()
	_local_ip_label.text = _local_ip_text(is_host)

	# 以單機遊玩、加入別人房間：只有 Host，且房內只有自己時可按。
	_solo_button.visible = is_host or joining
	_solo_button.disabled = not RoomManager.can_start_solo()
	_join_box.visible = is_host or joining
	_join_button.disabled = not RoomManager.can_join_other()
	_ip_input.editable = RoomManager.can_join_other()

	# 開始遊戲：Host 滿 2 人才可按；Client 只顯示「等待房主開始」。
	_start_button.text = "開始遊戲" if is_host or joining else "等待房主開始"
	_start_button.disabled = not RoomManager.can_start_match()

	_leave_button.text = "取消連線" if joining else "離開"
	_refresh_status()


func _local_ip_text(is_host: bool) -> String:
	if not is_host or not NetworkManager.is_host():
		return ""
	return "本機 IP：%s　Port：%d" % [", ".join(NetworkManager.get_local_ips()), NetworkManager.port]


func _refresh_status() -> void:
	_status_label.text = _status_text()


func _status_text() -> String:
	if RoomManager.phase == RoomManager.Phase.JOINING:
		return "連線中…（剩 %d 秒）" % ceili(NetworkManager.get_join_remaining_sec())
	if not _local_hint.is_empty():
		return _local_hint
	var lines: PackedStringArray = []
	if not RoomManager.notice.is_empty():
		lines.append(RoomManager.notice)
	if not RoomManager.room_error.is_empty():
		lines.append(RoomManager.room_error)
	if RoomManager.role == RoomManager.Role.CLIENT:
		lines.append("已加入房間，等待房主開始遊戲")
	elif RoomManager.get_player_count() >= 2:
		lines.append("對方已加入，可以開始遊戲")
	else:
		lines.append("等待對方輸入你的 IP 加入，或選擇單機、加入別人的房間")
	return "\n".join(lines)
