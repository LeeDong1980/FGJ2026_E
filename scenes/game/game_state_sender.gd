class_name GameStateSender
extends Node
## Host 端：把遊戲狀態傳給 Client，讓 Client 重現同樣的畫面（NET-19）。格式見 game_sync.gd。
## 只在 Host 的連線局啟用；單機與直接 F6 執行遊戲場景時什麼都不做。
##
## 目前傳送：龍（目標層、位置、暈眩與無敵）、完成鍋數與清空次數、龍頭朝向、火冰元素、遊戲狀態與勝敗、
## 鍋子與小龍、胃袋、噴吐狀態、食材（每層隊伍）與吸取、攻擊、冰凍、無效指令等事件。
## 食材的組成（誰在隊伍裡）只靠事件與完整狀態，快照只更新已存在食材的位置與進度，避免舊快照蓋掉新事件。

@export var game_manager: GameManager
@export var dragon: Dragon

## 房主坐玩家 1 時，持續把自己的音高傳給 Client，讓 Client 的 HUD 音高條有資料可顯示（不用來控制龍）。
var _pitch_input: PlayerPitchInput

var _snapshot_timer: float = 0.0
var _full_timer: float = 0.0
var _last_target: int = -1
var _last_spit: Array = [false, false]


func _ready() -> void:
	if RoomManager.role != RoomManager.Role.HOST or RoomManager.phase != RoomManager.Phase.MATCH:
		set_process(false)
		return
	if RoomManager.host_slot == 1:
		_pitch_input = PlayerPitchInput.new()
		_pitch_input.send_to_peer = true
		add_child(_pitch_input)
	NetworkManager.state_requested.connect(send_full)
	game_manager.game_started.connect(_on_game_started)
	game_manager.completed_count_changed.connect(func(v: int) -> void: _event(GameSync.EV_COMPLETED, v))
	game_manager.cleared_count_changed.connect(func(v: int) -> void: _event(GameSync.EV_CLEARED, v))
	game_manager.facing_changed.connect(func(v: GameManager.Facing) -> void: _event(GameSync.EV_FACING, v))
	game_manager.element_changed.connect(func(v: GameManager.Element) -> void: _event(GameSync.EV_ELEMENT, v))
	game_manager.dragon_stunned.connect(func() -> void: _event(GameSync.EV_STUNNED))
	game_manager.dragon_recovered.connect(func() -> void: _event(GameSync.EV_RECOVERED))
	game_manager.pot_changed.connect(func(lane: int) -> void: _event_with(GameSync.EV_POT, {"lane": lane, "pot": pot_to_dict(game_manager.get_pot(lane))}))
	game_manager.baby_left.connect(func(lane: int, reason: GameManager.BabyLeaveReason) -> void: _event_with(GameSync.EV_BABY_LEFT, {"lane": lane, "v": reason}))
	game_manager.baby_arrived.connect(func(lane: int) -> void: _event_with(GameSync.EV_BABY_ARRIVED, {"lane": lane}))
	game_manager.stomach_changed.connect(func(ingredient: IngredientState) -> void: _event(GameSync.EV_STOMACH, _type_of(ingredient)))
	game_manager.ingredient_spat.connect(func(lane: int, ingredient: IngredientState) -> void: _event_with(GameSync.EV_SPAT, {"lane": lane, "v": _type_of(ingredient)}))
	game_manager.ingredient_spawned.connect(func(lane: int, ingredient: IngredientState) -> void: _event_with(GameSync.EV_SPAWN, {"lane": lane, "id": ingredient.id, "type": ingredient.type, "x": ingredient.x}))
	game_manager.ingredient_removed.connect(func(lane: int, ingredient: IngredientState) -> void: _event_with(GameSync.EV_REMOVED, {"lane": lane, "id": ingredient.id}))
	game_manager.ingredient_swallowed.connect(func(lane: int, ingredient: IngredientState) -> void: _event_with(GameSync.EV_SWALLOWED, {"lane": lane, "v": ingredient.type}))
	game_manager.ingredient_burned.connect(func(lane: int, ingredient: IngredientState) -> void: _event_with(GameSync.EV_BURNED, {"lane": lane, "v": ingredient.type}))
	game_manager.ingredient_attacked.connect(func(lane: int, ingredient: IngredientState, hit: bool) -> void: _event_with(GameSync.EV_ATTACKED, {"lane": lane, "id": ingredient.id, "hit": hit}))
	game_manager.ingredient_frozen.connect(func(lane: int, ingredient: IngredientState) -> void: _event_with(GameSync.EV_FROZEN, {"lane": lane, "id": ingredient.id}))
	game_manager.suck_missed.connect(func(lane: int) -> void: _event_with(GameSync.EV_SUCK_MISSED, {"lane": lane}))
	game_manager.spit_missed.connect(func(lane: int) -> void: _event_with(GameSync.EV_SPIT_MISSED, {"lane": lane}))
	game_manager.action_missed.connect(func(lane: int, reason: GameManager.MissReason) -> void: _event_with(GameSync.EV_ACTION_MISSED, {"lane": lane, "v": reason}))
	game_manager.score_changed.connect(func(score: int, gained: int, fast: bool) -> void: _event_with(GameSync.EV_SCORE, {"v": score, "gained": gained, "fast": fast}))
	game_manager.game_won.connect(func() -> void: _event(GameSync.EV_WON))
	game_manager.game_lost.connect(func() -> void: _event(GameSync.EV_LOST))


