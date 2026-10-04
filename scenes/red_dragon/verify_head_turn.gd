extends SceneTree
## Runs in an imported standalone project copy. Inspect HEAD_TURN_RESULT.

const DRAGON: PackedScene = preload("res://scenes/red_dragon/red_dragon.tscn")
const NAMES: Array[StringName] = [&"idle", &"fly", &"atk", &"roar", &"fall", &"pose", &"pose2"]
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var dragon: Node3D = DRAGON.instantiate()
	_check(dragon.set_head_turn(0.0, true), "head turn accepts before ready")
	_check(is_zero_approx(dragon.get_current_head_turn()), "pre-ready value retained")
	root.add_child(dragon)
	var other: Node3D = DRAGON.instantiate()
	root.add_child(other)
	var player: AnimationPlayer = dragon.get_node("Model/AnimationPlayer")
	var other_player: AnimationPlayer = other.get_node("Model/AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	other_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	dragon.blend_time = 0.0
	var skeleton: Skeleton3D = dragon.get_node("Model/Armature/Skeleton3D")
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var record: Dictionary = {}
	skeleton.skeleton_updated.connect(_observe.bind(dragon, record))
	var events: Array[String] = []
	dragon.animation_started.connect(func(name: StringName) -> void: events.append("start:" + str(name)))
	dragon.animation_finished.connect(func(name: StringName) -> void: events.append("finish:" + str(name)))
	dragon.animation_interrupted.connect(func(name: StringName) -> void: events.append("interrupt:" + str(name)))
	_check(not dragon.set_head_turn(NAN) and not dragon.set_head_turn(INF), "nonfinite input rejected")
	dragon.set_head_turn(-2.0, true)
	_check(is_zero_approx(dragon.get_head_turn()), "low values clamp to left")
	dragon.set_head_turn(2.0, true)
	_check(is_equal_approx(dragon.get_head_turn(), 1.0), "high values clamp to right")
	var model: Node3D = dragon.get_node("Model")
	var mesh: MeshInstance3D = skeleton.get_node("mesh")
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lip_local: Vector3 = Vector3.ZERO
	for binding: int in range(mesh.skin.get_bind_count()):
		if mesh.skin.get_bind_name(binding) == &"head2":
			lip_local = mesh.skin.get_bind_pose(binding) * vertices[3122]
	var model_transform: Transform3D = model.transform
	var armature_transform: Transform3D = model.get_node("Armature").transform
	for multiplier: float in [1.0, 5.0]:
		dragon.position = Vector3(0, 6.4, -16.018951)
		dragon.scale = Vector3.ONE * multiplier
		for rotation: Vector3 in [Vector3.ZERO, Vector3(13, 37, 7)]:
			dragon.rotation_degrees = rotation
			var root_transform: Transform3D = dragon.transform
			for name: StringName in NAMES:
				dragon.play_animation(name, true)
				player.advance(0.0)
				for fraction: float in [0.0, 0.5, 0.999]:
					player.seek(player.get_animation(name).length * fraction, true)
					dragon.set_head_turn(0.5, true)
					await _sample(skeleton, 0.0)
					var baseline: Array = record["poses"].duplicate()
					var head_base: Transform3D = record["head_model"]
					for value: float in [0.0, 0.5, 1.0]:
						events.clear()
						dragon.set_head_turn(value, true)
						await _sample(skeleton, 0.0)
						var label: String = "%s t=%s turn=%s scale=%s rotation=%s" % [name, fraction, value, multiplier, rotation]
						var expected_basis: Basis = Basis(Vector3.UP, (value * 2.0 - 1.0) * PI / 2.0) * head_base.basis
						var actual_head: Transform3D = record["head_model"]
						_check(actual_head.basis.is_equal_approx(expected_basis), label + " additive head rotation")
						_check(record["expected_anchor"].is_equal_approx(dragon.get_mouth_anchor().global_transform), label + " mouth follows final modified pose")
						var lip_world: Vector3 = skeleton.global_transform * actual_head * lip_local
						_check(lip_world.distance_to(dragon.get_mouth_anchor().global_position) < 0.016 * multiplier, label + " mouth remains at real skinned lip")
						var localized: bool = true
						var poses: Array = record["poses"]
						for bone: int in range(skeleton.get_bone_count()):
							var before: Transform3D = baseline[bone]
							var after: Transform3D = poses[bone]
							localized = localized and before.origin.is_equal_approx(after.origin)
							localized = localized and before.basis.get_scale().is_equal_approx(after.basis.get_scale())
							if not [&"neck1", &"neck2", &"head1"].has(skeleton.get_bone_name(bone)):
								localized = localized and before.basis.is_equal_approx(after.basis)
						_check(localized, label + " only three local rotations changed")
						_check(dragon.transform.is_equal_approx(root_transform) and model.transform.is_equal_approx(model_transform) and model.get_node("Armature").transform.is_equal_approx(armature_transform), label + " root/model/armature preserved")
						_check(events.is_empty(), label + " head control emits no animation events")
						_check(is_equal_approx(other.get_current_head_turn(), 0.5), label + " second instance unaffected")
	# Actual mouth -Z, not a guessed local quaternion sign, determines left/right.
	dragon.transform = Transform3D.IDENTITY
	for name: StringName in [&"idle", &"fly"]:
		dragon.play_animation(name, true)
		player.advance(0.0)
		player.seek(2.0, true)
		for value: float in [0.0, 0.5, 1.0]:
			dragon.set_head_turn(value, true)
			await _sample(skeleton, 0.0)
			var forward: Vector3 = -dragon.get_mouth_anchor().global_basis.z.normalized()
			_check(forward.x < -0.5 if value == 0.0 else (forward.x > 0.5 if value == 1.0 else forward.z > 0.5), str(name) + " actual mouth endpoint direction " + str(value))
			print("HEAD_DIRECTION clip=", name, " turn=", value, " outward=", forward)
	dragon.set_head_turn(0.5, true)
	dragon.set_head_turn(1.0)
	await _sample(skeleton, 0.1)
	_check(is_equal_approx(dragon.get_current_head_turn(), 0.7), "manual 0.1s advances parameter by 0.2")
	dragon.stop_animation(true)
	await _sample(skeleton, 0.0)
	var held: Transform3D = dragon.get_mouth_anchor().global_transform
	await _sample(skeleton, 1.0)
	_check(is_equal_approx(dragon.get_current_head_turn(), 0.7) and dragon.get_mouth_anchor().global_transform.is_equal_approx(held), "stop true freezes base and current turn")
	for frame: int in range(20):
		await _sample(skeleton, 0.0)
	_check(dragon.get_mouth_anchor().global_transform.is_equal_approx(held), "stopped repeated updates do not accumulate yaw")
	dragon.set_head_turn(0.0, true)
	await _sample(skeleton, 0.0)
	_check(not dragon.get_mouth_anchor().global_transform.is_equal_approx(held) and not player.is_playing(), "explicit head control works on stopped base")
	dragon.stop_animation(false)
	await _sample(skeleton, 0.0)
	_check(is_equal_approx(dragon.get_current_head_turn(), 0.5), "stop false resets neutral")
	dragon.set_base_animation(&"fly")
	dragon.set_head_turn(1.0, true)
	for action: StringName in [&"atk", &"roar"]:
		dragon.play_animation(action, true)
		player.advance(0.0)
		events.clear()
		player.advance(player.get_animation(action).length + 0.1)
		await _sample(skeleton, 0.0)
		_check(events == ["finish:" + str(action), "start:fly"] and player.current_animation == &"fly", str(action) + " one-shot returns to base with same signal order")
		_check(is_equal_approx(dragon.get_current_head_turn(), 1.0), str(action) + " return preserves head turn")
	# Run both mixers together: the animated input pose is restored after each
	# skeleton pass, so read the baseline before the next deferred modifier pass.
	dragon.blend_time = 0.2
	for clip: StringName in [&"idle", &"fly", &"atk", &"roar"]:
		dragon.play_animation(clip, true)
		dragon.set_head_turn(0.0 if clip == &"idle" or clip == &"atk" else 1.0)
		for frame: int in range(15):
			player.advance(1.0 / 60.0)
			var animated: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("head2"))
			await _sample(skeleton, 1.0 / 60.0)
			var yaw: float = (dragon.get_current_head_turn() * 2.0 - 1.0) * PI / 2.0
			var final_head: Transform3D = record["head_model"]
			_check(final_head.basis.is_equal_approx(Basis(Vector3.UP, yaw) * animated.basis), str(clip) + " blend plus moving head turn frame " + str(frame))
			_check(record["expected_anchor"].is_equal_approx(dragon.get_mouth_anchor().global_transform), str(clip) + " blend mouth tracking frame " + str(frame))
	# Runtime limit changes apply without mutating clips or root transforms.
	dragon.head_turn_max_angle_degrees = 0.0
	await _sample(skeleton, 0.0)
	var limited: Transform3D = record["head_model"]
	dragon.set_head_turn(0.5, true)
	await _sample(skeleton, 0.0)
	_check(limited.is_equal_approx(record["head_model"]), "zero angle disables additive offset")
	dragon.free()
	other.free()
	_verify_preview_controls()
	print("HEAD_TURN_RESULT checks=", _checks, " failures=", _failures)
	quit(0 if _failures == 0 else 1)


