class_name ForbiddenIcon
extends Control
## 禁止食材圖示：食材顏色的圓形與名稱第一個字，再蓋上 UI 素材包的禁止符號（圓圈加斜線，染成紅色）。
## 正式的食材圖示做好之前，食材本身先用程式畫。

const BLOCK_TEXTURE := preload("res://scenes/ui/UI/Sprites/Components/Icon_PictoIcons/PictoIcon_128/Icon_PictoIcon_Block.Png")
const BLOCK_COLOR := Color(0.93, 0.22, 0.2, 0.92)
const OUTLINE_COLOR := Color("2a2235")

var type: IngredientType.Type = IngredientType.Type.HUMAN:
	set(value):
		type = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(58, 58)
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 5.0
	draw_circle(center, radius, IngredientType.COLORS[type], true, -1.0, true)
	draw_circle(center, radius, OUTLINE_COLOR, false, 2.0, true)

	var font := get_theme_default_font()
	var font_size := int(radius * 1.05)
	var label: String = IngredientType.NAMES[type].left(1)
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := center + Vector2(-text_width / 2.0, (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, int(radius * 0.3), OUTLINE_COLOR)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	var block_size := Vector2.ONE * (radius + 5.0) * 2.0
	draw_texture_rect(BLOCK_TEXTURE, Rect2(center - block_size / 2.0, block_size), false, BLOCK_COLOR)
