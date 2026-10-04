class_name StunBanner
extends CanvasLayer
## 螢幕上方（上方資訊列下面）顯示龍的暈眩／無敵狀態。暈眩時文字晃動，剛被打中時放大彈出。

@export var game_manager: GameManager
## 晃動的最大位移（像素）。
@export var shake_strength: float = 10.0
## 和畫面頂端的距離，避開 PlayHud 的上方資訊列。
@export var top_margin: float = 120.0

const STUN_COLOR := Color(1.0, 0.85, 0.2)
const INVINCIBLE_COLOR := Color(0.5, 0.85, 1.0)

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 64)
	_label.add_theme_constant_override("outline_size", 16)
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_label.size = Vector2(600.0, 90.0)
	_label.pivot_offset = _label.size / 2.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)
	game_manager.dragon_stunned.connect(_on_dragon_stunned)


func _process(_delta: float) -> void:
	var base := Vector2((_label.get_viewport_rect().size.x - _label.size.x) / 2.0, top_margin)
	if game_manager.state != GameManager.GameState.PLAYING:
		_label.visible = false
	elif game_manager.is_stunned():
		_label.visible = true
		_label.text = "暈眩！%.1f" % game_manager.stun_remaining
		_label.modulate = STUN_COLOR
		var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength
		_label.position = base + shake
	elif game_manager.is_invincible():
		_label.visible = true
		_label.text = "無敵 %.1f" % game_manager.invincible_remaining
		_label.modulate = INVINCIBLE_COLOR
		_label.position = base
	else:
		_label.visible = false


func _on_dragon_stunned() -> void:
	_label.scale = Vector2.ONE * 1.6
	create_tween().tween_property(_label, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
