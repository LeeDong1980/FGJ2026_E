class_name RangeMeter
extends Control
## 觀察兼設定用的橫條：顯示即時值（白線），並可拖曳下限／上限把手調整區間。
## 軸在 [min_axis, max_axis]；low 以下、low~high、high 以上三段各自上色。
## two_handles 關閉時只有 low 一個把手（用來設定單一閥值），low 以上都視為 high 段的顏色。

signal range_changed(low: float, high: float)

@export var min_axis: float = 0.0
@export var max_axis: float = 100.0
@export var two_handles: bool = true
@export var low: float = 25.0:
	set(value):
		low = value
		queue_redraw()
@export var high: float = 75.0:
	set(value):
		high = value
		queue_redraw()
@export var low_color: Color = Color(0.25, 0.25, 0.28)
@export var mid_color: Color = Color(0.3, 0.6, 0.35)
@export var high_color: Color = Color(0.25, 0.25, 0.28)
## 把手數值的顯示方式，預設顯示整數；軸不是線性單位（例如對數）時由外部指定
var label_formatter: Callable = func(value: float) -> String: return "%.0f" % value

## 即時值；live_active 為 false 時白線變暗
var live_value: float = 0.0:
	set(value):
		live_value = value
		queue_redraw()
var live_active: bool = false:
	set(value):
		live_active = value
		queue_redraw()

const BAR_HEIGHT := 20.0
const HANDLE_GRAB_RADIUS := 14.0

var _dragging: int = -1  # -1 沒有、0 low、1 high


func _init() -> void:
	custom_minimum_size = Vector2(0, 44)
	mouse_default_cursor_shape = Control.CURSOR_HSIZE


func _draw() -> void:
	var width: float = size.x
	var low_x: float = _value_to_x(low)
	var high_x: float = _value_to_x(high) if two_handles else low_x

	draw_rect(Rect2(0, 0, low_x, BAR_HEIGHT), low_color)
	if two_handles:
		draw_rect(Rect2(low_x, 0, high_x - low_x, BAR_HEIGHT), mid_color)
		draw_rect(Rect2(high_x, 0, width - high_x, BAR_HEIGHT), high_color)
	else:
		draw_rect(Rect2(low_x, 0, width - low_x, BAR_HEIGHT), high_color)

	var live_x: float = _value_to_x(live_value)
	var live_color := Color.WHITE if live_active else Color(1, 1, 1, 0.3)
	draw_line(Vector2(live_x, 0), Vector2(live_x, BAR_HEIGHT), live_color, 3.0)

	_draw_handle(low_x, low)
	if two_handles:
		_draw_handle(high_x, high)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = _pick_handle(event.position.x)
			if _dragging != -1:
				_drag_to(event.position.x)
		else:
			_dragging = -1
	elif event is InputEventMouseMotion and _dragging != -1:
		_drag_to(event.position.x)


func _draw_handle(x: float, value: float) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	draw_rect(Rect2(x - 3, 0, 6, BAR_HEIGHT + 4), Color(1, 0.95, 0.5))
	var text: String = label_formatter.call(value)
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_x: float = clampf(x - text_width * 0.5, 0.0, size.x - text_width)
	draw_string(font, Vector2(text_x, BAR_HEIGHT + 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


func _pick_handle(x: float) -> int:
	var low_distance: float = absf(x - _value_to_x(low))
	var high_distance: float = absf(x - _value_to_x(high)) if two_handles else INF
	if minf(low_distance, high_distance) > HANDLE_GRAB_RADIUS:
		return -1
	return 0 if low_distance <= high_distance else 1


func _drag_to(x: float) -> void:
	var value: float = _x_to_value(x)
	if _dragging == 0:
		low = minf(value, high) if two_handles else value
	else:
		high = maxf(value, low)
	range_changed.emit(low, high)


func _value_to_x(value: float) -> float:
	return clampf(inverse_lerp(min_axis, max_axis, value), 0.0, 1.0) * size.x


func _x_to_value(x: float) -> float:
	return lerpf(min_axis, max_axis, clampf(x / maxf(size.x, 1.0), 0.0, 1.0))
