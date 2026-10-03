class_name VoiceActionInput
extends Node
## 麥克風輸入橋接（單機版玩家 B）：聽到「吸」呼叫 suck()，聽到「吐」開始 spit_pressed()、聲音結束或換成別的字音時 spit_released()。
## 龍的移動不在這裡處理，仍由 KeyboardInput 的 1／2／3 控制。

@export var game_manager: GameManager

var _previous_action: StringName = &""


func _ready() -> void:
	MicInput.action_changed.connect(_on_action_changed)


func _exit_tree() -> void:
	if MicInput.action_changed.is_connected(_on_action_changed):
		MicInput.action_changed.disconnect(_on_action_changed)
	if _previous_action == MicController.EXHALE:
		game_manager.spit_released()


func _on_action_changed(action: StringName) -> void:
	if _previous_action == MicController.EXHALE:
		game_manager.spit_released()
	_previous_action = action
	if get_tree().paused:
		return
	match action:
		MicController.INHALE:
			game_manager.suck()
		MicController.EXHALE:
			game_manager.spit_pressed()
