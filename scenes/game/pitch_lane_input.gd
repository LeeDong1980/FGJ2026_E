class_name PitchLaneInput
extends Node
## 麥克風音高橋接（單機版玩家 1）：音高區間（MicInput.pitch_value 0～100）平均切成層數段，低／中／高音對應第 1／2／3 層，等同按 1／2／3。
## 吸與吐由 KeyboardInput（J／K）與 VoiceActionInput（語音）各自處理。MicInput.pitch_input_enabled 可關閉音高輸入。
## 手機 phone_player 有連上時改讀手機的音高（PhoneMic），沒連上就讀電腦麥克風（MicInput）。

## 換層遲滯：音高要超過層界線這麼多（0～100 刻度）才換層，避免在界線附近來回跳。
@export var hysteresis: float = 3.0
## 在畫面左上角顯示音高與目標層，確認訊號有沒有傳到。
@export var show_debug: bool = true
## 優先讀第幾號玩家的手機（1 或 2）；0 = 只用電腦麥克風
@export_range(0, 2) var phone_player: int = 1
@export var dragon: Dragon
@export var game_manager: GameManager

var _lane: int = -1
var _label: Label


func _ready() -> void:
	if show_debug:
		var layer := CanvasLayer.new()
		_label = Label.new()
		_label.position = Vector2(12, 12)
		layer.add_child(_label)
		add_child(layer)


func _process(_delta: float) -> void:
	var lane_count: int = game_manager.lane_layout.lane_count
	var voice: Node = _voice()
	if MicInput.pitch_input_enabled and voice.pitch_active:
		var lane := pick_lane(voice.pitch_value, lane_count, _lane, hysteresis)
		if lane != _lane:
			_lane = lane
			dragon.set_target_lane(lane)
	if _label != null:
		_label.text = "%s音高 %.0f Hz（%.0f／100）%s → 目標層 %d" % [
			"手機 %d " % phone_player if voice != MicInput else "",
			voice.pitch_hz, voice.pitch_value, "" if voice.pitch_active else "（無音高）" if MicInput.pitch_input_enabled else "（已關閉）", _lane + 1]


## 手機有連上就用手機（PhoneVoiceSource），否則用電腦麥克風；兩者欄位相同。
func _voice() -> Node:
	if phone_player > 0 and PhoneMic.is_player_connected(phone_player):
		return PhoneMic.get_source(phone_player)
	return MicInput


## 平均切段；已經在 current 層時，要越過界線 hysteresis 才換。current 為 -1 表示還沒有目前的層。
## 等候頁的玩家 1 顯示也用這個函式，才會和遊戲內換層的結果一致。
static func pick_lane(value: float, lane_count: int, current: int, hysteresis: float) -> int:
	var step := 100.0 / lane_count
	var raw := clampi(int(value / step), 0, lane_count - 1)
	if current < 0 or current >= lane_count or raw == current:
		return raw
	var low_edge := current * step
	var high_edge := (current + 1) * step
	if value < low_edge - hysteresis or value > high_edge + hysteresis:
		return raw
	return current
