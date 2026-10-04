class_name VoiceActionInput
extends Node
## 語音吸／吐橋接：MicInput 的 inhale 呼叫 suck()，exhale 開始／結束呼叫 spit_pressed()／spit_released()。
## 由 MicInput.action_input_enabled 開關；鍵盤 J／K 仍由 KeyboardInput 處理，兩者互不影響。
## 手機 phone_player 有連上時改讀手機的吸／吐（PhoneMic），沒連上就讀電腦麥克風（MicInput）。

@export var game_manager: GameManager
## 優先讀第幾號玩家的手機（1 或 2）；0 = 只用電腦麥克風
@export_range(0, 2) var phone_player: int = 2

var _spitting: bool = false
var _voice: Node


func _ready() -> void:
	_voice = _current_voice()
	MicInput.action_changed.connect(_on_action_changed.bind(MicInput))
	if phone_player > 0:
		var phone: PhoneVoiceSource = PhoneMic.get_source(phone_player)
		phone.action_changed.connect(_on_action_changed.bind(phone))


func _process(_delta: float) -> void:
	# 噴火中被關閉開關，或手機連上／斷線換了聲音來源時，補送放開，避免一直噴
	var voice: Node = _current_voice()
	if _spitting and (not MicInput.action_input_enabled or voice != _voice):
		_spitting = false
		game_manager.spit_released()
	_voice = voice


## 手機有連上就用手機（PhoneVoiceSource），否則用電腦麥克風；兩者欄位相同。
func _current_voice() -> Node:
	if phone_player > 0 and PhoneMic.is_player_connected(phone_player):
		return PhoneMic.get_source(phone_player)
	return MicInput


func _on_action_changed(action: StringName, voice: Node) -> void:
	if not MicInput.action_input_enabled or voice != _current_voice():
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
