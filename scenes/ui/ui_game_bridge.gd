class_name UIGameBridge
extends Node
## 把遊戲機制（GameManager、Dragon）與麥克風輸入（MicInput）的資料接到 UI。接口見 docs/api.md。
## 放進遊戲場景（scenes/game/main.tscn）時當作 GameManager 的子節點，game_manager 留空會自動使用父節點。
##
## 遊戲流程：場景載入後自動 start_game()（由 RoomManager 從等候頁切過來）；game_started 校正聲音並顯示遊玩狀態介面；
## game_won／game_lost 顯示遊戲結束介面；重新遊玩 → start_game()（原地重置）；回主選單 → RoomManager.return_to_menu()。
## 連線局由 NetworkGameBridge 接手結束畫面（回到房間）。

## 「下一關」要等關卡資料完成後才會提供（docs/api.md），目前成功時一律顯示「回主選單」。
const HAS_NEXT_LEVEL := false
## 鍋子資訊跟隨的位置：鍋子定位點往上這麼高（世界座標）。
const POT_ANCHOR_HEIGHT := 0.6

@export var game_manager: GameManager
@export var ui_root: UIRoot

## 玩家 1 的音高在對方電腦上時（連線局，房主坐玩家 2），由 NetworkGameBridge 持續餵進來（0～1）；
## 負值表示用本機的音高。
var remote_pitch_level: float = -1.0

var _hud: PlayHud
var _dragon: Dragon
var _was_spitting := false
var _calibrated := false


func _ready() -> void:
	if game_manager == null:
		game_manager = get_parent() as GameManager
	if ui_root == null:
		ui_root = get_node(^"UIRoot") as UIRoot
	_hud = ui_root.play_hud
	_dragon = game_manager.dragon

	# 重新遊玩與鍵盤 Enter（KeyboardInput）都只呼叫 start_game()，後續一律在 game_started 處理。
	ui_root.retry_requested.connect(game_manager.start_game)
	ui_root.next_level_requested.connect(game_manager.start_game)
	ui_root.back_requested.connect(RoomManager.return_to_menu)

	game_manager.game_started.connect(_on_game_started)
	game_manager.game_won.connect(_show_result.bind(true))
	game_manager.game_lost.connect(_show_result.bind(false))
	game_manager.completed_count_changed.connect(_on_completed_count_changed)
	game_manager.cleared_count_changed.connect(_on_cleared_count_changed)
	game_manager.pot_changed.connect(_refresh_pot)
	game_manager.baby_arrived.connect(_refresh_pot)
	game_manager.baby_left.connect(_on_baby_left)
	game_manager.ingredient_swallowed.connect(_show_suck.unbind(2))
	game_manager.suck_missed.connect(_show_suck.unbind(1))
	game_manager.ingredient_spat.connect(_show_spit.unbind(2))
	game_manager.spit_missed.connect(_show_spit.unbind(1))
	_dragon.current_lane_changed.connect(_hud.set_current_lane)

	# GameManager 開場的 signal 可能在連接前就發出了，先主動讀一次目前狀態（docs/api.md 注意事項）。
	_read_current_state.call_deferred()
	# 進入場景就直接開始；GameManager 的 _ready 要先跑完，所以延到下一個 idle。
	# 連線局由 NetworkGameBridge 開局，這裡不重複開。
	if RoomManager.phase != RoomManager.Phase.MATCH:
		_start_if_waiting.call_deferred()


func _process(_delta: float) -> void:
	# 玩家 2 還在出聲（語音吸／吐按住中，或按住噴火）時，字音保持亮著。
	_hud.word_held = game_manager.is_spitting or MicInput.action != &""
	if game_manager.state != GameManager.GameState.PLAYING:
		return
	_hud.set_volume(remote_pitch_level if remote_pitch_level >= 0.0 else _local_pitch_level())
	# 噴火沒有開始時的 signal，用 is_spitting 由 false 變 true 的瞬間顯示「吐」。
	if game_manager.is_spitting and not _was_spitting:
		_show_spit()
	_was_spitting = game_manager.is_spitting


func _start_if_waiting() -> void:
	if game_manager.state == GameManager.GameState.WAITING:
		game_manager.start_game()


## 本機玩家 1 的音高比例（0～1），與換層用的 PitchLaneInput 同一個來源：手機 1 有連上就用手機，否則電腦麥克風。
func _local_pitch_level() -> float:
	var voice: Node = MicInput
	if PhoneMic.is_player_connected(1):
		voice = PhoneMic.get_source(1)
	return voice.pitch_value / 100.0


func _on_game_started() -> void:
	# 進入遊戲後第一局校正聲音；重新遊玩不重新校正（design.md 未定事項）。
	# 開局音量校正由麥克風輸入提供（MIC-04），還沒完成時略過。
	if not _calibrated and MicInput.has_method(&"calibrate"):
		MicInput.call(&"calibrate")
	_calibrated = true
	_read_current_state()
	_hud.reset_word()
	ui_root.show_playing()


func _read_current_state() -> void:
	var lane_count := game_manager.lane_layout.lane_count
	_hud.setup_lanes(lane_count)
	_hud.set_pot_anchors(get_viewport().get_camera_3d(), _pot_anchor_positions(lane_count))
	for lane in lane_count:
		_refresh_pot(lane)
	_on_completed_count_changed(game_manager.completed_count)
	_on_cleared_count_changed(game_manager.cleared_count)
	_hud.set_current_lane(_dragon.current_lane)


## 各層鍋子上方的世界座標。
func _pot_anchor_positions(lane_count: int) -> Array[Vector3]:
	var layout := game_manager.lane_layout
	var positions: Array[Vector3] = []
	for lane in lane_count:
		var local := layout.get_anchor_position(lane, &"PotAnchor") + Vector3.UP * POT_ANCHOR_HEIGHT
		positions.append(layout.to_global(local))
	return positions


func _refresh_pot(lane: int) -> void:
	# setup_lanes() 之前（開場 _ready 階段）先略過，_read_current_state() 會補讀。
	if lane >= game_manager.pots.size() or lane >= _hud.get_lane_count():
		return
	var pot := game_manager.get_pot(lane)
	_hud.set_pot(lane, pot.forbidden, pot.count, pot.required)


func _on_completed_count_changed(count: int) -> void:
	_hud.set_completed(count, game_manager.pots_to_win)


func _on_cleared_count_changed(count: int) -> void:
	_hud.set_cleared(count, game_manager.clears_to_lose)


func _on_baby_left(lane: int, reason: GameManager.BabyLeaveReason) -> void:
	if reason == GameManager.BabyLeaveReason.COMPLETED:
		_hud.flash_pot_completed(lane)
	else:
		_hud.flash_pot_cleared(lane)


func _show_suck() -> void:
	_hud.show_word("吸")


func _show_spit() -> void:
	_hud.show_word("吐")
	# 吐進鍋子或吐空的 signal 已經顯示過，這一次按住不要在 _process 再顯示一次。
	_was_spitting = game_manager.is_spitting


func _show_result(success: bool) -> void:
	ui_root.show_result(success, HAS_NEXT_LEVEL, game_manager.completed_count, game_manager.pots_to_win,
			game_manager.cleared_count, game_manager.clears_to_lose)
