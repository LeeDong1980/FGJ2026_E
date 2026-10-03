class_name GameManager
extends Node3D
## 保存並推進遊戲狀態：各層的食材隊伍、鍋子與小龍、龍的胃袋、勝敗。畫面只讀這裡的資料。
## 對外接口的說明見 docs/api.md。

enum BabyLeaveReason { COMPLETED, KICKED }

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
signal game_won
signal game_lost

@export var lane_layout: LaneLayout
## 吸與吐都作用在龍目前所在的層。
@export var dragon: Dragon

@export_group("食材隊伍")
@export var ingredient_speed: float = 2.0
@export var ingredient_spacing: float = 0.6
@export var max_ingredients_per_lane: int = 5
## 食材出生的 x 座標（畫面左側外面）。
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

@export_group("勝敗")
@export var pots_to_win: int = 6
@export var clears_to_lose: int = 3

var lanes: Array[LaneState] = []
var pots: Array[PotState] = []
var stomach: IngredientState = null
var completed_count: int = 0
var cleared_count: int = 0
var is_game_over: bool = false
## 玩家正在持續喊「吐」。
var is_spitting: bool = false
## 這次按下「吐」已經把食材吐進鍋子，放開前不會接著噴火。
var _spit_used_for_pot: bool = false


func _ready() -> void:
	for i in lane_layout.lane_count:
		lanes.append(LaneState.new())
		for k in max_ingredients_per_lane:
			_spawn(i, front_x - k * ingredient_spacing)
		pots.append(PotState.new())
		_baby_arrive(i)


func _process(delta: float) -> void:
	for i in lanes.size():
		_advance_queue(lanes[i], delta)
		_try_spawn(i)
	_update_burning(delta)


## 胃袋空著時，把所在層最前端的食材吞進胃袋。
func suck() -> void:
	if is_game_over:
		return
	var lane := dragon.current_lane
	var ingredient: IngredientState = get_front(lane) if stomach == null else null
	if ingredient == null:
		suck_missed.emit(lane)
		return
	_take_front(lane)
	stomach = ingredient
	ingredient_swallowed.emit(lane, ingredient)
	stomach_changed.emit(stomach)


## 開始喊「吐」。胃袋有食材就立刻吐進所在層的鍋子；胃袋空著就開始噴火，持續到 spit_released()。
func spit_pressed() -> void:
	if is_game_over:
		return
	is_spitting = true
	var lane := dragon.current_lane
	if stomach != null:
		_spit_used_for_pot = true
		_spit_into_pot(lane)
	elif get_front(lane) == null:
		spit_missed.emit(lane)


## 停止喊「吐」。
func spit_released() -> void:
	is_spitting = false
	_spit_used_for_pot = false


## 最前端的食材已經走到停止位置才回傳，否則回傳 null。
func get_front(lane: int) -> IngredientState:
	var queue := lanes[lane].queue
	if queue.is_empty() or queue[0].x < front_x - 0.001:
		return null
	return queue[0]


func get_pot(lane: int) -> PotState:
	return pots[lane]


## 持續噴火時，累計所在層最前端食材的燒毀進度。
func _update_burning(delta: float) -> void:
	if not is_spitting or _spit_used_for_pot or stomach != null or is_game_over:
		return
	var lane := dragon.current_lane
	var ingredient := get_front(lane)
	if ingredient == null:
		return
	ingredient.burn_progress = minf(ingredient.burn_progress + delta / burn_time, 1.0)
	if ingredient.burn_progress >= 1.0:
		_take_front(lane)
		ingredient_burned.emit(lane, ingredient)


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
	get_tree().create_timer(baby_swap_time).timeout.connect(_baby_arrive.bind(lane))


func _baby_arrive(lane: int) -> void:
	var pot := pots[lane]
	pot.randomize_request(forbidden_min, forbidden_max, required_min, required_max)
	pot.has_baby = true
	pot_changed.emit(lane)
	baby_arrived.emit(lane)


func _end_game(won: bool) -> void:
	if is_game_over:
		return
	is_game_over = true
	if won:
		game_won.emit()
	else:
		game_lost.emit()


func _take_front(lane: int) -> void:
	var ingredient: IngredientState = lanes[lane].queue.pop_front()
	ingredient_removed.emit(lane, ingredient)


## 由前往後推進，每個食材最多走到前一個食材後方一個間隔的位置。
func _advance_queue(lane: LaneState, delta: float) -> void:
	var limit := front_x
	for ingredient in lane.queue:
		ingredient.x = minf(ingredient.x + ingredient_speed * delta, limit)
		limit = ingredient.x - ingredient_spacing


## 數量低於上限，且最後一個食材已離開出生點至少一個間隔，才產生新食材。
func _try_spawn(lane: int) -> void:
	var queue := lanes[lane].queue
	if queue.size() >= max_ingredients_per_lane:
		return
	if not queue.is_empty() and queue.back().x < spawn_x + ingredient_spacing:
		return
	_spawn(lane, spawn_x)


func _spawn(lane: int, x: float) -> void:
	var ingredient := IngredientState.new(_pick_type(lane), x)
	lanes[lane].queue.append(ingredient)
	ingredient_spawned.emit(lane, ingredient)


## 決定新食材的種類。目前所有層都平均隨機。
func _pick_type(_lane: int) -> IngredientType.Type:
	return IngredientType.Type.values().pick_random()
