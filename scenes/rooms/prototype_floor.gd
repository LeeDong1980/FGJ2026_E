@tool
extends Node3D
## One reusable left room / dragon channel / right room module.

const ROOM_SIZE: Vector3 = Vector3(8.0, 4.0, 8.0)
const CHANNEL_WIDTH: float = 8.0
const FLOOR_SPACING: float = 5.0

@export var floor_index: int = 0
@export var ceilings_visible: bool = false:
	set(value):
		ceilings_visible = value
		if is_node_ready():
			_apply_ceiling_visibility()


func _ready() -> void:
	_apply_ceiling_visibility()


func get_room(side: StringName) -> Node3D:
	match side:
		&"left":
			return get_node("LeftRoom") as Node3D
		&"right":
			return get_node("RightRoom") as Node3D
	return null


func get_anchor(anchor_name: StringName) -> Marker3D:
	match anchor_name:
		&"DragonAnchor":
			return get_node("DragonAnchor") as Marker3D
		&"QueueSpawnAnchor", &"QueueFrontAnchor":
			return get_room(&"left").get_node_or_null(NodePath(str(anchor_name))) as Marker3D
		&"PotAnchor", &"NestAnchor", &"HatchlingAnchor", &"EggAnchor":
			return get_room(&"right").get_node_or_null(NodePath(str(anchor_name))) as Marker3D
	return null


func set_ceilings_visible(enabled: bool) -> void:
	ceilings_visible = enabled


func _apply_ceiling_visibility() -> void:
	for side in [&"left", &"right"]:
		get_room(side).set("ceiling_visible", ceilings_visible)
