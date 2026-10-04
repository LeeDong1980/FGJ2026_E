class_name GameManager
extends Node3D
## 保存並推進遊戲狀態：各層的食材隊伍、鍋子與小龍、龍的胃袋、勝敗。畫面只讀這裡的資料。
## 對外接口的說明見 docs/api.md。

enum GameState { WAITING, PLAYING, ENDED }
enum BabyLeaveReason { COMPLETED, KICKED }
## 龍頭朝向：LEFT 面向食材隊伍，RIGHT 面向鍋子。目前只有狀態與畫面提示，龍的模型不會轉。
enum Facing { LEFT, RIGHT }

## start_game() 之後發出，此時已重置完畢並開始遊玩。
signal game_started

signal ingredient_spawned(lane: int, ingredient: IngredientState)
## 食材離開隊伍（被吞下或燒掉）。
signal ingredient_removed(lane: int, ingredient: IngredientState)
signal ingredient_swallowed(lane: int, ingredient: IngredientState)
signal ingredient_burned(lane: int, ingredient: IngredientState)
## 胃裡的食材吐進了鍋子。
signal ingredient_spat(lane: int, ingredient: IngredientState)
## 喊了吸或吐，但沒有效果（噴火時是一開始就沒有可以燒的食材）。
signal suck_missed(lane: int)
signal spit_missed(lane: int)
## 胃袋內容改變，胃空時 ingredient 為 null。
signal stomach_changed(ingredient: IngredientState)
## 鍋子的數量或要求改變。
signal pot_changed(lane: int)
signal baby_left(lane: int, reason: BabyLeaveReason)
signal baby_arrived(lane: int)
signal completed_count_changed(count: int)
signal cleared_count_changed(count: int)
## 最前端食材蓄滿出手。hit 為 false 表示龍正在暈眩或無敵，這次打空。
signal ingredient_attacked(lane: int, ingredient: IngredientState, hit: bool)
## 龍被打中開始暈眩，暈眩中不能換層、吸、吐、噴火。
signal dragon_stunned
## 龍暈眩結束，接著進入無敵時間。
signal dragon_recovered
## 龍頭轉向改變（Facing.LEFT 面向食材、RIGHT 面向鍋子）。
signal facing_changed(facing: Facing)
signal game_won
signal game_lost

@export var lane_layout: LaneLayout
## 吸與吐都作用在龍目前所在的層。
@export var dragon: Dragon

@export_group("食材隊伍")
## 從出生點走到最前端的秒數，移動速度由此換算。
@export var walk_time: float = 4.0
## 隊伍有空位後，等多少秒才補一個新食材（每層各自計時）。
## 間隔 = spawn_interval_start - 完成鍋數 × spawn_interval_step，最短 spawn_interval_min。
@export var spawn_interval_start: float = 8.0
@export var spawn_interval_step: float = 1.0
@export var spawn_interval_min: float = 3.0
@export var ingredient_spacing: float = 0.6
@export var max_ingredients_per_lane: int = 6
## 開場每層已經排在最前端的食材數。
@export var opening_ingredients: int = 1
## 開啟時 spawn_x、front_x 改讀最低層房間的 QueueSpawnAnchor、QueueFrontAnchor。
@export var use_room_anchors: bool = true
## 食材出生的 x 座標（LaneLayout 的本地座標）。
@export var spawn_x: float = -13.0
## 隊伍最前端停下的 x 座標（最靠近龍）。
@export var front_x: float = -2.5

@export_group("小龍與鍋子")
@export var forbidden_min: int = 1
@export var forbidden_max: int = 3
@export var required_min: int = 2
@export var required_max: int = 5
## 舊小龍離開到新小龍到位的秒數。
@export var baby_swap_time: float = 2.0

@export_group("噴火")
## 持續噴火多少秒才會燒掉一個食材。
@export var burn_time: float = 1.0

@export_group("食材攻擊")
## 每次蓄力的秒數在這個範圍內隨機。
@export var attack_charge_min: float = 10.0
@export var attack_charge_max: float = 20.0
## 龍被打中後暈眩的秒數。
@export var stun_time: float = 1.5
## 暈眩結束後的無敵秒數，期間攻擊打空。
@export var invincible_time: float = 2.0

@export_group("勝敗")
@export var pots_to_win: int = 6
@export var clears_to_lose: int = 3

var lanes: Array[LaneState] = []
var pots: Array[PotState] = []
var stomach: IngredientState = null
var completed_count: int = 0
var cleared_count: int = 0
## WAITING：場景擺好但靜止，等待 start_game()。PLAYING：遊玩中。ENDED：已分出勝敗。
var state: GameState = GameState.WAITING
## 龍頭朝向：LEFT 面向食材（吸、噴火有效），RIGHT 面向鍋子（吐進鍋子有效）。
var facing: Facing = Facing.LEFT
## 玩家正在持續喊「吐」。
var is_spitting: bool = false
## 這次按下「吐」已經把食材吐進鍋子，放開前不會接著噴火。
var _spit_used_for_pot: bool = false
## 剩餘的暈眩秒數，大於 0 表示暈眩中。
var stun_remaining: float = 0.0
## 剩餘的無敵秒數，大於 0 表示無敵中。
var invincible_remaining: float = 0.0
## 每次重置加一，用來忽略上一局還沒觸發的換小龍計時。
var _round: int = 0


