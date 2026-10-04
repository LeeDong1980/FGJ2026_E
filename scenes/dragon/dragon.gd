class_name Dragon
extends Node3D
## 龍在各層之間等速移動。所在層依龍目前的位置判斷，不是依目標層。

signal current_lane_changed(lane: int)

@export var lane_layout: LaneLayout
@export var move_speed: float = 6.0

var target_lane: int = 0
var current_lane: int = 0
## 暈眩中停在原地，目標層照常記錄，醒來後才飛過去。由 GameManager 設定。
var stunned: bool = false


func _ready() -> void:
	# 單獨執行 dragon.tscn（F6）時沒有 LaneLayout，只顯示模型、不移動。
	if lane_layout == null:
		set_process(false)
		return
	reset_position()


func _process(delta: float) -> void:
	if stunned:
		return
	position.y = move_toward(position.y, _lane_y(target_lane), move_speed * delta)
	var lane := lane_layout.get_lane_at(position.y - lane_layout.position.y)
	if lane != current_lane:
		current_lane = lane
		current_lane_changed.emit(current_lane)


## 立刻回到中間層（開始或重新遊玩時使用）。
func reset_position() -> void:
	target_lane = floori(lane_layout.lane_count / 2.0)
	position.y = _lane_y(target_lane)
	if current_lane != target_lane:
		current_lane = target_lane
		current_lane_changed.emit(current_lane)


## 嘴部掛點，給特效（DragonEffects.bind_dragon）使用。
func get_mouth_anchor() -> Marker3D:
	return ($Model as RedDragon).get_mouth_anchor()


func set_target_lane(lane: int) -> void:
	target_lane = clampi(lane, 0, lane_layout.lane_count - 1)


func _lane_y(lane: int) -> float:
	return lane_layout.position.y + lane_layout.get_lane_position(lane)
