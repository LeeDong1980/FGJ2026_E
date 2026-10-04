class_name PlayerInputPanels
extends Control
## 玩家 1／玩家 2 的輸入顯示，沿用遊玩介面（PlayHud）的樣式：左下玩家 1 的音高條、右下玩家 2 的吸／吐大字。
## 只負責顯示，資料由呼叫端（房間等候頁）餵進來。「我的」那一塊會多一個語音開關。

const LANE_COUNT: int = 3

@onready var _meter: VolumeMeter = %VolumeMeter
@onready var _p1_caption: Label = %Player1Caption
@onready var _p1_toggle: CheckButton = %Player1Toggle
@onready var _word_label: Label = %WordLabel
@onready var _p2_caption: Label = %Player2Caption
@onready var _p2_toggle: CheckButton = %Player2Toggle

var _word_tween: Tween


func _ready() -> void:
	_meter.thresholds = _even_thresholds(LANE_COUNT)
	_meter.current_lane = -1
	_p1_toggle.toggled.connect(func(on: bool) -> void: MicInput.pitch_input_enabled = on)
	_p2_toggle.toggled.connect(func(on: bool) -> void: MicInput.action_input_enabled = on)
	_word_label.text = "—"
	_word_label.modulate.a = 0.45


func _process(_delta: float) -> void:
	# 暫停選單或其他地方改了開關時跟著更新
	_p1_toggle.set_pressed_no_signal(MicInput.pitch_input_enabled)
	_p2_toggle.set_pressed_no_signal(MicInput.action_input_enabled)


## 玩家 1：level 是 0～1 的音高比例，lane 是對應的層（0 是最低層，-1 不亮）。
func set_pitch(level: float, lane: int) -> void:
	_meter.level = level
	_meter.current_lane = lane


## 玩家 1 的說明文字與語音開關；is_mine 為 true（這台電腦就是玩家 1）才顯示開關。
func set_player1(caption: String, is_mine: bool) -> void:
	_p1_caption.text = caption
	_p1_toggle.visible = is_mine


## 玩家 2 的說明文字與語音開關；is_mine 為 true（這台電腦負責玩家 2 的輸入）才顯示開關。
func set_player2(caption: String, is_mine: bool) -> void:
	_p2_caption.text = caption
	_p2_toggle.visible = is_mine


## 玩家 2 的動作（NetworkManager.ACTION_*）。吸／吐剛開始時放大並閃一下，放開後保留最後的字並變淡。
func show_action(action: String) -> void:
	match action:
		NetworkManager.ACTION_INHALE:
			_pop("吸")
		NetworkManager.ACTION_EXHALE:
			_pop("吐")
		_:
			_fade()


func _pop(word: String) -> void:
	_word_label.text = word
	_word_label.pivot_offset = _word_label.size / 2.0
	if _word_tween:
		_word_tween.kill()
	_word_label.scale = Vector2.ONE * 1.35
	_word_label.modulate.a = 1.0
	_word_tween = create_tween()
	_word_tween.tween_property(_word_label, ^"scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fade() -> void:
	if _word_tween:
		_word_tween.kill()
	_word_tween = create_tween()
	_word_tween.tween_property(_word_label, ^"modulate:a", 0.45, 0.6)


func _even_thresholds(lane_count: int) -> PackedFloat32Array:
	var thresholds := PackedFloat32Array()
	for i in range(1, lane_count):
		thresholds.append(float(i) / lane_count)
	return thresholds