func _ready() -> void:
	if use_room_anchors:
		spawn_x = lane_layout.get_anchor_position(0, &"QueueSpawnAnchor").x
		front_x = lane_layout.get_anchor_position(0, &"QueueFrontAnchor").x
	_setup_round()


func _process(delta: float) -> void:
	if state != GameState.PLAYING:
		return
	_update_stun(delta)
	for i in lanes.size():
		_advance_queue(lanes[i], delta)
		_try_spawn(i, delta)
		_update_attack(i, delta)
	_update_burning(delta)


## 開始遊戲或重新遊玩。開場第一次呼叫時直接沿用已擺好的場景，之後每次都原地重置。
func start_game() -> void:
	if state != GameState.WAITING:
		_setup_round()
	state = GameState.PLAYING
	game_started.emit()


## 面向左邊且胃袋空著時，把所在層最前端的食材吞進胃袋。
func suck() -> void:
	if state != GameState.PLAYING or is_stunned():
		return
	var lane := dragon.current_lane
	var ingredient: IngredientState = null
	if facing == Facing.LEFT and stomach == null:
		ingredient = get_front(lane)
	if ingredient == null:
		suck_missed.emit(lane)
		return
	_take_front(lane)
	stomach = ingredient
	ingredient_swallowed.emit(lane, ingredient)
	stomach_changed.emit(stomach)


## 開始喊「吐」。面向右邊且胃袋有食材，立刻吐進所在層的鍋子；
## 面向左邊且胃袋空著，開始噴火，持續到 spit_released()。其他情況沒有效果。
func spit_pressed() -> void:
	if state != GameState.PLAYING:
		return
	is_spitting = true
	if is_stunned():
		return
	var lane := dragon.current_lane
	if facing == Facing.RIGHT:
		if stomach != null:
			_spit_used_for_pot = true
			_spit_into_pot(lane)
		else:
			spit_missed.emit(lane)
	elif stomach != null or get_front(lane) == null:
		spit_missed.emit(lane)


## 停止喊「吐」。
func spit_released() -> void:
	is_spitting = false
	_spit_used_for_pot = false


## 正在喊「吐」、面向左邊且胃袋空著（噴火中）。這次按下已經吐進鍋子時回傳 false。
func is_breathing_fire() -> bool:
	return state == GameState.PLAYING and is_spitting and not _spit_used_for_pot and stomach == null \
			and facing == Facing.LEFT and not is_stunned()


## 龍頭左右切換（玩家 B 大叫或按 L）。暈眩中不能轉頭。
func turn_head() -> void:
	if state != GameState.PLAYING or is_stunned():
		return
	_set_facing(Facing.RIGHT if facing == Facing.LEFT else Facing.LEFT)


func is_stunned() -> bool:
	return stun_remaining > 0.0


func is_invincible() -> bool:
	return invincible_remaining > 0.0


## 最前端的食材已經走到停止位置才回傳，否則回傳 null。
func get_front(lane: int) -> IngredientState:
	var queue := lanes[lane].queue
	if queue.is_empty() or queue[0].x < front_x - 0.001:
		return null
	return queue[0]


func get_pot(lane: int) -> PotState:
	return pots[lane]


## 目前的生成間隔，完成鍋數越多越短。
func get_spawn_interval() -> float:
	return maxf(spawn_interval_start - completed_count * spawn_interval_step, spawn_interval_min)


## 持續噴火時，累計所在層最前端食材的燒毀進度。
func _update_burning(delta: float) -> void:
	if not is_breathing_fire():
		return
	var lane := dragon.current_lane
	var ingredient := get_front(lane)
	if ingredient == null:
		return
	ingredient.burn_progress = minf(ingredient.burn_progress + delta / burn_time, 1.0)
	if ingredient.burn_progress >= 1.0:
		_take_front(lane)
		ingredient_burned.emit(lane, ingredient)


## 推進暈眩與無敵的倒數。
func _update_stun(delta: float) -> void:
	if is_stunned():
		stun_remaining -= delta
		if stun_remaining <= 0.0:
			stun_remaining = 0.0
			dragon.stunned = false
			invincible_remaining = invincible_time
			dragon_recovered.emit()
	elif is_invincible():
		invincible_remaining = maxf(invincible_remaining - delta, 0.0)


## 最前端的食材蓄力，蓄滿就攻擊龍並重新蓄力。龍暈眩或無敵時打空。
func _update_attack(lane: int, delta: float) -> void:
	var ingredient := get_front(lane)
	if ingredient == null:
		return
	if ingredient.attack_time <= 0.0:
		ingredient.attack_time = randf_range(attack_charge_min, attack_charge_max)
	ingredient.attack_progress = minf(ingredient.attack_progress + delta / ingredient.attack_time, 1.0)
	if ingredient.attack_progress < 1.0:
		return
	ingredient.attack_progress = 0.0
	ingredient.attack_time = 0.0
	var hit := not is_stunned() and not is_invincible()
	ingredient_attacked.emit(lane, ingredient, hit)
	if hit:
		_stun_dragon()


