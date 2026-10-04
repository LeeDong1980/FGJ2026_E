class_name RoomLobby
extends Control
## 房間等候頁：Host 與 Client 共用，依角色顯示按鈕。流程規則見 docs/lobby-flow.md。
## 這裡只讀 RoomManager 的狀態、呼叫它的函式；換場景都由 RoomManager 處理，所以單獨按 F6 也能測試。
##
## 左下玩家 1（音高）、右下玩家 2（吸／吐）的輸入顯示，讓兩位玩家進遊戲前先測試、一起熟悉：
## - 玩家 1 是 Host：Host 本機量音高，並以 NetworkManager.send_lobby_pitch 傳給 Client 顯示。
## - 玩家 2 是 Client：Client 本機的鍵盤 J／K 與麥克風送給 Host（PlayerActionInput），Host 收到後顯示。
## - Host 房內只有自己時（單機），玩家 2 的輸入也由 Host 本機負責。

const LANE_COUNT: int = 3
## 與 PitchLaneInput.hysteresis 的預設值相同，等候頁看到的層才會和遊戲內一致。
const PITCH_HYSTERESIS: float = 3.0
const PITCH_PHONE_PLAYER: int = 1
const PITCH_BROADCAST_INTERVAL: float = 1.0 / 15.0

@onready var _slot1_label: Label = %Slot1Label
@onready var _slot2_label: Label = %Slot2Label
@onready var _local_ip_label: Label = %LocalIpLabel
@onready var _status_label: Label = %StatusLabel
@onready var _solo_button: Button = %SoloButton
@onready var _join_box: Control = %JoinBox
@onready var _ip_input: LineEdit = %IpInput
@onready var _join_button: Button = %JoinButton
@onready var _start_button: Button = %StartButton
@onready var _leave_button: Button = %LeaveButton
@onready var _panels: PlayerInputPanels = %PlayerPanels

## 等候頁自己的提示（例如沒填 IP），下次房間狀態改變時清除。
var _local_hint: String = ""
var _action_input: PlayerActionInput
var _player1_lane: int = -1
var _broadcast_timer: float = 0.0


func _ready() -> void:
	_solo_button.pressed.connect(RoomManager.start_solo)
	_join_button.pressed.connect(_on_join_pressed)
	_ip_input.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	_start_button.pressed.connect(RoomManager.start_match)
	_leave_button.pressed.connect(_on_leave_pressed)
	RoomManager.room_changed.connect(_on_room_changed)
	NetworkManager.voice_action_received.connect(_on_remote_action)
	NetworkManager.lobby_pitch_received.connect(_on_lobby_pitch_received)

	# 玩家 2 的本機輸入（鍵盤與語音）。是否啟用、要不要送給 Host 依角色在 _refresh() 設定。
	_action_input = PlayerActionInput.new()
	_action_input.action_changed.connect(_panels.show_action)
	add_child(_action_input)

	# 單獨執行這個場景（F6）時還沒有房間，自動建立。
	if RoomManager.role == RoomManager.Role.NONE:
		RoomManager.enter_room(false)
	_refresh()


func _process(delta: float) -> void:
	if RoomManager.phase == RoomManager.Phase.JOINING:
		_refresh_status()
	if RoomManager.role == RoomManager.Role.HOST:
		_update_player1(delta)


func _exit_tree() -> void:
	MicInput.save_settings()


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


# ---- 玩家輸入顯示 ----

## Host：量自己的音高，換算成層顯示，並傳給 Client。
func _update_player1(delta: float) -> void:
	var voice: Node = MicInput
	if PhoneMic.is_player_connected(PITCH_PHONE_PLAYER):
		voice = PhoneMic.get_source(PITCH_PHONE_PLAYER)
	var level: float = 0.0
	if MicInput.pitch_input_enabled:
		level = voice.pitch_value / 100.0
		if voice.pitch_active:
			_player1_lane = PitchLaneInput.pick_lane(voice.pitch_value, LANE_COUNT, _player1_lane, PITCH_HYSTERESIS)
	else:
		_player1_lane = -1
	_panels.set_pitch(level, _player1_lane)

	_broadcast_timer += delta
	if _broadcast_timer >= PITCH_BROADCAST_INTERVAL:
		_broadcast_timer = 0.0
		NetworkManager.send_lobby_pitch(level, _player1_lane)


func _on_lobby_pitch_received(level: float, lane: int) -> void:
	if RoomManager.role == RoomManager.Role.CLIENT:
		_panels.set_pitch(level, lane)


## Host 收到 Client 的吸／吐。
func _on_remote_action(_peer_id: int, action: String) -> void:
	if RoomManager.role == RoomManager.Role.HOST:
		_panels.show_action(action)


# ---- 畫面 ----

func _refresh() -> void:
	var is_host: bool = RoomManager.role == RoomManager.Role.HOST
	var is_client: bool = RoomManager.role == RoomManager.Role.CLIENT
	var joining: bool = RoomManager.phase == RoomManager.Phase.JOINING
	var count: int = RoomManager.get_player_count()

	_slot1_label.text = "玩家 1：你（房主）" if is_host else "玩家 1：房主"
	_slot2_label.text = _slot2_text(is_client, joining, count)
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
	_refresh_player_inputs(is_host, is_client, joining, count)
	_refresh_status()


## 玩家 2 的輸入來源：Client 是自己；Host 單機時也是自己；Host 有 Client 時是對方。
func _refresh_player_inputs(is_host: bool, is_client: bool, joining: bool, count: int) -> void:
	var player2_is_mine: bool = is_client or (is_host and count == 1)
	_action_input.enabled = player2_is_mine and not joining
	_action_input.send_to_host = is_client

	_panels.set_player1("你的音高：對麥克風發出高低音" if is_host else "房主的音高", is_host)
	var player2_caption: String = "對方的吸／吐"
	if is_client:
		player2_caption = "你的吸／吐：喊「吸」「吐」，或按 J／K"
	elif player2_is_mine:
		player2_caption = "單機時由你操作：喊「吸」「吐」，或按 J／K"
	_panels.set_player2(player2_caption, player2_is_mine)


func _slot2_text(is_client: bool, joining: bool, count: int) -> String:
	if is_client:
		return "玩家 2：你"
	if joining:
		return "玩家 2：連線中…"
	if count >= 2:
		return "玩家 2：對方（已加入）"
	return "玩家 2：等待加入…"


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