func _process(delta: float) -> void:
	# 龍的目標層一改變就送，不等快照
	if dragon.target_lane != _last_target:
		_last_target = dragon.target_lane
		_event(GameSync.EV_TARGET, _last_target)
	# 噴吐狀態（正在喊吐、這次已吐進鍋子）一改變就送，特效與鍋子的跳動要靠它
	var spit: Array = [game_manager.is_spitting, game_manager.is_spit_used_for_pot()]
	if spit != _last_spit:
		_last_spit = spit
		_event(GameSync.EV_SPIT, spit)
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
		"score": game_manager.score,
		"completed": game_manager.completed_count,
		"cleared": game_manager.cleared_count,
		"facing": game_manager.facing,
		"element": game_manager.element,
		"target": dragon.target_lane,
		"pots": game_manager.pots.map(pot_to_dict),
		"lanes": game_manager.lanes.map(func(lane: LaneState) -> Array: return lane.queue.map(ingredient_to_array)),
		"stomach": _type_of(game_manager.stomach),
		"spit": [game_manager.is_spitting, game_manager.is_spit_used_for_pot()],
		"snapshot": build_snapshot(),
	}


## 連續變動的值。
func build_snapshot() -> Dictionary:
	return {
		"y": dragon.position.y,
		"stun": game_manager.stun_remaining,
		"inv": game_manager.invincible_remaining,
		"since": game_manager.since_last_pot,
		"cook": game_manager.pots.map(func(pot: PotState) -> float: return pot.cook_progress),
		"q": game_manager.lanes.map(func(lane: LaneState) -> Array: return lane.queue.map(ingredient_to_array)),
	}


## 一個食材：[編號, 種類, 位置, 燒毀進度, 攻擊蓄力進度, 冰凍剩餘秒數]。
func ingredient_to_array(ingredient: IngredientState) -> Array:
	return [ingredient.id, ingredient.type, ingredient.x, ingredient.burn_progress,
			ingredient.attack_progress, ingredient.freeze_remaining]


## 一個鍋子與旁邊小龍的資料（cook 是連續值，主要由快照更新）。
func pot_to_dict(pot: PotState) -> Dictionary:
	return {
		"forbidden": Array(pot.forbidden),
		"required": pot.required,
		"count": pot.count,
		"has_baby": pot.has_baby,
		"element": pot.element,
		"cook": pot.cook_progress,
	}


func send_full() -> void:
	_full_timer = 0.0
	NetworkManager.send_state_full(build_full())


func _on_game_started() -> void:
	# 開局的完整狀態要先到，Client 才能先套用再收到「開始」事件
	send_full()
	_event(GameSync.EV_STARTED)


## 食材的種類，null（胃空）是 -1。
func _type_of(ingredient: IngredientState) -> int:
	return -1 if ingredient == null else ingredient.type


func _event_with(type: String, fields: Dictionary) -> void:
	var event: Dictionary = fields.duplicate()
	event["t"] = type
	NetworkManager.send_state_event(event)


func _event(type: String, value: Variant = null) -> void:
	var event: Dictionary = {"t": type}
	if value != null:
		event["v"] = value
	NetworkManager.send_state_event(event)