func _set_facing(value: Facing) -> void:
	if value == facing:
		return
	facing = value
	facing_changed.emit(facing)


func _stun_dragon() -> void:
	stun_remaining = stun_time
	dragon.stunned = true
	dragon_stunned.emit()


func _spit_into_pot(lane: int) -> void:
	var pot := pots[lane]
	if not pot.has_baby:
		spit_missed.emit(lane)
		return
	var ingredient := stomach
	stomach = null
	ingredient_spat.emit(lane, ingredient)
	stomach_changed.emit(null)

	if pot.is_forbidden(ingredient.type):
		cleared_count += 1
		cleared_count_changed.emit(cleared_count)
		_baby_leave(lane, BabyLeaveReason.KICKED)
		if cleared_count >= clears_to_lose:
			_end_game(false)
		return

	pot.count += 1
	pot_changed.emit(lane)
	if pot.count >= pot.required:
		completed_count += 1
		completed_count_changed.emit(completed_count)
		_baby_leave(lane, BabyLeaveReason.COMPLETED)
		if completed_count >= pots_to_win:
			_end_game(true)


## 小龍離開並清空鍋子，經過 baby_swap_time 後換新的小龍。
func _baby_leave(lane: int, reason: BabyLeaveReason) -> void:
	var pot := pots[lane]
	pot.has_baby = false
	pot.count = 0
	pot_changed.emit(lane)
	baby_left.emit(lane, reason)
	get_tree().create_timer(baby_swap_time).timeout.connect(_baby_arrive.bind(lane, _round))


func _baby_arrive(lane: int, round_id: int) -> void:
	if round_id != _round:
		return
	var pot := pots[lane]
	pot.randomize_request(forbidden_min, forbidden_max, required_min, required_max)
	pot.has_baby = true
	pot_changed.emit(lane)
	baby_arrived.emit(lane)


func _end_game(won: bool) -> void:
	if state == GameState.ENDED:
		return
	state = GameState.ENDED
	if won:
		game_won.emit()
	else:
		game_lost.emit()


## 清掉上一局的所有狀態，重新排好開場隊伍、換上小龍，龍回到中間層。
func _setup_round() -> void:
	_round += 1
	for i in lanes.size():
		for ingredient in lanes[i].queue:
			ingredient_removed.emit(i, ingredient)
	lanes.clear()
	pots.clear()

	if stomach != null:
		stomach = null
		stomach_changed.emit(null)
	is_spitting = false
	_spit_used_for_pot = false
	stun_remaining = 0.0
	invincible_remaining = 0.0
	dragon.stunned = false
	_set_facing(Facing.LEFT)
	completed_count = 0
	completed_count_changed.emit(completed_count)
	cleared_count = 0
	cleared_count_changed.emit(cleared_count)
	dragon.reset_position()

	for i in lane_layout.lane_count:
		lanes.append(LaneState.new())
		for k in mini(opening_ingredients, max_ingredients_per_lane):
			_spawn(i, front_x - k * ingredient_spacing)
		pots.append(PotState.new())
		_baby_arrive(i, _round)


func _take_front(lane: int) -> void:
	var ingredient: IngredientState = lanes[lane].queue.pop_front()
	ingredient_removed.emit(lane, ingredient)


## 由前往後推進，每個食材最多走到前一個食材後方一個間隔的位置。
func _advance_queue(lane: LaneState, delta: float) -> void:
	var limit := front_x
	var speed := (front_x - spawn_x) / walk_time
	for ingredient in lane.queue:
		ingredient.x = minf(ingredient.x + speed * delta, limit)
		limit = ingredient.x - ingredient_spacing


## 數量低於上限後開始計時，到生成間隔且最後一個食材已離開出生點至少一個間隔，才產生新食材。
func _try_spawn(lane: int, delta: float) -> void:
	var lane_state := lanes[lane]
	var queue := lane_state.queue
	if queue.size() >= max_ingredients_per_lane:
		lane_state.spawn_timer = 0.0
		return
	lane_state.spawn_timer += delta
	if lane_state.spawn_timer < get_spawn_interval():
		return
	if not queue.is_empty() and queue.back().x < spawn_x + ingredient_spacing:
		return
	lane_state.spawn_timer = 0.0
	_spawn(lane, spawn_x)


func _spawn(lane: int, x: float) -> void:
	var ingredient := IngredientState.new(_pick_type(lane), x)
	lanes[lane].queue.append(ingredient)
	ingredient_spawned.emit(lane, ingredient)


## 決定新食材的種類。目前所有層都平均隨機。
func _pick_type(_lane: int) -> IngredientType.Type:
	return IngredientType.Type.values().pick_random()
