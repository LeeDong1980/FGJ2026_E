class_name GameStateReceiver
extends Node
## Client 端：把 Host 傳來的遊戲狀態套用到副本 GameManager（GameManager.replica），並發出和 Host 相同的 signal，
## 所有畫面元件（龍、HUD、特效、提示）不用改就能顯示一樣的畫面（NET-19）。格式見 game_sync.gd。
## 由 ClientViewBridge 在副本模式建立。

@export var game_manager: GameManager
@export var dragon: Dragon

## 開始事件或完整狀態已經讓 UI 進入遊玩狀態。
var _started: bool = false


func _ready() -> void:
	NetworkManager.state_full_received.connect(apply_full)
	NetworkManager.state_event_received.connect(apply_event)
	NetworkManager.state_snapshot_received.connect(apply_snapshot)
	# 場景載入完成才要完整狀態（等 GameManager 與各畫面元件都就緒）
	NetworkManager.request_state.call_deferred()


func apply_full(state: Dictionary) -> void:
	game_manager.pots_to_win = int(state.get("pots_to_win", game_manager.pots_to_win))
	game_manager.clears_to_lose = int(state.get("clears_to_lose", game_manager.clears_to_lose))
	game_manager.state = int(state.get("state", game_manager.state)) as GameManager.GameState
	_set_completed(int(state.get("completed", game_manager.completed_count)))
	_set_cleared(int(state.get("cleared", game_manager.cleared_count)))
	_set_facing(int(state.get("facing", game_manager.facing)) as GameManager.Facing)
	_set_element(int(state.get("element", game_manager.element)) as GameManager.Element)
	dragon.set_target_lane(int(state.get("target", dragon.target_lane)))
	apply_snapshot(state.get("snapshot", {}), true)
	# 晚進場時（Client 載入比 Host 開局慢），完整狀態已經是遊玩中，補發「開始」讓 UI 進入遊玩狀態
	if game_manager.state == GameManager.GameState.PLAYING:
		_emit_started()


func apply_event(event: Dictionary) -> void:
	var value: Variant = event.get("v")
	match event.get("t", ""):
		GameSync.EV_STARTED:
			game_manager.state = GameManager.GameState.PLAYING
			_emit_started()
		GameSync.EV_COMPLETED:
			_set_completed(int(value))
		GameSync.EV_CLEARED:
			_set_cleared(int(value))
		GameSync.EV_FACING:
			_set_facing(int(value) as GameManager.Facing)
		GameSync.EV_ELEMENT:
			_set_element(int(value) as GameManager.Element)
		GameSync.EV_TARGET:
			dragon.set_target_lane(int(value))
		GameSync.EV_STUNNED:
			game_manager.stun_remaining = game_manager.stun_time
			dragon.stunned = true
			game_manager.dragon_stunned.emit()
		GameSync.EV_RECOVERED:
			game_manager.stun_remaining = 0.0
			game_manager.invincible_remaining = game_manager.invincible_time
			dragon.stunned = false
			game_manager.dragon_recovered.emit()
		GameSync.EV_WON:
			_end(true)
		GameSync.EV_LOST:
			_end(false)


## 連續變動的值：龍的位置只在差太多時才硬拉，平時靠本機的移動預測，避免一格一格跳。
func apply_snapshot(snapshot: Dictionary, force_position: bool = false) -> void:
	if snapshot.is_empty():
		return
	var y: float = float(snapshot.get("y", dragon.position.y))
	if force_position or absf(dragon.position.y - y) > GameSync.DRAGON_SNAP_DISTANCE:
		dragon.position.y = y
	game_manager.stun_remaining = float(snapshot.get("stun", 0.0))
	game_manager.invincible_remaining = float(snapshot.get("inv", 0.0))
	dragon.stunned = game_manager.stun_remaining > 0.0


func _emit_started() -> void:
	if _started:
		return
	_started = true
	game_manager.game_started.emit()


func _end(won: bool) -> void:
	if game_manager.state == GameManager.GameState.ENDED:
		return
	game_manager.state = GameManager.GameState.ENDED
	if won:
		game_manager.game_won.emit()
	else:
		game_manager.game_lost.emit()


func _set_completed(value: int) -> void:
	if value == game_manager.completed_count:
		return
	game_manager.completed_count = value
	game_manager.completed_count_changed.emit(value)


func _set_cleared(value: int) -> void:
	if value == game_manager.cleared_count:
		return
	game_manager.cleared_count = value
	game_manager.cleared_count_changed.emit(value)


func _set_facing(value: GameManager.Facing) -> void:
	if value == game_manager.facing:
		return
	game_manager.facing = value
	game_manager.facing_changed.emit(value)


func _set_element(value: GameManager.Element) -> void:
	if value == game_manager.element:
		return
	game_manager.element = value
	game_manager.element_changed.emit(value)
