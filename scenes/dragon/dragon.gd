class_name Dragon
extends Node3D
## 龍在各層之間等速移動。所在層依龍目前的位置判斷，不是依目標層。

signal current_lane_changed(lane: int)

@export var lane_layout: LaneLayout
@export var move_speed: float = 6.0

var target_lane: int = 0
var current_lane: int = 0


func _ready() -> void:
	target_lane = floori(lane_layout.lane_count / 2.0)
	position.y = _lane_y(target_lane)
	current_lane = target_lane


func _process(delta: float) -> void:
	position.y = move_toward(position.y, _lane_y(target_lane), move_speed * delta)
	var lane := lane_layout.get_lane_at(position.y - lane_layout.position.y)
	if lane != current_lane:
		current_lane = lane
		current_lane_changed.emit(current_lane)


func set_target_lane(lane: int) -> void:
	target_lane = clampi(lane, 0, lane_layout.lane_count - 1)


func _lane_y(lane: int) -> float:
	return lane_layout.position.y + lane_layout.get_lane_position(lane)
