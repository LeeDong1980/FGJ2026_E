class_name PitchLaneInput
extends Node
## 麥克風音高橋接（單機版玩家 1）：音高區間（MicInput.pitch_value 0～100）平均切成層數段，低／中／高音對應第 1／2／3 層，等同按 1／2／3。
## 吸與吐仍由 KeyboardInput 的 J／K 處理。

## 換層遲滯：音高要超過層界線這麼多（0～100 刻度）才換層，避免在界線附近來回跳。
@export var hysteresis: float = 3.0
## 在畫面左上角顯示音高與目標層，確認訊號有沒有傳到。
@export var show_debug: bool = true
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
	if MicInput.pitch_active:
		var lane := _pick_lane(MicInput.pitch_value, lane_count)
		if lane != _lane:
			_lane = lane
			dragon.set_target_lane(lane)
	if _label != null:
		_label.text = "音高 %.0f Hz（%.0f／100）%s → 目標層 %d" % [
			MicInput.pitch_hz, MicInput.pitch_value, "" if MicInput.pitch_active else "（無音高）", _lane + 1]


## 平均切段；已經在某一層時，要越過界線 hysteresis 才換。
func _pick_lane(value: float, lane_count: int) -> int:
	var step := 100.0 / lane_count
	var raw := clampi(int(value / step), 0, lane_count - 1)
	if _lane < 0 or _lane >= lane_count or raw == _lane:
		return raw
	var low_edge := _lane * step
	var high_edge := (_lane + 1) * step
	if value < low_edge - hysteresis or value > high_edge + hysteresis:
		return raw
	return _lane
