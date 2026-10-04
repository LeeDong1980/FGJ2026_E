class_name GameStateReceiver
extends Node
## Client 端：把 Host 傳來的遊戲狀態套用到副本 GameManager（GameManager.replica），並發出和 Host 相同的 signal，
## 所有畫面元件（龍、HUD、特效、提示）不用改就能顯示一樣的畫面（NET-19）。格式見 game_sync.gd。
## 由 ClientViewBridge 在副本模式建立。

@export var game_manager: GameManager
@export var dragon: Dragon
## HUD 的橋接。Client 坐玩家 2 時，玩家 1 的音高來自 Host，由這裡餵給 HUD 的音高條。
@export var ui_bridge: UIGameBridge

## 開始事件或完整狀態已經讓 UI 進入遊玩狀態。
var _started: bool = false


func _ready() -> void:
	NetworkManager.state_full_received.connect(apply_full)
	NetworkManager.state_event_received.connect(apply_event)
	NetworkManager.state_snapshot_received.connect(_on_snapshot_received)
	NetworkManager.pitch_received.connect(_on_pitch_received)
	# 場景載入完成才要完整狀態（等 GameManager 與各畫面元件都就緒）
	NetworkManager.request_state.call_deferred()


func _on_snapshot_received(snapshot: Dictionary) -> void:
	if GameSync.debug_snapshot_loss > 0.0 and randf() < GameSync.debug_snapshot_loss:
		return
	apply_snapshot(snapshot)


## 對方（坐玩家 1 的 Host）的音高，給 HUD 的音高條。自己坐玩家 1 時用本機音高，不用這個。
func _on_pitch_received(level: float, _lane: int) -> void:
	if ui_bridge != null and RoomManager.get_my_slot() == 2:
		ui_bridge.remote_pitch_level = level


func apply_full(state: Dictionary) -> void:
	game_manager.pots_to_win = int(state.get("pots_to_win", game_manager.pots_to_win))
	game_manager.clears_to_lose = int(state.get("clears_to_lose", game_manager.clears_to_lose))
	game_manager.state = int(state.get("state", game_manager.state)) as GameManager.GameState
	_set_completed(int(state.get("completed", game_manager.completed_count)))
	_set_cleared(int(state.get("cleared", game_manager.cleared_count)))
	_set_facing(int(state.get("facing", game_manager.facing)) as GameManager.Facing)
	_set_element(int(state.get("element", game_manager.element)) as GameManager.Element)
	dragon.set_target_lane(int(state.get("target", dragon.target_lane)))
	var pots: Array = state.get("pots", [])
	for lane in mini(pots.size(), game_manager.pots.size()):
		if _apply_pot(lane, pots[lane]):
			game_manager.pot_changed.emit(lane)
	_apply_lanes(state.get("lanes", []))
	_set_stomach(int(state.get("stomach", -1)), true)
	var spit: Array = state.get("spit", [false, false])
	game_manager.apply_replica_spit(bool(spit[0]), bool(spit[1]))
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
		GameSync.EV_POT:
			var lane: int = int(event["lane"])
			_apply_pot(lane, event["pot"])
			game_manager.pot_changed.emit(lane)
		GameSync.EV_BABY_LEFT:
			game_manager.baby_left.emit(int(event["lane"]), int(value) as GameManager.BabyLeaveReason)
		GameSync.EV_BABY_ARRIVED:
			game_manager.baby_arrived.emit(int(event["lane"]))
		GameSync.EV_STOMACH:
			_set_stomach(int(value))
		GameSync.EV_SPAT:
			game_manager.ingredient_spat.emit(int(event["lane"]), IngredientState.new(int(value) as IngredientType.Type, 0.0))
		GameSync.EV_SPIT:
			var spit: Array = value
			game_manager.apply_replica_spit(bool(spit[0]), bool(spit[1]))
		GameSync.EV_SPAWN:
			_spawn(int(event["lane"]), int(event["id"]), int(event["type"]), float(event["x"]))
		GameSync.EV_REMOVED:
			_remove(int(event["lane"]), int(event["id"]))
		GameSync.EV_SWALLOWED:
			game_manager.ingredient_swallowed.emit(int(event["lane"]), _placeholder(int(value)))
		GameSync.EV_BURNED:
			game_manager.ingredient_burned.emit(int(event["lane"]), _placeholder(int(value)))
		GameSync.EV_ATTACKED:
			var attacker := _find(int(event["lane"]), int(event["id"]))
			if attacker != null:
				game_manager.ingredient_attacked.emit(int(event["lane"]), attacker, bool(event["hit"]))
		GameSync.EV_FROZEN:
			var frozen := _find(int(event["lane"]), int(event["id"]))
			if frozen != null:
				game_manager.ingredient_frozen.emit(int(event["lane"]), frozen)
		GameSync.EV_SUCK_MISSED:
			game_manager.suck_missed.emit(int(event["lane"]))
		GameSync.EV_SPIT_MISSED:
			game_manager.spit_missed.emit(int(event["lane"]))
		GameSync.EV_ACTION_MISSED:
			game_manager.action_missed.emit(int(event["lane"]), int(value) as GameManager.MissReason)
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
	_apply_queue_snapshot(snapshot.get("q", []))
	# 鍋子煮的進度（連續值）
	var cook: Array = snapshot.get("cook", [])
	for lane in mini(cook.size(), game_manager.pots.size()):
		game_manager.pots[lane].cook_progress = float(cook[lane])


