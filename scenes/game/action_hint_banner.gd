class_name ActionHintBanner
extends CanvasLayer
## 螢幕上方（暈眩提示下面）顯示吸或吐為什麼沒有效果，停留一下後淡出。

@export var game_manager: GameManager
## 和畫面頂端的距離，放在 StunBanner 下面。
@export var top_margin: float = 210.0
## 提示停留的秒數（不含淡出）。
@export var show_time: float = 1.2
@export var fade_time: float = 0.4

const TEXTS: Dictionary = {
	GameManager.MissReason.NO_INGREDIENT: "這層前面沒有食材",
	GameManager.MissReason.STOMACH_FULL: "胃裡已經有食材，先轉向右邊吐進鍋子",
	GameManager.MissReason.FACING_RIGHT: "龍頭朝右，要轉向左邊才能吸",
	GameManager.MissReason.SPIT_FACING_LEFT: "龍頭朝左，要轉向右邊才能吐進鍋子",
	GameManager.MissReason.NOTHING_TO_SPIT: "胃是空的，鍋子還沒滿",
	GameManager.MissReason.POT_FULL: "鍋子滿了，胃空時對鍋子噴火煮好",
	GameManager.MissReason.NO_BABY: "小龍還沒到，不能吐進鍋子",
}

var _label: Label
var _tween: Tween


func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_constant_override("outline_size", 12)
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)
	game_manager.action_missed.connect(_on_action_missed)
	game_manager.game_started.connect(func() -> void: _label.modulate.a = 0.0)


func _process(_delta: float) -> void:
	var view := _label.get_viewport_rect().size
	_label.size = Vector2(view.x, 60.0)
	_label.position = Vector2(0.0, top_margin)


func _on_action_missed(_lane: int, reason: GameManager.MissReason) -> void:
	_label.text = TEXTS.get(reason, "")
	if _tween != null:
		_tween.kill()
	_label.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(show_time)
	_tween.tween_property(_label, ^"modulate:a", 0.0, fade_time)
