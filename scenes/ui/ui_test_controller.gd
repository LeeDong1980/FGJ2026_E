class_name UITestController
extends Node
## 測試介面用的控制中心：不接遊戲機制，只用假資料依遊戲階段切換介面。
## 執行後直接顯示遊玩狀態介面並開始倒數（主選單已拆成獨立場景 main_menu.tscn），
## 時間到就算失敗。完成數達到 target_pots 算成功，清空次數達到 clear_limit 算失敗。
## 按下「重新遊玩」「下一關」或「回主選單」都會重新開始一局（測試場景沒有主選單）。
##
## 測試快捷鍵（遊玩中有效，可在 Inspector 用 hotkeys_enabled 開關），都要同時按住 Ctrl + Shift：
##   W 強制成功　　L 強制失敗
##   1 完成數 +1　 2 清空次數 +1
##   4／5／6 上層／中層／下層的禁止食材隨機換成 1～3 種
##   ↑／←／↓ 龍的高度顯示為高／中／低
##   I 顯示「吸」　O 顯示「吐」
##   按住 I 再按 3／4／5 上層／中層／下層的鍋子增加一個原料，收集滿就算完成一鍋並換新鍋子

## 遊玩狀態介面要顯示幾層鍋子。第 0 層是最低層。
const LANE_COUNT := 3
const TOP_LANE := LANE_COUNT - 1
const MIDDLE_LANE := 1
const BOTTOM_LANE := 0
## 換禁止食材的按鍵 -> 層。
const REROLL_KEYS: Dictionary = {KEY_4: TOP_LANE, KEY_5: MIDDLE_LANE, KEY_6: BOTTOM_LANE}
## 改龍高度的按鍵 -> 層。
const HEIGHT_KEYS: Dictionary = {KEY_UP: TOP_LANE, KEY_LEFT: MIDDLE_LANE, KEY_DOWN: BOTTOM_LANE}
## 按住 show_suck_key 時，增加原料的按鍵 -> 層。
const ADD_INGREDIENT_KEYS: Dictionary = {KEY_3: TOP_LANE, KEY_4: MIDDLE_LANE, KEY_5: BOTTOM_LANE}

@export var ui_root: UIRoot
## 每一局的倒數秒數。
@export var play_time: float = 60.0
@export var target_pots: int = 6
@export var clear_limit: int = 3
## 成功時是否還有下一關。勾選時成功畫面顯示「下一關」，不勾選時顯示「回主選單」。
@export var has_next_level: bool = true

@export_group("測試快捷鍵")
## 打開時，遊玩中可以用 Ctrl + Shift + 按鍵操作測試功能。
@export var hotkeys_enabled: bool = true
@export var force_success_key: Key = KEY_W
@export var force_fail_key: Key = KEY_L
@export var add_completed_key: Key = KEY_1
@export var add_cleared_key: Key = KEY_2
@export var show_suck_key: Key = KEY_I
@export var show_burn_key: Key = KEY_O

var _time_left := 0.0
var _playing := false
var _completed := 0
var _cleared := 0
## 各層鍋子的假資料：{"forbidden": Array, "have": int, "need": int}
var _pots: Array[Dictionary] = []


func _ready() -> void:
	ui_root.retry_requested.connect(_start_round)
	ui_root.next_level_requested.connect(_start_round)
	ui_root.back_requested.connect(_start_round)
	_start_round.call_deferred()


func _process(delta: float) -> void:
	if not _playing:
		return
	_time_left -= delta
	ui_root.play_hud.show_time_left(_time_left)
	if _time_left <= 0.0:
		_end(false, _completed, _cleared)


func _unhandled_input(event: InputEvent) -> void:
	if not hotkeys_enabled or not _playing:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not key.ctrl_pressed or not key.shift_pressed:
		return
	if _handle_hotkey(key.keycode):
		get_viewport().set_input_as_handled()


