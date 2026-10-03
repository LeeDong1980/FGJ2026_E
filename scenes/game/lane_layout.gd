@tool
class_name LaneLayout
extends Node3D
## 依層數與層距產生各層樓層（prototype_floor），並提供樓層位置與房間定位點的查詢。
## 各層沿 Y 軸垂直排放。層的編號：0 是最低層，編號越大越高。層的 Y 座標是該層地板頂面。

@export_range(1, 10) var lane_count: int = 3:
	set(value):
		lane_count = value
		_rebuild()
@export var lane_spacing: float = 5.0:
	set(value):
		lane_spacing = value
		_rebuild()
@export var floor_scene: PackedScene = preload("res://scenes/rooms/prototype_floor.tscn"):
	set(value):
		floor_scene = value
		_rebuild()
## 層數改變時重新取景的展示 rig（prototype_presentation.tscn），可留空。
@export var presentation: Node3D:
	set(value):
		presentation = value
		_rebuild()

var _floors: Array[Node3D] = []


func _ready() -> void:
	_rebuild()


## 第 index 層地板頂面的 Y 座標（LaneLayout 的本地座標）。
func get_lane_position(index: int) -> float:
	return index * lane_spacing


## Y 座標 y 落在哪一層的範圍內，以相鄰兩層的中線為界。
func get_lane_at(y: float) -> int:
	if lane_spacing <= 0.0:
		return 0
	return clampi(roundi(y / lane_spacing), 0, lane_count - 1)


## 第 lane 層房間定位點的位置（LaneLayout 的本地座標），名稱見 prototype_floor.gd 的 get_anchor()。
## 找不到定位點時回傳該層中心。
func get_anchor_position(lane: int, anchor_name: StringName) -> Vector3:
	var center := Vector3(0.0, get_lane_position(lane), 0.0)
	if lane < 0 or lane >= _floors.size():
		return center
	var anchor: Marker3D = _floors[lane].call(&"get_anchor", anchor_name)
	if anchor == null:
		return center
	return to_local(anchor.global_position)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_floors.clear()
	if floor_scene == null:
		return
	for i in lane_count:
		var floor_node := floor_scene.instantiate() as Node3D
		floor_node.name = "Floor%d" % i
		floor_node.position = Vector3(0.0, get_lane_position(i), 0.0)
		floor_node.set(&"floor_index", i)
		add_child(floor_node)
		_floors.append(floor_node)
	if presentation != null and presentation.has_method(&"configure_for_layers"):
		presentation.call(&"configure_for_layers", lane_count, lane_spacing)
