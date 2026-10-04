@tool
extends Node3D
## Origin stays at the original core-floor centre while the outside extends.
## +Z is the open front. Props and gameplay anchors do not inherit extension.

@export_enum("Left:-1", "Right:1") var outward_direction: int = 1
@export_range(0.0, 40.0, 0.05) var outer_extension: float = 0.0:
	set(value):
		if not is_finite(value):
			return
		outer_extension = clampf(value, 0.0, 40.0)
		if is_node_ready():
			_apply_extension()

var _original_positions: Dictionary = {}
var _extension_geometry: Node3D

@export var ceiling_visible: bool = false:
	set(value):
		ceiling_visible = value
		if is_node_ready():
			_apply_ceiling_visibility()


func _ready() -> void:
	for child: Node3D in get_node("Architecture").get_children():
		_original_positions[child.name] = child.position
	_apply_extension()
	_apply_ceiling_visibility()


## Extends only the outside of this room. Gameplay anchors and props stay fixed.
func set_outer_extension(distance: float) -> void:
	outer_extension = distance


func _apply_extension() -> void:
	if _original_positions.is_empty():
		return
	var architecture: Node3D = get_node("Architecture")
	if is_instance_valid(_extension_geometry):
		architecture.remove_child(_extension_geometry)
		_extension_geometry.queue_free()
	_extension_geometry = Node3D.new()
	_extension_geometry.name = "OuterExtension"
	architecture.add_child(_extension_geometry)
	var direction: float = -1.0 if outward_direction < 0 else 1.0
	for child_name: StringName in _original_positions:
		var child: Node3D = architecture.get_node(NodePath(child_name)) as Node3D
		var original: Vector3 = _original_positions[child_name]
		if str(child_name).begins_with("OuterWall") or child_name == &"OuterCornice" \
				or child_name == &"ColumnOuterFront" \
				or child_name == (&"ColumnBackLeft" if direction < 0.0 else &"ColumnBackRight"):
			child.position = original + Vector3(direction * outer_extension, 0.0, 0.0)
	for name: String in ["Foundation", "BackCornice"]:
		var node: Node3D = architecture.get_node(name) as Node3D
		node.position = _original_positions[StringName(name)] + Vector3(direction * outer_extension * 0.5, 0.0, 0.0)
		_resize_box(node, 8.0 + outer_extension)
	var cursor: float = 0.0
	while cursor < outer_extension - 0.00001:
		var width: float = minf(4.0, outer_extension - cursor)
		var x: float = direction * (4.0 + cursor + width * 0.5)
		for seed: String in (["Floor00", "Floor01"] if direction < 0.0 else ["Floor10", "Floor11"]):
			_add_segment(architecture.get_node(seed) as Node3D, x, width)
		_add_segment(architecture.get_node("BackWall0") as Node3D, x, width)
		cursor += width
	get_node("CeilingAnchor/RoomCeiling").call("set_outer_extension", outer_extension, direction)


func _add_segment(seed: Node3D, x: float, width: float) -> void:
	var segment: Node3D = seed.duplicate() as Node3D
	segment.name = str(seed.name) + "_" + str(_extension_geometry.get_child_count())
	segment.position.x = x
	segment.scale.x = width / 4.0
	_extension_geometry.add_child(segment)


func _resize_box(node: Node3D, width: float) -> void:
	var mesh: MeshInstance3D = node.get_node("Mesh") as MeshInstance3D
	mesh.mesh = mesh.mesh.duplicate()
	(mesh.mesh as BoxMesh).size.x = width
	var collision: CollisionShape3D = node.get_node("Body/Collision") as CollisionShape3D
	collision.shape = collision.shape.duplicate()
	(collision.shape as BoxShape3D).size.x = width


func get_anchor(anchor_name: StringName) -> Marker3D:
	return get_node_or_null(NodePath(str(anchor_name))) as Marker3D


func _apply_ceiling_visibility() -> void:
	var ceiling: Node3D = get_node("CeilingAnchor/RoomCeiling")
	ceiling.call("set_enabled", ceiling_visible)
