@tool
extends Node3D
## Ground-centred wrapper. Size changes affect the model, never its room anchor.

@export_range(0.2, 3.0, 0.05) var display_height: float = 2.4:
	set(value):
		if not is_finite(value):
			return
		display_height = clampf(value, 0.2, 3.0)
		if is_node_ready():
			_apply_height()


func _ready() -> void:
	_apply_height()


func _apply_height() -> void:
	var ratio: float = display_height / 1.15
	var model: Node3D = get_node("Model") as Node3D
	model.scale = Vector3.ONE * 8.654718001 * ratio
	model.position = Vector3(0.0, -0.00065677014, 0.211296117) * ratio
