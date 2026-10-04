class_name ResultScreen
extends Control
## 遊戲結束介面。成功和失敗共用，依結果切換上方橫幅、標題顏色、面板色調與按鍵。
## 美術用 UI 素材包：成功是 VICTORY 字樣配月桂葉，失敗是 DEFEAT 字樣配骷髏；按鍵成功用金色、失敗用紅色。

signal action_pressed(action: Action)

enum Action { NEXT_LEVEL, MAIN_MENU, RETRY }

const ACTION_TEXTS: Dictionary = {
	Action.NEXT_LEVEL: "下一關",
	Action.MAIN_MENU: "回主選單",
	Action.RETRY: "重新遊玩",
}
const SUCCESS_TITLE_COLOR := Color("ffd34d")
const FAIL_TITLE_COLOR := Color("ff6b6e")
const FAIL_PANEL_TINT := Color(1.0, 0.8, 0.78)
const FAIL_BUTTON_TEXT_COLOR := Color.WHITE
const FAIL_BUTTON_OUTLINE_COLOR := Color(0.35, 0.03, 0.02, 1)

const VICTORY_TEXT := preload("res://scenes/ui/UI/Sprites/Components/ActionText/ActionText_Victory.png")
const DEFEAT_TEXT := preload("res://scenes/ui/UI/Sprites/Components/ActionText/ActionText_Defeat.png")
const LAUREL_LEFT := preload("res://scenes/ui/UI/Sprites/Demo/Demo_Image/Image_Deco_Laurel_L.Png")
const LAUREL_RIGHT := preload("res://scenes/ui/UI/Sprites/Demo/Demo_Image/Image_Deco_Laurel_R.Png")
const SKULL_LEFT := preload("res://scenes/ui/UI/Sprites/Demo/Demo_Image/Image_DefeatScene_Skull2.Png")
const SKULL_RIGHT := preload("res://scenes/ui/UI/Sprites/Demo/Demo_Image/Image_DefeatScene_Skull3.Png")
const RED_BUTTON := preload("res://scenes/ui/UI/Sprites/Components/Button/Button01_Red.png")

var _action: Action = Action.RETRY
var _banner_tween: Tween

@onready var _banner: Control = %Banner
@onready var _banner_text: TextureRect = %BannerText
@onready var _deco_left: TextureRect = %DecoLeft
@onready var _deco_right: TextureRect = %DecoRight
@onready var _result_panel: PanelContainer = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _completed_stat: Label = %CompletedStat
@onready var _cleared_stat: Label = %ClearedStat
@onready var _action_button: Button = %ActionButton


func _ready() -> void:
	_action_button.pressed.connect(func() -> void: action_pressed.emit(_action))
	visibility_changed.connect(_on_visibility_changed)


func show_result(success: bool, has_next_level: bool, completed: int, target: int, cleared: int, limit: int) -> void:
	if success:
		_action = Action.NEXT_LEVEL if has_next_level else Action.MAIN_MENU
	else:
		_action = Action.RETRY
	_banner_text.texture = VICTORY_TEXT if success else DEFEAT_TEXT
	_deco_left.texture = LAUREL_LEFT if success else SKULL_LEFT
	_deco_right.texture = LAUREL_RIGHT if success else SKULL_RIGHT
	_result_label.text = "料理成功！" if success else "料理失敗…"
	_result_label.add_theme_color_override(&"font_color", SUCCESS_TITLE_COLOR if success else FAIL_TITLE_COLOR)
	_completed_stat.text = "完成鍋數 %d / %d" % [completed, target]
	_cleared_stat.text = "清空次數 %d / %d" % [cleared, limit]
	_action_button.text = ACTION_TEXTS[_action]

	# 面板是圖片（九宮格）：成功維持原色，失敗偏紅。
	var panel_style := _result_panel.get_theme_stylebox(&"panel").duplicate() as StyleBoxTexture
	panel_style.modulate_color = Color.WHITE if success else FAIL_PANEL_TINT
	_result_panel.add_theme_stylebox_override(&"panel", panel_style)
	_set_button_style(success)


## 成功用主題的金色按鍵；失敗換成紅色按鍵與白字。
func _set_button_style(success: bool) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		_action_button.remove_theme_stylebox_override(state)
	for font_state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_outline_color"]:
		_action_button.remove_theme_color_override(font_state)
	_action_button.remove_theme_constant_override(&"outline_size")
	if success:
		return
	var tints: Dictionary = {&"normal": Color.WHITE, &"hover": Color(1.15, 1.1, 1.1), &"pressed": Color(0.85, 0.8, 0.8)}
	for state: StringName in tints:
		var style := StyleBoxTexture.new()
		style.texture = RED_BUTTON
		style.texture_margin_left = 28.0
		style.texture_margin_right = 28.0
		style.texture_margin_top = 22.0
		style.texture_margin_bottom = 28.0
		style.content_margin_left = 60.0
		style.content_margin_right = 60.0
		style.content_margin_top = 12.0
		style.content_margin_bottom = 20.0
		style.modulate_color = tints[state]
		_action_button.add_theme_stylebox_override(state, style)
	for font_state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		_action_button.add_theme_color_override(font_state, FAIL_BUTTON_TEXT_COLOR)
	_action_button.add_theme_color_override(&"font_outline_color", FAIL_BUTTON_OUTLINE_COLOR)
	_action_button.add_theme_constant_override(&"outline_size", 8)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		return
	_action_button.grab_focus.call_deferred()
	# 橫幅彈出。
	_banner.pivot_offset = _banner.size / 2.0
	if _banner_tween:
		_banner_tween.kill()
	_banner.scale = Vector2.ONE * 0.6
	_banner.modulate.a = 0.0
	_banner_tween = create_tween().set_parallel()
	_banner_tween.tween_property(_banner, ^"scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner, ^"modulate:a", 1.0, 0.25)
