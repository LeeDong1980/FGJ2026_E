@tool
extends Node3D
## Visibility and physical closure are switched together.


func _ready() -> void:
	set_enabled(visible)


func set_enabled(enabled: bool) -> void:
	visible = enabled
	var collision: CollisionShape3D = get_node("Body/Collision")
	collision.set_deferred("disabled", not enabled)
