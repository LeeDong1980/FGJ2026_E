class_name PotInfo
extends PanelContainer
## 單一層鍋子的資訊：禁止食材與收集進度。
## 龍所在的層外框亮起，其他層變暗；完成時閃綠色，被清空時閃紅色並晃動。

const NORMAL_BORDER := Color(1, 1, 1, 0.2)
const ACTIVE_BORDER := Color("ffd34d")
const COMPLETED_COLOR := Color("46c46b")
const CLEARED_COLOR := Color("e5484d")
const INACTIVE_ALPHA := 0.6
const FLASH_TIME := 0.8

var _style: StyleBoxFlat
var _base_bg: Color
var _active := false
var _flash_tween: Tween
var _shake_tween: Tween

@onready var _icons: HBoxContainer = %ForbiddenIcons
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _progress_label: Label = %ProgressLabel


func _ready() -> void:
	# 每個鍋子各自一份 StyleBox，才能分別改外框顏色。
	_style = get_theme_stylebox(&"panel").duplicate()
	add_theme_stylebox_override(&"panel", _style)
	_base_bg = _style.bg_color
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	set_active(false)


func set_forbidden(types: Array) -> void:
	for child in _icons.get_children():
		child.queue_free()
	for type: IngredientType.Type in types:
		var icon := ForbiddenIcon.new()
		icon.type = type
		_icons.add_child(icon)


func set_progress(have: int, need: int) -> void:
	_progress_bar.max_value = maxi(need, 1)
	_progress_bar.value = have
	_progress_label.text = "%d / %d" % [have, need]


func set_active(active: bool) -> void:
	_active = active
	_apply_state()


func flash_completed() -> void:
	_flash(COMPLETED_COLOR)


func flash_cleared() -> void:
	_flash(CLEARED_COLOR)
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	for angle: float in [0.06, -0.06, 0.04, -0.03, 0.0]:
		_shake_tween.tween_property(self, ^"rotation", angle, 0.05)


func _apply_state() -> void:
	_style.bg_color = _base_bg
	_style.border_color = ACTIVE_BORDER if _active else NORMAL_BORDER
	_style.set_border_width_all(6 if _active else 3)
	modulate.a = 1.0 if _active else INACTIVE_ALPHA


func _flash(color: Color) -> void:
	if _flash_tween:
		_flash_tween.kill()
	modulate.a = 1.0
	_style.border_color = color
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_bg_color, color.darkened(0.55), _base_bg, FLASH_TIME)
	_flash_tween.finished.connect(_apply_state)


func _set_bg_color(color: Color) -> void:
	_style.bg_color = color