func _sample(skeleton: Skeleton3D, delta: float) -> void:
	skeleton.advance(delta)
	await process_frame
	await process_frame


func _verify_preview_controls() -> void:
	var preview: Node3D = load("res://scenes/red_dragon/head_turn_preview.tscn").instantiate()
	root.add_child(preview)
	var dragon: Node3D = preview.get_node("RedDragon")
	var player: AnimationPlayer = dragon.get_node("Model/AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var controls: Array[Node] = preview.find_children("*", "BaseButton", true, false)
	for control: Node in controls:
		if control is CheckButton and control.text == "立即":
			control.button_pressed = true
	for index: int in range(3):
		for control: Node in controls:
			if control is Button and control.text == ["左", "正前", "右"][index]:
				control.pressed.emit()
		_check(is_equal_approx(dragon.get_current_head_turn(), index * 0.5), "preview endpoint button " + str(index))
	var slider: HSlider = preview.find_children("*", "HSlider", true, false)[0]
	slider.value = 0.25
	_check(is_equal_approx(dragon.get_current_head_turn(), 0.25), "preview slider drives immediate control")
	var clips: OptionButton = preview.find_children("*", "OptionButton", true, false)[0]
	_check(clips.item_count == 7, "preview offers all seven animations")
	for index: int in range(clips.item_count):
		clips.select(index)
		clips.item_selected.emit(index)
		_check(player.assigned_animation == clips.get_item_text(index), "preview clip selection " + clips.get_item_text(index))
	player.advance(0.5)
	for control: Node in controls:
		if control is Button and control.text == "重播":
			control.pressed.emit()
	_check(is_zero_approx(player.current_animation_position), "preview replays selected animation")
	for control: Node in controls:
		if control is Button and control.text == "停止保留姿勢":
			control.pressed.emit()
	_check(not player.is_playing(), "preview stop hold stops base")
	for control: Node in controls:
		if control is Button and control.text == "停止回中立":
			control.pressed.emit()
	_check(not player.is_playing() and is_equal_approx(dragon.get_current_head_turn(), 0.5), "preview stop neutral resets head")
	preview.free()


func _observe(dragon: Node3D, record: Dictionary) -> void:
	var skeleton: Skeleton3D = dragon.get_node("Model/Armature/Skeleton3D")
	var poses: Array[Transform3D] = []
	for bone: int in range(skeleton.get_bone_count()):
		poses.append(skeleton.get_bone_pose(bone))
	var head: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("head2"))
	record["poses"] = poses
	record["head_model"] = head
	record["expected_anchor"] = skeleton.global_transform * head * dragon.get_mouth_anchor().transform


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + label)