## 有對應的測試功能就執行並回傳 true。
func _handle_hotkey(keycode: Key) -> bool:
	var hud := ui_root.play_hud
	if Input.is_key_pressed(show_suck_key) and ADD_INGREDIENT_KEYS.has(keycode):
		_add_ingredient(ADD_INGREDIENT_KEYS[keycode])
	elif keycode == force_success_key:
		# 強制成功：清空次數隨機顯示 1～2。
		_end(true, target_pots, randi_range(1, 2))
	elif keycode == force_fail_key:
		# 強制失敗：完成鍋數隨機顯示 1～3。
		_end(false, randi_range(1, 3), clear_limit)
	elif keycode == add_completed_key:
		_add_completed()
	elif keycode == add_cleared_key:
		_add_cleared()
	elif REROLL_KEYS.has(keycode):
		_reroll_forbidden(REROLL_KEYS[keycode])
	elif HEIGHT_KEYS.has(keycode):
		_set_dragon_lane(HEIGHT_KEYS[keycode])
	elif keycode == show_suck_key:
		hud.show_word("吸")
	elif keycode == show_burn_key:
		hud.show_word("吐")
	else:
		return false
	return true


func _start_round() -> void:
	_time_left = play_time
	_playing = true
	_completed = 0
	_cleared = 0
	var hud := ui_root.play_hud
	hud.setup_lanes(LANE_COUNT)
	_pots.clear()
	for i in LANE_COUNT:
		_pots.append(_new_pot())
		hud.set_pot(i, _pots[i].forbidden, _pots[i].have, _pots[i].need)
	_set_dragon_lane(MIDDLE_LANE)
	hud.set_completed(_completed, target_pots)
	hud.set_cleared(_cleared, clear_limit)
	hud.show_time_left(_time_left)
	ui_root.show_playing()


func _add_completed() -> void:
	_completed += 1
	ui_root.play_hud.set_completed(_completed, target_pots)
	if _completed >= target_pots:
		_end(true, _completed, _cleared)


func _add_cleared() -> void:
	_cleared += 1
	ui_root.play_hud.set_cleared(_cleared, clear_limit)
	if _cleared >= clear_limit:
		_end(false, _completed, _cleared)


## 鍋子增加一個原料。收集滿就算完成一鍋：鍋子閃綠色、換成新鍋子，完成數 +1。
func _add_ingredient(lane: int) -> void:
	var hud := ui_root.play_hud
	var pot := _pots[lane]
	pot.have += 1
	if pot.have < pot.need:
		hud.set_pot_progress(lane, pot.have, pot.need)
		return
	_pots[lane] = _new_pot()
	hud.set_pot(lane, _pots[lane].forbidden, _pots[lane].have, _pots[lane].need)
	hud.flash_pot_completed(lane)
	_add_completed()


func _reroll_forbidden(lane: int) -> void:
	var pot := _pots[lane]
	# 一定換成和原本不同的組合，測試時才看得出有換。
	var old: Array = pot.forbidden.duplicate()
	old.sort()
	var forbidden := _random_forbidden()
	forbidden.sort()
	while forbidden == old:
		forbidden = _random_forbidden()
		forbidden.sort()
	pot.forbidden = forbidden
	ui_root.play_hud.set_pot(lane, pot.forbidden, pot.have, pot.need)


## 龍所在層亮起，音量條也移到那一層的中間。
func _set_dragon_lane(lane: int) -> void:
	var hud := ui_root.play_hud
	hud.set_current_lane(lane)
	hud.set_volume((lane + 0.5) / LANE_COUNT)


func _new_pot() -> Dictionary:
	return {"forbidden": _random_forbidden(), "have": 0, "need": randi_range(2, 5)}


func _random_forbidden() -> Array:
	var types := IngredientType.Type.values()
	types.shuffle()
	return types.slice(0, randi_range(1, 3))


func _end(success: bool, completed: int, cleared: int) -> void:
	_playing = false
	ui_root.show_result(success, has_next_level, completed, target_pots, cleared, clear_limit)
