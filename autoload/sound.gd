extends Node
## 音樂與音效（autoload，全域名稱 Sound）：BGM 從開遊戲就循環播放，換場景、暫停都不中斷（bus Music）。
## 所有按鈕自動加上滑過與按下的音效（bus SFX），依節點名稱選確認／取消／一般點擊（見 BUTTON_KINDS）；
## 想指定某顆按鈕的音效，就在節點設 metadata `ui_sound`（StringName，填 SOUNDS 的鍵，或 &"none" 不出聲）。
## 其他腳本用 Sound.play(&"notify") 播指定音效。每種音效有 4 個版本，每次隨機挑一個並微調音高。

const BGM_PATH := "res://SFX/BGM.mp3"
## 音效種類 → 檔名樣式（%d 換成 1～4）。換音效只要改這裡。
const SOUNDS: Dictionary[StringName, String] = {
	&"hover": "res://SFX/Hover/subtle_UI_hover_soun_#%d.wav",
	&"click": "res://SFX/Click_Select/soft_UI_button_click_#%d.wav",
	&"confirm": "res://SFX/Confirm_Accept/positive_UI_confirm__#%d.wav",
	&"cancel": "res://SFX/Cancel_Back/soft_UI_back_sound,__#%d.wav",
	&"open": "res://SFX/Open_Close/UI_window_opening_so_#%d.wav",
	&"close": "res://SFX/Open_Close/UI_window_closing_so_#%d.wav",
	&"notify": "res://SFX/Notification/friendly_game_notifi_#%d.wav",
	&"error": "res://SFX/Cancel_Back/firm_UI_cancel_sound_#%d.wav",
	&"toggle": "res://SFX/Click_Select/sharp_UI_selection_c_#%d.wav",
	&"popup": "res://SFX/Open_Close/small_popup_appearin_#%d.wav",
}
const VARIANTS := 4
## 按鈕節點名稱 → 按下時的音效。沒列到的按鈕播 click。
const BUTTON_KINDS: Dictionary[StringName, StringName] = {
	&"StartButton": &"confirm",
	&"SoloButton": &"confirm",
	&"HostButton": &"confirm",
	&"JoinButton": &"confirm",
	&"ActionButton": &"confirm",
	&"QuitButton": &"cancel",
	&"LeaveButton": &"cancel",
	# 開關視窗的按鈕由視窗本身播 open／close
	&"CloseButton": &"none",
	&"AudioButton": &"none",
}
## 同一種音效最多同時播幾個
const MAX_POLYPHONY := 4

var _bgm: AudioStreamPlayer
var _players: Dictionary[StringName, AudioStreamPlayer] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bgm()
	for kind in SOUNDS:
		_players[kind] = _create_player(kind)
	get_tree().node_added.connect(_on_node_added)
	_hook_existing(get_tree().root)
	# 暫停選單（autoload PauseMenu）開關時的音效
	var pause_menu := get_node_or_null(^"/root/PauseMenu") as CanvasLayer
	if pause_menu != null:
		pause_menu.visibility_changed.connect(func() -> void:
			play(&"open" if pause_menu.visible else &"close"))


## 播放一種音效（SOUNDS 的鍵）。
func play(kind: StringName) -> void:
	var player: AudioStreamPlayer = _players.get(kind)
	if player != null:
		player.play()


func _setup_bgm() -> void:
	var stream := load(BGM_PATH) as AudioStreamMP3
	if stream == null:
		push_warning("找不到 BGM：%s" % BGM_PATH)
		return
	stream.loop = true
	_bgm = AudioStreamPlayer.new()
	_bgm.stream = stream
	_bgm.bus = AudioSettings.MUSIC
	add_child(_bgm)
	_bgm.play()


func _create_player(kind: StringName) -> AudioStreamPlayer:
	var randomizer := AudioStreamRandomizer.new()
	randomizer.random_pitch = 1.05
	for i in range(1, VARIANTS + 1):
		var stream := load(SOUNDS[kind] % i) as AudioStream
		if stream != null:
			randomizer.add_stream(-1, stream)
	var player := AudioStreamPlayer.new()
	player.stream = randomizer
	player.bus = AudioSettings.SFX
	player.max_polyphony = MAX_POLYPHONY
	add_child(player)
	return player


func _hook_existing(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_existing(child)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	var kind: StringName = button.get_meta(&"ui_sound", BUTTON_KINDS.get(button.name, &"click"))
	if kind == &"none":
		return
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			play(&"hover"))
	button.pressed.connect(play.bind(kind))
