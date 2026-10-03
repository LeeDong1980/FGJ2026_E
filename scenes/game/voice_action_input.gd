class_name VoiceActionInput
extends Node
## 語音吸／吐橋接：MicInput 的 inhale 呼叫 suck()，exhale 開始／結束呼叫 spit_pressed()／spit_released()。
## 由 MicInput.action_input_enabled 開關；鍵盤 J／K 仍由 KeyboardInput 處理，兩者互不影響。

@export var game_manager: GameManager

var _spitting: bool = false


func _ready() -> void:
	MicInput.action_changed.connect(_on_action_changed)


func _process(_delta: float) -> void:
	# 噴火中被關閉開關時，補送放開，避免一直噴
	if _spitting and not MicInput.action_input_enabled:
		_spitting = false
		game_manager.spit_released()


func _on_action_changed(action: StringName) -> void:
	if not MicInput.action_input_enabled:
		return
	if _spitting and action != MicController.EXHALE:
		_spitting = false
		game_manager.spit_released()
	match action:
		MicController.INHALE:
			game_manager.suck()
		MicController.EXHALE:
			_spitting = true
			game_manager.spit_pressed()
