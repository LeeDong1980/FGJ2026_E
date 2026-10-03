class_name ForbiddenIcon
extends Control
## 禁止食材圖示：食材顏色的圓形、名稱第一個字，再蓋上紅色禁止圈與斜線。
## 正式的食材圖示做好之前，先用程式畫。

const RING_COLOR := Color("e5484d")
const OUTLINE_COLOR := Color("2a2235")

var type: IngredientType.Type = IngredientType.Type.HUMAN:
	set(value):
		type = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 4.0
	var line_width := maxf(3.0, radius * 0.14)
	draw_circle(center, radius, IngredientType.COLORS[type], true, -1.0, true)

	var slash := Vector2(radius, radius) * 0.7
	draw_line(center - slash, center + slash, Color(RING_COLOR, 0.85), line_width, true)

	var font := get_theme_default_font()
	var font_size := int(radius * 1.05)
	var label: String = IngredientType.NAMES[type].left(1)
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := center + Vector2(-text_width / 2.0, (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, int(radius * 0.25), OUTLINE_COLOR)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	draw_arc(center, radius + 1.0, 0.0, TAU, 48, RING_COLOR, line_width, true)
