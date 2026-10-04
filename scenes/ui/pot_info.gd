class_name PotInfo
extends PanelContainer
## 單一層鍋子的資訊：禁止食材與收集進度。
## 外框用 UI 素材包的石框：一般是灰色，龍所在的層換成橘金色、其他層變暗；
## 完成時外框染綠色，被清空時染紅色並晃動。

const NORMAL_FRAME := preload("res://scenes/ui/UI/Sprites/Components/Frame/StageFrame_Demo_n.Png")
const ACTIVE_FRAME := preload("res://scenes/ui/UI/Sprites/Components/Frame/StageFrame_Demo_f.Png")
const COMPLETED_TINT := Color(0.55, 1.35, 0.55)
const CLEARED_TINT := Color(1.5, 0.45, 0.4)
const INACTIVE_ALPHA := 0.65
const FLASH_TIME := 0.8

var _style: StyleBoxTexture
var _active := false
var _flash_tween: Tween
var _shake_tween: Tween

@onready var _icons: HBoxContainer = %ForbiddenIcons
@onready var _progress_label: Label = %ProgressLabel


func _ready() -> void:
	# 每個鍋子各自一份 StyleBox，才能分別換外框與染色。
	_style = get_theme_stylebox(&"panel").duplicate()
	add_theme_stylebox_override(&"panel", _style)
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	set_active(false)


func set_forbidden(types: Array) -> void:
	# 先移出再釋放：queue_free 要等到這一幀結束，舊圖示留著會把面板撐寬。
	for child in _icons.get_children():
		_icons.remove_child(child)
		child.queue_free()
	for type: IngredientType.Type in types:
		var icon := ForbiddenIcon.new()
		icon.type = type
		_icons.add_child(icon)
	# PanelContainer 只會長大不會自己縮，圖示變少時縮回最小尺寸。
	reset_size()


func set_progress(have: int, need: int) -> void:
	_progress_label.text = "%d/%d" % [have, need]
	reset_size()


func set_active(active: bool) -> void:
	_active = active
	_apply_state()


func flash_completed() -> void:
	_flash(COMPLETED_TINT)


func flash_cleared() -> void:
	_flash(CLEARED_TINT)
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	for angle: float in [0.06, -0.06, 0.04, -0.03, 0.0]:
		_shake_tween.tween_property(self, ^"rotation", angle, 0.05)


func _apply_state() -> void:
	_style.texture = ACTIVE_FRAME if _active else NORMAL_FRAME
	_style.modulate_color = Color.WHITE
	modulate.a = 1.0 if _active else INACTIVE_ALPHA


func _flash(tint: Color) -> void:
	if _flash_tween:
		_flash_tween.kill()
	modulate.a = 1.0
	_style.texture = ACTIVE_FRAME
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_tint, tint, Color.WHITE, FLASH_TIME)
	_flash_tween.finished.connect(_apply_state)


func _set_tint(tint: Color) -> void:
	_style.modulate_color = tint
