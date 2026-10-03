class_name GameManager
extends Node3D
## 保存並推進遊戲狀態：各層的食材隊伍、吸與吐。畫面只讀這裡的資料。

signal ingredient_spawned(lane: int, ingredient: IngredientState)
signal ingredient_removed(lane: int, ingredient: IngredientState)
signal ingredient_sucked(lane: int, ingredient: IngredientState)
signal ingredient_burned(lane: int, ingredient: IngredientState)
## 喊了吸或吐，但最前端沒有已經到位的食材。
signal suck_missed(lane: int)
signal burn_missed(lane: int)

@export var lane_layout: LaneLayout
@export var ingredient_speed: float = 2.0
@export var ingredient_spacing: float = 0.6
@export var max_ingredients_per_lane: int = 5
## 食材出生的 x 座標（畫面左側外面）。
@export var spawn_x: float = -13.0
## 隊伍最前端停下的 x 座標（最靠近龍）。
@export var front_x: float = -2.5

var lanes: Array[LaneState] = []


func _ready() -> void:
	for i in lane_layout.lane_count:
		var lane := LaneState.new()
		lanes.append(lane)
		for k in max_ingredients_per_lane:
			_spawn(i, front_x - k * ingredient_spacing)


func _process(delta: float) -> void:
	for i in lanes.size():
		_advance_queue(lanes[i], delta)
		_try_spawn(i)


func suck(lane: int) -> void:
	var ingredient := _take_front(lane)
	if ingredient == null:
		suck_missed.emit(lane)
		return
	ingredient_sucked.emit(lane, ingredient)


func burn(lane: int) -> void:
	var ingredient := _take_front(lane)
	if ingredient == null:
		burn_missed.emit(lane)
		return
	ingredient_burned.emit(lane, ingredient)


## 最前端的食材已經走到停止位置才回傳，否則回傳 null。
func get_front(lane: int) -> IngredientState:
	var queue := lanes[lane].queue
	if queue.is_empty() or queue[0].x < front_x - 0.001:
		return null
	return queue[0]


func _take_front(lane: int) -> IngredientState:
	var ingredient := get_front(lane)
	if ingredient != null:
		lanes[lane].queue.pop_front()
		ingredient_removed.emit(lane, ingredient)
	return ingredient


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
