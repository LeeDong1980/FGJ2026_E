class_name PlayerActionInput
extends Node
## 玩家 2（吸／吐）的本機輸入：鍵盤 J（吸）、K（吐，按住），以及語音（電腦麥克風，或連上的手機）。
## 鍵盤優先於語音，吐優先於吸。動作改變時發出 action_changed，send_to_peer 開啟時也把變化傳給對方
## （Client 傳給 Host，Host 只在等候頁傳給 Client 顯示）。client_play（連線局）與房間等候頁共用。

signal action_changed(action: String)

## 關閉時不讀任何輸入，動作視為 ACTION_NONE。
@export var enabled: bool = true
## 動作改變時送給對方（NetworkManager.send_voice_action）。
@export var send_to_peer: bool = false
## 優先讀第幾號玩家的手機（1 或 2）；沒連上就讀電腦麥克風。0 = 只用電腦麥克風。
@export_range(0, 2) var phone_player: int = 2

## 目前的動作（NetworkManager.ACTION_*）。
var action: String = NetworkManager.ACTION_NONE


func _process(_delta: float) -> void:
	var next: String = NetworkManager.ACTION_NONE
	if enabled and not get_tree().paused:
		next = _keyboard_action()
		if next == NetworkManager.ACTION_NONE:
			next = _voice_action()
	if next == action:
		return
	action = next
	if send_to_peer:
		NetworkManager.send_voice_action(next)
	action_changed.emit(next)


func _exit_tree() -> void:
	# 離開時還按著的話補送放開，避免對方一直在噴火。
	if send_to_peer and action != NetworkManager.ACTION_NONE:
		NetworkManager.send_voice_action(NetworkManager.ACTION_NONE)


func _keyboard_action() -> String:
	if Input.is_action_pressed(&"spit"):
		return NetworkManager.ACTION_EXHALE
	if Input.is_action_pressed(&"suck"):
		return NetworkManager.ACTION_INHALE
	return NetworkManager.ACTION_NONE


func _voice_action() -> String:
	if not MicInput.action_input_enabled:
		return NetworkManager.ACTION_NONE
	var voice: Node = MicInput
	if phone_player > 0 and PhoneMic.is_player_connected(phone_player):
		voice = PhoneMic.get_source(phone_player)
	match voice.action:
		MicController.INHALE:
			return NetworkManager.ACTION_INHALE
		MicController.EXHALE:
			return NetworkManager.ACTION_EXHALE
	return NetworkManager.ACTION_NONE