## 完整狀態裡的食材隊伍：和本機比對，缺的補上、多的移除（發出 spawned／removed，畫面元件就會跟著增減模型），
## 已存在的更新位置與進度。每個食材是 [編號, 種類, 位置, 燒毀, 攻擊蓄力, 冰凍]。
func _apply_lanes(lanes_data: Array) -> void:
	for lane in mini(lanes_data.size(), game_manager.lanes.size()):
		var wanted: Array = lanes_data[lane]
		var wanted_ids: Array = wanted.map(func(item: Array) -> int: return int(item[0]))
		for ingredient: IngredientState in game_manager.lanes[lane].queue.duplicate():
			if not wanted_ids.has(ingredient.id):
				_remove(lane, ingredient.id)
		for item: Array in wanted:
			var ingredient := _find(lane, int(item[0]))
			if ingredient == null:
				ingredient = _spawn(lane, int(item[0]), int(item[1]), float(item[2]))
			_update_ingredient(ingredient, item)


## 快照裡的食材：只更新已存在的食材，不增減（增減靠事件與完整狀態）。
func _apply_queue_snapshot(queues: Array) -> void:
	for lane in mini(queues.size(), game_manager.lanes.size()):
		for item: Array in queues[lane]:
			var ingredient := _find(lane, int(item[0]))
			if ingredient != null:
				_update_ingredient(ingredient, item)


func _update_ingredient(ingredient: IngredientState, item: Array) -> void:
	# 位置靠本機沿隊伍走的預測，差太多才硬拉，避免一格一格跳
	var x: float = float(item[2])
	if absf(ingredient.x - x) > GameSync.INGREDIENT_SNAP_DISTANCE:
		ingredient.x = x
	ingredient.burn_progress = float(item[3])
	ingredient.attack_progress = float(item[4])
	ingredient.freeze_remaining = float(item[5])


func _find(lane: int, id: int) -> IngredientState:
	if lane < 0 or lane >= game_manager.lanes.size():
		return null
	for ingredient: IngredientState in game_manager.lanes[lane].queue:
		if ingredient.id == id:
			return ingredient
	return null


func _spawn(lane: int, id: int, type: int, x: float) -> IngredientState:
	var existing := _find(lane, id)
	if existing != null:
		return existing
	var ingredient := IngredientState.new(type as IngredientType.Type, x)
	ingredient.id = id
	game_manager.lanes[lane].queue.append(ingredient)
	game_manager.ingredient_spawned.emit(lane, ingredient)
	return ingredient


func _remove(lane: int, id: int) -> void:
	var ingredient := _find(lane, id)
	if ingredient == null:
		return
	game_manager.lanes[lane].queue.erase(ingredient)
	game_manager.ingredient_removed.emit(lane, ingredient)


## 被吞下或燒掉時 signal 帶的食材（食材本身已經由 removed 事件離開隊伍）；畫面元件只用到種類與所在層。
func _placeholder(type: int) -> IngredientState:
	return IngredientState.new(type as IngredientType.Type, 0.0)


## 套用一個鍋子的資料，回傳有沒有任何欄位改變（煮的進度不算，那是連續值）。
func _apply_pot(lane: int, data: Dictionary) -> bool:
	if lane < 0 or lane >= game_manager.pots.size():
		return false
	var pot: PotState = game_manager.pots[lane]
	var forbidden: Array = data.get("forbidden", [])
	var changed: bool = Array(pot.forbidden) != forbidden \
			or pot.required != int(data.get("required", 0)) \
			or pot.count != int(data.get("count", 0)) \
			or pot.has_baby != bool(data.get("has_baby", false)) \
			or pot.element != int(data.get("element", 0))
	pot.forbidden.assign(forbidden)
	pot.required = int(data.get("required", 0))
	pot.count = int(data.get("count", 0))
	pot.has_baby = bool(data.get("has_baby", false))
	pot.element = int(data.get("element", 0)) as GameManager.Element
	pot.cook_progress = float(data.get("cook", 0.0))
	return changed


## 胃袋裡的食材。type 是 -1 表示胃空。quiet 為 true 時內容沒變就不發 signal（完整狀態對帳用）。
func _set_stomach(type: int, quiet: bool = false) -> void:
	var current: int = -1 if game_manager.stomach == null else game_manager.stomach.type
	if quiet and type == current:
		return
	game_manager.stomach = null if type < 0 else IngredientState.new(type as IngredientType.Type, 0.0)
	game_manager.stomach_changed.emit(game_manager.stomach)


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
