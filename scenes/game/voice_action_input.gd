class_name VoiceActionInput
extends Node
## 麥克風輸入橋接（單機版玩家 B）：聽到「吸」呼叫 suck()，聽到「吐」開始 spit_pressed()、聲音結束或換成別的字音時 spit_released()。
## 龍的移動不在這裡處理，仍由 KeyboardInput 的 1／2／3 控制。

@export var game_manager: GameManager

## 在畫面左上角顯示麥克風辨識與送進遊戲的結果，確認訊號有沒有傳到。
@export var show_debug: bool = true

var _previous_action: StringName = &""
var _label: Label


func _ready() -> void:
	MicInput.action_changed.connect(_on_action_changed)
	if show_debug:
		var layer := CanvasLayer.new()
		_label = Label.new()
		_label.position = Vector2(12, 12)
		layer.add_child(_label)
		add_child(layer)
		_log("等待聲音（遊戲需先按 Enter 開始）")
		game_manager.suck_missed.connect(func(lane: int) -> void: _log("吸空（第 %d 層沒有可吸食材或胃已滿）" % lane))
		game_manager.stomach_changed.connect(func(i: IngredientState) -> void: _log("胃袋：%s" % ("空" if i == null else "有食材")))
		game_manager.spit_missed.connect(func(lane: int) -> void: _log("吐空（第 %d 層）" % lane))


func _exit_tree() -> void:
	if MicInput.action_changed.is_connected(_on_action_changed):
		MicInput.action_changed.disconnect(_on_action_changed)
	if _previous_action == MicController.EXHALE:
		game_manager.spit_released()


func _on_action_changed(action: StringName) -> void:
	if _previous_action == MicController.EXHALE:
		game_manager.spit_released()
	_previous_action = action
	if action != &"":
		_log("辨識到 %s（遊戲狀態 %s%s）" % [action, GameManager.GameState.keys()[game_manager.state], "，暫停中不處理" if get_tree().paused else ""])
	if get_tree().paused:
		return
	match action:
		MicController.INHALE:
			game_manager.suck()
		MicController.EXHALE:
			game_manager.spit_pressed()


func _log(text: String) -> void:
	print("[VoiceActionInput] ", text)
	if _label != null:
		_label.text = text
