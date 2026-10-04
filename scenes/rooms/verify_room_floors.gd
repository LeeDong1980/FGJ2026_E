extends SceneTree
## Run with Godot --headless --path <project> --script res://scenes/rooms/verify_room_floors.gd.
## Exercises actual generated rooms, including legacy authored slab offsets.

const LAYOUT: Script = preload("res://scenes/game/lane_layout.gd")
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)


func _run() -> void:
	var layout: Node3D = LAYOUT.new()
	root.add_child(layout)
	for count: int in [1, 3]:
		layout.set(&"lane_count", count)
		for extension: float in [0.0, 2.5, 12.0, 0.0]:
			for floor_node: Node3D in layout.get_children():
				for side: StringName in [&"left", &"right"]:
					floor_node.call(&"get_room", side).call(&"set_outer_extension", extension)
			await process_frame
			await physics_frame
			for floor_node: Node3D in layout.get_children():
				for side: StringName in [&"left", &"right"]:
					var room: Node3D = floor_node.call(&"get_room", side)
					var direction: float = float(room.get("outward_direction"))
					var foundation: MeshInstance3D = room.get_node("Architecture/Foundation/Mesh")
					var bounds: AABB = room.global_transform.affine_inverse() * foundation.global_transform * foundation.get_aabb()
					var expected_left: float = -4.0 - (extension if direction < 0.0 else 0.0)
					var expected_right: float = 4.0 + (extension if direction > 0.0 else 0.0)
					_check(is_equal_approx(bounds.position.x, expected_left), "Foundation left edge matches core/extension")
					_check(is_equal_approx(bounds.end.x, expected_right), "Foundation right edge matches core/extension")
					var collision: CollisionShape3D = room.get_node("Architecture/Foundation/Body/Collision")
					_check((foundation.mesh as BoxMesh).size == (collision.shape as BoxShape3D).size, "Foundation collision matches mesh")
					var ceiling_mesh: MeshInstance3D = room.get_node("CeilingAnchor/RoomCeiling/StoneSlab/Mesh")
					var ceiling_bounds: AABB = room.global_transform.affine_inverse() * ceiling_mesh.global_transform * ceiling_mesh.get_aabb()
					_check(is_equal_approx(bounds.position.x, ceiling_bounds.position.x), "Foundation and ceiling share left edge")
					_check(is_equal_approx(bounds.end.x, ceiling_bounds.end.x), "Foundation and ceiling share right edge")
					for patch: Node in foundation.get_parent().get_children():
						if patch is MeshInstance3D and patch != foundation:
							_check(not (patch as MeshInstance3D).visible, "Duplicate foundation patch hidden")
					for seed: String in ["Floor00", "Floor01", "Floor10", "Floor11"]:
						var floor_mesh: MeshInstance3D = room.get_node("Architecture/" + seed + "/Model/Ground_01")
						var stone: AABB = room.global_transform.affine_inverse() * floor_mesh.global_transform * floor_mesh.get_aabb()
						_check(stone.position.y > bounds.end.y + 0.0005, "Stone surface does not fight foundation")
					for fraction: float in [0.05, 0.5, 0.95]:
						for depth: float in [-3.0, 1.1, 3.0]:
							var x: float = lerpf(expected_left, expected_right, fraction)
							var ray := PhysicsRayQueryParameters3D.create(room.to_global(Vector3(x, 0.0005, depth)), room.to_global(Vector3(x, -0.2, depth)))
							_check(not room.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Continuous foundation collision under floor")
			var channel_ray := PhysicsRayQueryParameters3D.create(Vector3(0, count * 5.0, 1.1), Vector3(0, -2, 1.1))
			_check(layout.get_world_3d().direct_space_state.intersect_ray(channel_ray).is_empty(), "Central dragon channel stays open")
	layout.queue_free()
	await process_frame
	print("ROOM_FLOORS: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
