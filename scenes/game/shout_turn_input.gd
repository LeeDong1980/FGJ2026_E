class_name ShoutTurnInput
extends Node
## 大叫轉頭橋接（玩家 1）：音量（volume_value，0～100）超過 MicInput.shout_threshold 就呼叫 turn_head()，龍頭左右切換。
## 門檻在 Esc 暫停選單的麥克風設定面板調整（shout_threshold／shout_release，會存檔）。
## 鍵盤 4（轉頭）由 KeyboardInput（連線局是 NetworkGameBridge）處理，兩者互不影響。連線局 Host 是玩家 1，照常讀 Host 的麥克風。
## 手機 phone_player 有連上時改讀手機的音量（PhoneMic），沒連上就讀電腦麥克風（MicInput）。

@export var game_manager: GameManager
## 兩次轉頭的最短間隔（秒）。
@export var cooldown: float = 0.4
## 優先讀第幾號玩家的手機（1 或 2）；0 = 只用電腦麥克風
@export_range(0, 2) var phone_player: int = 1

var _detector := ShoutDetector.new()


func _process(delta: float) -> void:
	_detector.threshold = MicInput.shout_threshold
	_detector.release = MicInput.shout_release
	_detector.cooldown = cooldown
	if _detector.update(_voice().volume_value, delta):
		game_manager.turn_head()


## 手機有連上就用手機（PhoneVoiceSource），否則用電腦麥克風；兩者欄位相同。
func _voice() -> Node:
	if phone_player > 0 and PhoneMic.is_player_connected(phone_player):
		return PhoneMic.get_source(phone_player)
	return MicInput
