class_name PlayerPitchInput
extends Node
## 玩家 1（音高換層）的本機輸入：電腦麥克風，或連上的手機（PhoneMic）的音高，換算成 0～1 的音高比例與層。
## 層的換算與遊戲內相同（PitchLaneInput.pick_lane），所以這裡看到的層就是進遊戲後龍會去的層。
## send_to_peer 開啟時把音高與層傳給對方：層改變時立刻送，平時每秒約 15 次（對方靠它顯示，連線局中也靠它控制龍）。
## client_play（連線局）與房間等候頁共用。

const LANE_COUNT: int = 3
const SEND_INTERVAL: float = 1.0 / 15.0

## 關閉時不讀輸入，音高視為 0、層視為 -1（沒有）。
@export var enabled: bool = true
@export var send_to_peer: bool = false
## 優先讀第幾號玩家的手機（1 或 2）；沒連上就讀電腦麥克風。0 = 只用電腦麥克風。
@export_range(0, 2) var phone_player: int = 1
## 換層遲滯，與 PitchLaneInput.hysteresis 的預設值相同。
@export var hysteresis: float = 3.0

## 0～1 的音高比例（沒有聲音時維持最後的值，與 MicInput 一致）。
var level: float = 0.0
## 目前的層（0 是最低層），-1 表示還沒有。即使「音高輸入」開關關閉也照常量測，讓玩家看得出麥克風有沒有收到。
var lane: int = -1
## 這個輸入現在會不會真的控制龍：本元件啟用，而且「音高輸入」開關（MicInput.pitch_input_enabled）是開的。
## 開關關閉時傳給對方的層是 -1，對方不會用它換層。
var controls_dragon: bool = false

var _timer: float = 0.0


func _process(delta: float) -> void:
	var previous_sent_lane: int = _sent_lane()
	if enabled:
		var voice: Node = _voice()
		level = voice.pitch_value / 100.0
		if voice.pitch_active:
			lane = PitchLaneInput.pick_lane(voice.pitch_value, LANE_COUNT, lane, hysteresis)
	else:
		level = 0.0
		lane = -1
	controls_dragon = enabled and MicInput.pitch_input_enabled
	if not (send_to_peer and enabled):
		return
	_timer += delta
	if _sent_lane() != previous_sent_lane or _timer >= SEND_INTERVAL:
		_timer = 0.0
		NetworkManager.send_pitch(level, _sent_lane())


## 傳給對方的層：開關關閉時是 -1（沒有）。
func _sent_lane() -> int:
	return lane if controls_dragon else -1


func _voice() -> Node:
	if phone_player > 0 and PhoneMic.is_player_connected(phone_player):
		return PhoneMic.get_source(phone_player)
	return MicInput
