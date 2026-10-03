@tool
class_name LaneLayout
extends Node3D
## 依層數與層距產生各層的左右平台，並提供樓層位置的查詢。
## 各層沿 Y 軸垂直排放。層的編號：0 是最低層，編號越大越高。

@export_range(1, 10) var lane_count: int = 3:
	set(value):
		lane_count = value
		_rebuild()
@export var lane_spacing: float = 3.0:
	set(value):
		lane_spacing = value
		_rebuild()
## 左右平台中心到中線的距離。
@export var platform_offset_x: float = 3.8:
	set(value):
		platform_offset_x = value
		_rebuild()
## 平台頂面到該層中心的高度差（平台在龍的下方）。
@export var platform_offset_y: float = -0.08:
	set(value):
		platform_offset_y = value
		_rebuild()
@export var platform_scene: PackedScene = preload("res://scenes/platforms/cube_platform.tscn"):
	set(value):
		platform_scene = value
		_rebuild()


func _ready() -> void:
	_rebuild()


## 第 index 層中心的 Y 座標（LaneLayout 的本地座標）。
func get_lane_position(index: int) -> float:
	return (index - _center_index()) * lane_spacing


## Y 座標 y 落在哪一層的範圍內，以相鄰兩層的中線為界。
func get_lane_at(y: float) -> int:
	if lane_spacing <= 0.0:
		return 0
	return clampi(roundi(y / lane_spacing + _center_index()), 0, lane_count - 1)


func _center_index() -> float:
	return (lane_count - 1) / 2.0


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if platform_scene == null:
		return
	for i in lane_count:
		var y := get_lane_position(i) + platform_offset_y
		_add_platform("Lane%dLeft" % i, Vector3(-platform_offset_x, y, 0.0))
		_add_platform("Lane%dRight" % i, Vector3(platform_offset_x, y, 0.0))
	# 最高層上方再放一組平台當天花板，位置等同第 lane_count 層。
	var ceiling_y := get_lane_position(lane_count) + platform_offset_y
	_add_platform("CeilingLeft", Vector3(-platform_offset_x, ceiling_y, 0.0))
	_add_platform("CeilingRight", Vector3(platform_offset_x, ceiling_y, 0.0))


func _add_platform(node_name: String, pos: Vector3) -> void:
	var platform := platform_scene.instantiate() as Node3D
	platform.name = node_name
	platform.position = pos
	add_child(platform)
