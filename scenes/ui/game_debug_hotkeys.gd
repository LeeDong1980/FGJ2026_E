class_name GameDebugHotkeys
extends Node
## 真正遊戲裡的測試快捷鍵（按鍵與 ui_test.tscn 的 UITestController 相同），都要同時按住 Ctrl + Shift：
##   W 強制成功（清空次數隨機 1～2）　　L 強制失敗（完成鍋數隨機 1～3）
##   1 完成數 +1　 2 清空次數 +1（達到目標就結束）
##   4／5／6 上層／中層／下層的禁止食材隨機換成 1～3 種
##   ↑／←／↓ 龍飛到高／中／低層
##   I 吸　O 吐（按住 O 持續噴火）
##   按住 I 再按 3／4／5 上層／中層／下層的鍋子增加一個可以放的原料（走正式的吐入流程，收集滿就完成一鍋）
##
## 只在除錯版本（編輯器執行）有效，匯出的正式版本自動停用；連線局預設停用（避免兩台機器不同步），可用 allow_in_match 打開。
## 畫面下方中央會顯示目前是否開啟，停用時也會寫出原因。
## 注意：完成數、清空次數、強制勝敗與換禁止食材，遊戲機制目前沒有正式接口，這裡直接改 GameManager 的資料，
## 只能用在測試。正式接口完成後改用正式接口（見 tasks.md）。

const TOP_LANE := 2
const MIDDLE_LANE := 1
const BOTTOM_LANE := 0
const REROLL_KEYS: Dictionary = {KEY_4: TOP_LANE, KEY_5: MIDDLE_LANE, KEY_6: BOTTOM_LANE}
const HEIGHT_KEYS: Dictionary = {KEY_UP: TOP_LANE, KEY_LEFT: MIDDLE_LANE, KEY_DOWN: BOTTOM_LANE}
## 按住 suck_key 時，增加原料的按鍵 -> 層。
const ADD_INGREDIENT_KEYS: Dictionary = {KEY_3: TOP_LANE, KEY_4: MIDDLE_LANE, KEY_5: BOTTOM_LANE}

## 打開時，遊玩中可以用 Ctrl + Shift + 按鍵操作測試功能。
@export var hotkeys_enabled: bool = true
## 連線局也允許使用（只改自己這台的資料，兩台機器可能不同步，只在需要時打開）。
@export var allow_in_match: bool = false
## 畫面下方中央顯示測試快捷鍵是否開啟。
@export var show_indicator: bool = true
@export var game_manager: GameManager
@export var force_success_key: Key = KEY_W
@export var force_fail_key: Key = KEY_L
@export var add_completed_key: Key = KEY_1
@export var add_cleared_key: Key = KEY_2
@export var suck_key: Key = KEY_I
@export var spit_key: Key = KEY_O


var _indicator: Label


func _ready() -> void:
	if game_manager == null:
		# 放在 GameUI 底下時，GameUI 的父節點就是 GameManager。
		game_manager = get_parent().get_parent() as GameManager
	if show_indicator and OS.is_debug_build():
		_create_indicator()


func _process(_delta: float) -> void:
	if _indicator == null:
		return
	var reason := _inactive_reason()
	_indicator.text = "測試快捷鍵：開啟（Ctrl + Shift）" if reason.is_empty() else "測試快捷鍵：停用（%s）" % reason
	_indicator.modulate = Color(0.6, 1.0, 0.6) if reason.is_empty() else Color(1.0, 0.7, 0.6)


func _create_indicator() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_indicator = Label.new()
	_indicator.add_theme_font_size_override(&"font_size", 22)
	_indicator.add_theme_constant_override(&"outline_size", 6)
	_indicator.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicator.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_indicator.offset_left = -300.0
	_indicator.offset_right = 300.0
	_indicator.offset_top = -40.0
	_indicator.offset_bottom = -8.0
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_indicator)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active():
		return
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	# 放開 O 時停止噴火（放開的瞬間可能已經沒按住 Ctrl／Shift，所以先處理）。
	if not key.pressed and key.keycode == spit_key and game_manager.is_spitting:
		game_manager.spit_released()
		return
	if not key.pressed or not key.ctrl_pressed or not key.shift_pressed:
		return
	if _handle_hotkey(key.keycode):
		get_viewport().set_input_as_handled()


