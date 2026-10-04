@tool
extends Node3D
## Visibility and physical closure are switched together.

## Keep the decorative stone faces below the slab's underside, not coplanar.
@export_range(0.001, 0.05, 0.001) var underside_offset: float = 0.01:
	set(value):
		underside_offset = clampf(value, 0.001, 0.05)
		if is_node_ready():
			_apply_underside_offset()

var _extension_geometry: Node3D


## Fill up to the upper foundation without overlapping its front/side faces.
## Duplicate resources so each generated floor keeps its own dimensions.
func set_fill_height(height: float) -> void:
	if not is_finite(height) or height <= 0.0:
		return
	var slab: MeshInstance3D = get_node("StoneSlab/Mesh") as MeshInstance3D
	slab.mesh = slab.mesh.duplicate()
	(slab.mesh as BoxMesh).size.y = height
	get_node("StoneSlab").position.y = height * 0.5
	var collision: CollisionShape3D = get_node("Body/Collision") as CollisionShape3D
	collision.shape = collision.shape.duplicate()
	(collision.shape as BoxShape3D).size.y = height
	collision.position.y = height * 0.5


func set_outer_extension(distance: float, direction: float) -> void:
	if not is_finite(distance) or not is_finite(direction):
		return
	var extension: float = clampf(distance, 0.0, 40.0)
	var side: float = -1.0 if direction < 0.0 else 1.0
	var slab: MeshInstance3D = get_node("StoneSlab/Mesh") as MeshInstance3D
	slab.mesh = slab.mesh.duplicate()
	(slab.mesh as BoxMesh).size.x = 8.0 + extension
	get_node("StoneSlab").position.x = side * extension * 0.5
	var collision: CollisionShape3D = get_node("Body/Collision") as CollisionShape3D
	collision.shape = collision.shape.duplicate()
	(collision.shape as BoxShape3D).size.x = 8.0 + extension
	collision.position.x = side * extension * 0.5
	if is_instance_valid(_extension_geometry):
		remove_child(_extension_geometry)
		_extension_geometry.queue_free()
	_extension_geometry = Node3D.new()
	_extension_geometry.name = "OuterExtension"
	add_child(_extension_geometry)
	var cursor: float = 0.0
	while cursor < extension - 0.00001:
		var width: float = minf(4.0, extension - cursor)
		for seed: String in (["StoneUnderside00", "StoneUnderside01"] if side < 0.0 else ["StoneUnderside10", "StoneUnderside11"]):
			var segment: Node3D = get_node(seed).duplicate() as Node3D
			segment.name = seed + "_" + str(_extension_geometry.get_child_count())
			segment.position.x = side * (4.0 + cursor + width * 0.5)
			segment.scale.x = width / 4.0
			_extension_geometry.add_child(segment)
		cursor += width


func _ready() -> void:
	_apply_underside_offset()
	set_enabled(visible)


func _apply_underside_offset() -> void:
	for seed: String in ["StoneUnderside00", "StoneUnderside01", "StoneUnderside10", "StoneUnderside11"]:
		get_node(seed).position.y = -underside_offset
	if is_instance_valid(_extension_geometry):
		for segment: Node3D in _extension_geometry.get_children():
			segment.position.y = -underside_offset


func set_enabled(enabled: bool) -> void:
	visible = enabled
	var collision: CollisionShape3D = get_node("Body/Collision")
	collision.set_deferred("disabled", not enabled)
