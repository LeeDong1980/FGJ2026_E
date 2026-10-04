class_name ScoreBanner
extends CanvasLayer
## 畫面右上角顯示分數與快速加分倒數；完成一鍋時在分數旁跳出「+150 快速！」。

@export var game_manager: GameManager
## 和畫面右上角的距離。
@export var margin: Vector2 = Vector2(24.0, 20.0)

const FAST_COLOR := Color(1.0, 0.85, 0.3)
const NORMAL_COLOR := Color(1.0, 1.0, 1.0)
const EXPIRED_COLOR := Color(0.6, 0.6, 0.65)

var _box: VBoxContainer
var _score_label: Label
var _timer_label: Label
var _popup: Label
var _popup_tween: Tween


func _ready() -> void:
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_score_label = _make_label(44)
	_timer_label = _make_label(26)
	_box.add_child(_score_label)
	_box.add_child(_timer_label)
	_popup = _make_label(36)
	_popup.modulate.a = 0.0
	add_child(_popup)
	game_manager.score_changed.connect(_on_score_changed)
	_on_score_changed(game_manager.score, 0, false)


func _process(_delta: float) -> void:
	var view := _box.get_viewport_rect().size
	_box.position = Vector2(view.x - _box.size.x - margin.x, margin.y)
	_popup.position = Vector2(_box.position.x + _box.size.x - _popup.size.x, _box.position.y + _box.size.y + 6.0)
	var left := game_manager.fast_time - game_manager.since_last_pot
	if left > 0.0:
		_timer_label.text = "快速加分 %d:%02d" % [int(left) / 60, int(left) % 60]
		_timer_label.modulate = FAST_COLOR if left > 10.0 else Color(1.0, 0.4, 0.3)
	else:
		_timer_label.text = "快速加分已過"
		_timer_label.modulate = EXPIRED_COLOR


func _on_score_changed(score: int, gained: int, fast: bool) -> void:
	_score_label.text = "分數 %d" % score
	if gained <= 0:
		return
	_popup.text = "+%d%s" % [gained, " 快速！" if fast else ""]
	_popup.modulate = Color(FAST_COLOR if fast else NORMAL_COLOR, 1.0)
	if _popup_tween != null:
		_popup_tween.kill()
	_popup_tween = create_tween()
	_popup_tween.tween_interval(1.2)
	_popup_tween.tween_property(_popup, ^"modulate:a", 0.0, 0.5)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
