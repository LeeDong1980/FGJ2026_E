class_name FacingIndicator
extends CanvasLayer
## 畫面下方正中的框框：左「◀ 食材」、右「鍋子 ▶」顯示龍頭朝向，目前朝向的那格亮起；
## 中間一格顯示目前的元素（火／冰）。轉頭動畫與冰的特效完成前用它代替。

@export var game_manager: GameManager
## 和畫面底部的距離。
@export var bottom_margin: float = 24.0

const ACTIVE_COLOR := Color(1.0, 0.8, 0.25)
const INACTIVE_COLOR := Color(0.35, 0.35, 0.4)
const FIRE_COLOR := Color(1.0, 0.45, 0.15)
const ICE_COLOR := Color(0.45, 0.8, 1.0)

var _box: HBoxContainer
var _left: PanelContainer
var _right: PanelContainer
var _element: PanelContainer


func _ready() -> void:
	_box = HBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_left = _add_slot("◀ 食材")
	_element = _add_slot("")
	_right = _add_slot("鍋子 ▶")
	game_manager.facing_changed.connect(_show.unbind(1))
	game_manager.element_changed.connect(_show.unbind(1))
	_show()


func _process(_delta: float) -> void:
	var view := _box.get_viewport_rect().size
	_box.position = Vector2((view.x - _box.size.x) / 2.0, view.y - _box.size.y - bottom_margin)


func _add_slot(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(160.0, 0.0)
	label.add_theme_font_size_override("font_size", 32)
	panel.add_child(label)
	_box.add_child(panel)
	return panel


func _show() -> void:
	_set_style(_left, ACTIVE_COLOR if game_manager.facing == GameManager.Facing.LEFT else INACTIVE_COLOR,
			game_manager.facing == GameManager.Facing.LEFT)
	_set_style(_right, ACTIVE_COLOR if game_manager.facing == GameManager.Facing.RIGHT else INACTIVE_COLOR,
			game_manager.facing == GameManager.Facing.RIGHT)
	var ice := game_manager.element == GameManager.Element.ICE
	(_element.get_child(0) as Label).text = "冰" if ice else "火"
	_set_style(_element, ICE_COLOR if ice else FIRE_COLOR, true)


func _set_style(panel: PanelContainer, border: Color, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	style.border_color = border
	style.set_border_width_all(4 if active else 2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate.a = 1.0 if active else 0.5
