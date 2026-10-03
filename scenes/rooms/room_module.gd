@tool
extends Node3D
## Room origin is the centre of the floor's upper surface. +Z is the open front.

@export var ceiling_visible: bool = false:
	set(value):
		ceiling_visible = value
		if is_node_ready():
			_apply_ceiling_visibility()


func _ready() -> void:
	_apply_ceiling_visibility()


func get_anchor(anchor_name: StringName) -> Marker3D:
	return get_node_or_null(NodePath(str(anchor_name))) as Marker3D


func _apply_ceiling_visibility() -> void:
	var ceiling: Node3D = get_node("CeilingAnchor/RoomCeiling")
	ceiling.call("set_enabled", ceiling_visible)
