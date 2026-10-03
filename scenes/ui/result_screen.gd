class_name ResultScreen
extends Control
## 遊戲結束介面。成功和失敗共用，依結果顯示不同的標題、顏色與按鍵。

signal action_pressed(action: Action)

enum Action { NEXT_LEVEL, QUIT, RETRY }

const ACTION_TEXTS: Dictionary = {
	Action.NEXT_LEVEL: "下一關",
	Action.QUIT: "關閉遊戲",
	Action.RETRY: "重新遊玩",
}
const SUCCESS_TITLE_COLOR := Color("ffd34d")
const FAIL_TITLE_COLOR := Color("ff6b6e")
const SUCCESS_BUTTON_COLOR := Color("f0a830")
const FAIL_BUTTON_COLOR := Color("e5484d")
const SUCCESS_BUTTON_TEXT_COLOR := Color("2a1a05")
const FAIL_BUTTON_TEXT_COLOR := Color.WHITE
const FAIL_PANEL_TINT := Color(1.0, 0.72, 0.72)

var _action: Action = Action.RETRY

@onready var _result_panel: PanelContainer = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _action_button: Button = %ActionButton


func _ready() -> void:
	_action_button.pressed.connect(func() -> void: action_pressed.emit(_action))
	visibility_changed.connect(_on_visibility_changed)


func show_result(success: bool, has_next_level: bool, completed: int, target: int, cleared: int, limit: int) -> void:
	if success:
		_action = Action.NEXT_LEVEL if has_next_level else Action.QUIT
	else:
		_action = Action.RETRY
	var title_color := SUCCESS_TITLE_COLOR if success else FAIL_TITLE_COLOR
	_result_label.text = "料理成功！" if success else "料理失敗…"
	_result_label.add_theme_color_override(&"font_color", title_color)
	_stats_label.text = "完成鍋數 %d / %d\n清空次數 %d / %d" % [completed, target, cleared, limit]
	_action_button.text = ACTION_TEXTS[_action]

	# 面板是圖片（九宮格）：成功維持原色，失敗偏紅。
	var panel_style := _result_panel.get_theme_stylebox(&"panel").duplicate() as StyleBoxTexture
	panel_style.modulate_color = Color.WHITE if success else FAIL_PANEL_TINT
	_result_panel.add_theme_stylebox_override(&"panel", panel_style)
	_set_button_colors(SUCCESS_BUTTON_COLOR if success else FAIL_BUTTON_COLOR,
			SUCCESS_BUTTON_TEXT_COLOR if success else FAIL_BUTTON_TEXT_COLOR)


func _set_button_colors(color: Color, text_color: Color) -> void:
	var states: Dictionary = {&"normal": color, &"hover": color.lightened(0.15), &"pressed": color.darkened(0.15)}
	for state: StringName in states:
		var style := _action_button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.bg_color = states[state]
		_action_button.add_theme_stylebox_override(state, style)
	for font_state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		_action_button.add_theme_color_override(font_state, text_color)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_action_button.grab_focus.call_deferred()
