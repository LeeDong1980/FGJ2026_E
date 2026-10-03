extends Node
## UI 預覽：把 UI 疊在遊戲場景上，用暫時的鍋子規則與假音量測試介面。
## 鍋子、勝敗判定與麥克風完成後，改由正式的系統呼叫 UIRoot 與 PlayHud，這個場景只留作測試。
## 操作：Enter 開始，1／2／3 換層，J 吸，K 吐。

const TARGET_POTS := 6
const CLEAR_LIMIT := 3
const LEVEL_COUNT := 2

var _pots: Array[Dictionary] = []
var _completed := 0
var _cleared := 0
var _level := 0
var _playing := false
var _volume := 0.0

@onready var _game: GameManager = $Game
@onready var _dragon: Dragon = $Game/Dragon
@onready var _camera: Camera3D = $Game/Camera3D
@onready var _ui: UIRoot = $UIRoot


func _ready() -> void:
	_ui.start_requested.connect(start_level)
	_ui.next_level_requested.connect(func() -> void:
		_level += 1
		start_level())
	_ui.retry_requested.connect(start_level)
	_game.ingredient_sucked.connect(_on_ingredient_sucked)
	_game.ingredient_burned.connect(func(_lane: int, _ingredient: IngredientState) -> void: _ui.play_hud.show_word("吐"))
	_game.suck_missed.connect(func(_lane: int) -> void: _ui.play_hud.show_word("吸"))
	_game.burn_missed.connect(func(_lane: int) -> void: _ui.play_hud.show_word("吐"))
	_dragon.current_lane_changed.connect(_ui.play_hud.set_current_lane)


func _process(delta: float) -> void:
	if not _playing:
		return
	# 假音量：往龍目標層那一段的中間靠近，再加一點抖動。
	var lane_count := _game.lane_layout.lane_count
	var target := (_dragon.target_lane + 0.5) / lane_count
	_volume = lerpf(_volume, target, 1.0 - exp(-8.0 * delta))
	_ui.play_hud.set_volume(_volume + randf_range(-0.03, 0.03))


func start_level() -> void:
	_completed = 0
	_cleared = 0
	_playing = true
	var hud := _ui.play_hud
	var layout := _game.lane_layout
	hud.setup_lanes(layout.lane_count)
	var anchors: Array[Vector3] = []
	for i in layout.lane_count:
		anchors.append(layout.to_global(Vector3(layout.platform_offset_x, layout.get_lane_position(i) + 0.6, 0.0)))
	hud.set_pot_anchors(_camera, anchors)
	_pots.clear()
	for i in layout.lane_count:
		_pots.append(_new_pot())
		hud.set_pot(i, _pots[i].forbidden, _pots[i].have, _pots[i].need)
	hud.set_completed(_completed, TARGET_POTS)
	hud.set_cleared(_cleared, CLEAR_LIMIT)
	hud.set_current_lane(_dragon.current_lane)
	_ui.show_playing()


func _on_ingredient_sucked(lane: int, ingredient: IngredientState) -> void:
	_ui.play_hud.show_word("吸")
	if not _playing:
		return
	var hud := _ui.play_hud
	var pot := _pots[lane]
	if ingredient.type in pot.forbidden:
		pot.have = 0
		_cleared += 1
		hud.flash_pot_cleared(lane)
		hud.set_cleared(_cleared, CLEAR_LIMIT)
	else:
		pot.have += 1
		if pot.have >= pot.need:
			_completed += 1
			_pots[lane] = _new_pot()
			hud.flash_pot_completed(lane)
			hud.set_completed(_completed, TARGET_POTS)
	hud.set_pot(lane, _pots[lane].forbidden, _pots[lane].have, _pots[lane].need)
	if _completed >= TARGET_POTS:
		_end(true)
	elif _cleared >= CLEAR_LIMIT:
		_end(false)


func _end(success: bool) -> void:
	_playing = false
	_ui.show_result(success, _level < LEVEL_COUNT - 1, _completed, TARGET_POTS, _cleared, CLEAR_LIMIT)


func _new_pot() -> Dictionary:
	var types := IngredientType.Type.values()
	types.shuffle()
	return {"forbidden": types.slice(0, randi_range(1, 3)), "have": 0, "need": randi_range(2, 5)}
