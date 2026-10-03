extends Control
## 大廳：建立房間或輸入 Host 的 IP 加入。

@onready var _ip_input: LineEdit = %IpInput
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _leave_button: Button = %LeaveButton
@onready var _local_ip_label: Label = %LocalIpLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	NetworkManager.hosting_started.connect(_on_hosting_started)
	NetworkManager.joined_server.connect(func() -> void: _set_connected("已連上房間，等待遊戲開始"))
	NetworkManager.join_failed.connect(_on_join_failed)
	NetworkManager.peer_joined.connect(func(_id: int) -> void: _set_connected("對方已加入，可以開始"))
	NetworkManager.peer_left.connect(_on_peer_left)
	NetworkManager.disconnected.connect(_on_disconnected)
	_show_idle()


func _show_idle() -> void:
	_host_button.disabled = false
	_join_button.disabled = false
	_ip_input.editable = true
	_leave_button.visible = false
	_local_ip_label.text = ""
	_status_label.text = "建立房間，或輸入對方的 IP 加入"


func _set_connected(text: String) -> void:
	_status_label.text = text
	_host_button.disabled = true
	_join_button.disabled = true
	_ip_input.editable = false
	_leave_button.visible = true


func _on_host_pressed() -> void:
	var err: Error = NetworkManager.host_game()
	if err != OK:
		_status_label.text = "建立房間失敗（%s），port 可能被占用" % error_string(err)


func _on_hosting_started() -> void:
	var ips: PackedStringArray = NetworkManager.get_local_ips()
	_local_ip_label.text = "本機 IP：%s　Port：%d" % [", ".join(ips), NetworkManager.port]
	_set_connected("房間已建立，等待對方加入")


func _on_join_pressed() -> void:
	var err: Error = NetworkManager.join_game(_ip_input.text)
	if err != OK:
		_status_label.text = "無法連線（%s），請檢查 IP" % error_string(err)
		return
	_set_connected("連線中…")


func _on_join_failed() -> void:
	_show_idle()
	_status_label.text = "連線失敗，請確認 IP、同一個網路與防火牆"


func _on_peer_left(_id: int) -> void:
	if NetworkManager.is_host():
		_status_label.text = "對方已離開，等待重新加入"


func _on_leave_pressed() -> void:
	NetworkManager.leave()


func _on_disconnected() -> void:
	_show_idle()
	_status_label.text = "已中斷連線"