func _is_active() -> bool:
	return _inactive_reason().is_empty()


## 測試快捷鍵目前不能用的原因；可以用時回傳空字串。
func _inactive_reason() -> String:
	if not hotkeys_enabled:
		return "Inspector 已關閉"
	if not OS.is_debug_build():
		return "正式版本"
	if game_manager == null:
		return "找不到 GameManager"
	if RoomManager.phase == RoomManager.Phase.MATCH and not allow_in_match:
		return "連線局，可在 Inspector 勾選 Allow In Match"
	if game_manager.state != GameManager.GameState.PLAYING:
		return "目前不在遊玩中"
	return ""


## 有對應的測試功能就執行並回傳 true。
func _handle_hotkey(keycode: Key) -> bool:
	if Input.is_key_pressed(suck_key) and ADD_INGREDIENT_KEYS.has(keycode):
		_add_ingredient(ADD_INGREDIENT_KEYS[keycode])
	elif keycode == force_success_key:
		_set_counts(game_manager.pots_to_win, randi_range(1, 2))
		game_manager._end_game(true)
	elif keycode == force_fail_key:
		_set_counts(randi_range(1, 3), game_manager.clears_to_lose)
		game_manager._end_game(false)
	elif keycode == add_completed_key:
		_set_counts(game_manager.completed_count + 1, game_manager.cleared_count)
		if game_manager.completed_count >= game_manager.pots_to_win:
			game_manager._end_game(true)
	elif keycode == add_cleared_key:
		_set_counts(game_manager.completed_count, game_manager.cleared_count + 1)
		if game_manager.cleared_count >= game_manager.clears_to_lose:
			game_manager._end_game(false)
	elif REROLL_KEYS.has(keycode):
		_reroll_forbidden(REROLL_KEYS[keycode])
	elif HEIGHT_KEYS.has(keycode):
		game_manager.dragon.set_target_lane(HEIGHT_KEYS[keycode])
	elif keycode == suck_key:
		game_manager.suck()
	elif keycode == spit_key:
		game_manager.spit_pressed()
	else:
		return false
	return true


func _set_counts(completed: int, cleared: int) -> void:
	game_manager.completed_count = completed
	game_manager.completed_count_changed.emit(completed)
	game_manager.cleared_count = cleared
	game_manager.cleared_count_changed.emit(cleared)


## 換成和原本不同的禁止清單，數量與需求不變。
func _reroll_forbidden(lane: int) -> void:
	var pot := game_manager.get_pot(lane)
	var old: Array = Array(pot.forbidden).duplicate()
	old.sort()
	var forbidden: Array = old
	while forbidden == old:
		var types: Array = IngredientType.Type.values()
		types.shuffle()
		forbidden = types.slice(0, randi_range(game_manager.forbidden_min, game_manager.forbidden_max))
		forbidden.sort()
	pot.forbidden.assign(forbidden)
	game_manager.pot_changed.emit(lane)


## 把一個可以放的原料吐進指定層的鍋子：沿用遊戲正式的吐入流程（完成、換小龍、勝利判定都照常）。
## 胃袋原本的食材會保留。
func _add_ingredient(lane: int) -> void:
	var pot := game_manager.get_pot(lane)
	if not pot.has_baby:
		return
	var allowed: Array = IngredientType.Type.values().filter(func(type: int) -> bool: return not pot.is_forbidden(type))
	var kept := game_manager.stomach
	game_manager.stomach = IngredientState.new(allowed.pick_random(), 0.0)
	game_manager._spit_into_pot(lane)
	if kept != null and game_manager.state == GameManager.GameState.PLAYING:
		game_manager.stomach = kept
		game_manager.stomach_changed.emit(kept)
