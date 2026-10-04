class_name GameStateSender
extends Node
## Host 端：把遊戲狀態傳給 Client，讓 Client 重現同樣的畫面（NET-19）。格式見 game_sync.gd。
## 只在 Host 的連線局啟用；單機與直接 F6 執行遊戲場景時什麼都不做。
##
## 目前傳送：龍（目標層、位置、暈眩與無敵）、完成鍋數與清空次數、龍頭朝向、火冰元素、遊戲狀態與勝敗。
## 之後各階段加入：鍋子、胃袋、食材、特效事件。

@export var game_manager: GameManager
@export var dragon: Dragon

var _snapshot_timer: float = 0.0
var _full_timer: float = 0.0
var _last_target: int = -1


func _ready() -> void:
	if RoomManager.role != RoomManager.Role.HOST or RoomManager.phase != RoomManager.Phase.MATCH:
		set_process(false)
		return
	NetworkManager.state_requested.connect(send_full)
	game_manager.game_started.connect(_on_game_started)
	game_manager.completed_count_changed.connect(func(v: int) -> void: _event(GameSync.EV_COMPLETED, v))
	game_manager.cleared_count_changed.connect(func(v: int) -> void: _event(GameSync.EV_CLEARED, v))
	game_manager.facing_changed.connect(func(v: GameManager.Facing) -> void: _event(GameSync.EV_FACING, v))
	game_manager.element_changed.connect(func(v: GameManager.Element) -> void: _event(GameSync.EV_ELEMENT, v))
	game_manager.dragon_stunned.connect(func() -> void: _event(GameSync.EV_STUNNED))
	game_manager.dragon_recovered.connect(func() -> void: _event(GameSync.EV_RECOVERED))
	game_manager.game_won.connect(func() -> void: _event(GameSync.EV_WON))
	game_manager.game_lost.connect(func() -> void: _event(GameSync.EV_LOST))


func _process(delta: float) -> void:
	# 龍的目標層一改變就送，不等快照
	if dragon.target_lane != _last_target:
		_last_target = dragon.target_lane
		_event(GameSync.EV_TARGET, _last_target)
	_snapshot_timer += delta
	if _snapshot_timer >= GameSync.SNAPSHOT_INTERVAL:
		_snapshot_timer = 0.0
		NetworkManager.send_state_snapshot(build_snapshot())
	_full_timer += delta
	if _full_timer >= GameSync.FULL_INTERVAL:
		send_full()


## 完整的離散狀態。
func build_full() -> Dictionary:
	return {
		"lane_count": game_manager.lane_layout.lane_count,
		"pots_to_win": game_manager.pots_to_win,
		"clears_to_lose": game_manager.clears_to_lose,
		"state": game_manager.state,
		"completed": game_manager.completed_count,
		"cleared": game_manager.cleared_count,
		"facing": game_manager.facing,
		"element": game_manager.element,
		"target": dragon.target_lane,
		"snapshot": build_snapshot(),
	}


## 連續變動的值。
func build_snapshot() -> Dictionary:
	return {
		"y": dragon.position.y,
		"stun": game_manager.stun_remaining,
		"inv": game_manager.invincible_remaining,
	}


func send_full() -> void:
	_full_timer = 0.0
	NetworkManager.send_state_full(build_full())


func _on_game_started() -> void:
	# 開局的完整狀態要先到，Client 才能先套用再收到「開始」事件
	send_full()
	_event(GameSync.EV_STARTED)


func _event(type: String, value: Variant = null) -> void:
	var event: Dictionary = {"t": type}
	if value != null:
		event["v"] = value
	NetworkManager.send_state_event(event)
