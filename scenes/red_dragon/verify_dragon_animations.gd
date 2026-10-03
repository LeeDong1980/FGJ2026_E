extends SceneTree
## Run against a copy of the project with --headless --script <this file>.

const DRAGON_SCENE: PackedScene = preload("res://scenes/red_dragon/red_dragon.tscn")
const MODEL_SCENE: PackedScene = preload("res://Models/dragon/Red_dragon.glb")
const EXPECTED_NAMES: Array[String] = [
	"atk", "fall", "fly", "idle", "pose", "pose2", "roar"
]

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var events: Array[String] = []
	var first: Node3D = DRAGON_SCENE.instantiate()
	_check(first.get_mouth_anchor() == null, "mouth getter is null before ready")
	_record_events(first, events)
	root.add_child(first)
	var player: AnimationPlayer = first.get_node("Model/AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	first.blend_time = 0.0
	_check(events == ["started:idle"], "standalone starts idle")
	_check(first.get_animation_names() == PackedStringArray(EXPECTED_NAMES), "all seven names exposed")
	var second: Node3D = DRAGON_SCENE.instantiate()
	_check(second.set_base_animation(&"fly"), "base can be configured before ready")
	root.add_child(second)
	var other_player: AnimationPlayer = second.get_node("Model/AnimationPlayer")
	other_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_check(other_player.current_animation == &"fly", "scene instance starts configured fly")
	var source: Node3D = MODEL_SCENE.instantiate()
	var source_player: AnimationPlayer = source.get_node("AnimationPlayer")
	_check(
		player.get_animation_library(&"") != other_player.get_animation_library(&""),
		"animation libraries are separate per instance"
	)
	for name: String in EXPECTED_NAMES:
		var clip: Animation = player.get_animation(name)
		_check(clip != other_player.get_animation(name), name + " instance isolation")
		_check(clip != source_player.get_animation(name), name + " source isolation")
		_check(source_player.get_animation(name).loop_mode == Animation.LOOP_NONE,
			name + " source loop unchanged")
		var loops: bool = name == "idle" or name == "fly"
		_check(clip.loop_mode == (Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE),
			name + " loop policy")
		first.play_animation(StringName(name), true)
		player.advance(0.0)
		events.clear()
		player.advance(clip.length * 3.0 + 0.1 if loops else clip.length + 0.1)
		if loops:
			_check(events.is_empty(), name + " loops without completion signal")
			_check(player.is_playing() and player.current_animation == name,
				name + " continues over three loops")
		else:
			_check(events.count("finished:" + name) == 1, name + " finishes once")
			if name == "atk" or name == "roar":
				_check(player.current_animation == &"idle", name + " returns to base")
				_check(events == ["finished:" + name, "started:idle"],
					name + " completion then base start without interruption")
			else:
				_check(not player.is_playing(), name + " holds final pose")
				var skeleton: Skeleton3D = first.get_node("Model/Armature/Skeleton3D")
				var final_pose: Transform3D = skeleton.get_bone_pose(skeleton.find_bone("root"))
				player.advance(1.0)
				_check(final_pose.is_equal_approx(skeleton.get_bone_pose(skeleton.find_bone("root"))),
					name + " final pose remains")
				events.clear()
				first.play_animation(StringName(name))
				_check(events.is_empty() and not player.is_playing(),
					name + " repeated call does not restart held pose")
				first.play_animation(StringName(name), true)
				_check(events == ["started:" + name] and player.is_playing(),
					name + " explicit restart resumes held pose")

	events.clear()
	var previous: StringName = player.current_animation
	_check(not first.play_animation(&"missing"), "unknown animation returns false")
	_check(not first.play_animation(&""), "empty animation returns false")
	_check(not first.set_base_animation(&"roar"), "one-shot cannot be selected as base")
	_check(events.is_empty() and player.current_animation == previous,
		"invalid requests leave state and signals unchanged")
	first.play_animation(&"idle", true)
	player.advance(0.5)
	events.clear()
	first.play_animation(&"idle")
	_check(is_equal_approx(player.current_animation_position, 0.5) and events.is_empty(),
		"same animation request does not reset time or emit signals")
	first.play_animation(&"idle", true)
	_check(is_zero_approx(player.current_animation_position), "forced replay resets time")
	_check(events == ["interrupted:idle", "started:idle"], "forced replay signal order")
	events.clear()
	first.play_animation(&"roar")
	_check(events == ["interrupted:idle", "started:roar"], "explicit switch signal order")
	player.advance(0.7)
	events.clear()
	first.set_base_animation(&"fly")
	_check(player.current_animation == &"roar" and events.is_empty(),
		"base change during action waits for completion")
	player.advance(player.get_animation(&"roar").length)
	_check(events == ["finished:roar", "started:fly"], "action returns to changed base")
	events.clear()
	first.set_base_animation(&"idle")
	_check(events == ["interrupted:fly", "started:idle"], "playing base switches immediately")

	player.advance(0.5)
	var skeleton: Skeleton3D = first.get_node("Model/Armature/Skeleton3D")
	var poses: Array[Transform3D] = []
	for bone: int in range(skeleton.get_bone_count()):
		poses.append(skeleton.get_bone_pose(bone))
	events.clear()
	first.stop_animation()
	_check(not player.is_playing() and events == ["interrupted:idle"], "stop interrupts only")
	var pose_preserved: bool = true
	for bone: int in range(skeleton.get_bone_count()):
		pose_preserved = pose_preserved and poses[bone].is_equal_approx(skeleton.get_bone_pose(bone))
	_check(pose_preserved, "stop retains every bone pose")
	events.clear()
	first.stop_animation()
	_check(events.is_empty(), "repeated stop has no duplicate interruption")
	first.play_animation(&"idle")
	_check(player.is_playing() and events == ["started:idle"], "play after stop works")
	first.stop_animation(false)
	_check(not player.is_playing(), "reset stop does not leave base running")
	var reference_skeleton: Skeleton3D = second.get_node("Model/Armature/Skeleton3D")
	second.play_animation(&"idle", true)
	other_player.play(&"idle", 0.0)
	other_player.advance(0.0)
	var base_pose_applied: bool = true
	for bone: int in range(skeleton.get_bone_count()):
		base_pose_applied = base_pose_applied and skeleton.get_bone_pose(bone).is_equal_approx(
			reference_skeleton.get_bone_pose(bone)
		)
	_check(base_pose_applied, "reset stop applies base first pose")

	_verify_motion(first, player, other_player, source_player)
	_verify_signal_handlers(first, player, events)
	_verify_blending(first, player, source_player)
	await _verify_mouth(first, second)
	source.free()
	first.free()
	second.free()
	print("RESULT checks=", _checks, " failures=", _failures)
	quit(0 if _failures == 0 else 1)


func _verify_motion(
	dragon: Node3D, player: AnimationPlayer, other: AnimationPlayer, source: AnimationPlayer
) -> void:
	var source_attack: Animation = source.get_animation(&"atk")
	var root_track: int = source_attack.find_track(
		NodePath("Armature/Skeleton3D:root"), Animation.TYPE_POSITION_3D
	)
	var origin: Vector3 = source_attack.track_get_key_value(root_track, 0)
	dragon.play_animation(&"atk", true)
	var attack: Animation = player.get_animation(&"atk")
	var clamped: bool = true
	var vertical_preserved: bool = true
	for key: int in range(attack.track_get_key_count(root_track)):
		var value: Vector3 = attack.track_get_key_value(root_track, key)
		var original: Vector3 = source_attack.track_get_key_value(root_track, key)
		clamped = clamped and is_equal_approx(value.x, origin.x) and is_equal_approx(value.z, origin.z)
		vertical_preserved = vertical_preserved and is_equal_approx(value.y, original.y)
	_check(clamped, "default atk clamps horizontal root movement")
	_check(vertical_preserved, "in-place atk preserves vertical movement")
	var last_key: int = source_attack.track_get_key_count(root_track) - 1
	_check(other.get_animation(&"atk").track_get_key_value(root_track, last_key)
		== source_attack.track_get_key_value(root_track, last_key),
		"changing atk does not alter another instance or source")
	dragon.play_animation(&"atk", true, true)
	_check(attack.track_get_key_value(root_track, last_key)
		== source_attack.track_get_key_value(root_track, last_key), "per-call original atk motion")
	dragon.attack_in_place = false
	dragon.play_animation(&"atk", true)
	_check(attack.track_get_key_value(root_track, last_key)
		== source_attack.track_get_key_value(root_track, last_key), "export original atk motion")
	dragon.attack_in_place = true
	dragon.play_animation(&"atk", true)
	var restored: Vector3 = attack.track_get_key_value(root_track, last_key)
	_check(is_equal_approx(restored.z, origin.z), "returning to in-place restores clamp")
	var fly: Animation = player.get_animation(&"fly")
	var arm_track: int = fly.find_track(NodePath("Armature/Skeleton3D:arm3.R"), Animation.TYPE_ROTATION_3D)
	var first: Quaternion = fly.track_get_key_value(arm_track, 0)
	var last: Quaternion = fly.track_get_key_value(arm_track, fly.track_get_key_count(arm_track) - 1)
	_check(first.angle_to(last) < 0.001, "corrected fly arm loop closes")
	var source_fly: Animation = source.get_animation(&"fly")
	var original_first: Quaternion = source_fly.track_get_key_value(arm_track, 0)
	var original_last: Quaternion = source_fly.track_get_key_value(
		arm_track, source_fly.track_get_key_count(arm_track) - 1
	)
	_check(rad_to_deg(original_first.angle_to(original_last)) > 30.0,
		"fly source retains original seam")
	var start: float = fly.length - dragon.fly_loop_blend_time
	_check(fly.rotation_track_interpolate(arm_track, start).angle_to(
		source_fly.rotation_track_interpolate(arm_track, start)) < 0.001,
		"fly correction joins original curve without a jump")
	var fall: Animation = player.get_animation(&"fall")
	var source_fall: Animation = source.get_animation(&"fall")
	var fall_unchanged: bool = true
	for key: int in range(fall.track_get_key_count(root_track)):
		fall_unchanged = (
			fall_unchanged and fall.track_get_key_value(root_track, key)
			== source_fall.track_get_key_value(root_track, key)
		)
	_check(fall_unchanged, "fall retains original vertical root movement")


func _verify_signal_handlers(dragon: Node3D, player: AnimationPlayer, events: Array[String]) -> void:
	dragon.play_animation(&"roar", true)
	dragon.animation_finished.connect(func(_name: StringName) -> void:
		dragon.play_animation(&"pose2"), CONNECT_ONE_SHOT)
	events.clear()
	player.advance(player.get_animation(&"roar").length + 0.1)
	_check(events == ["finished:roar", "started:pose2"] and player.current_animation == &"pose2",
		"completion handler request overrides automatic base return")
	dragon.animation_interrupted.connect(func(_name: StringName) -> void:
		dragon.play_animation(&"fall"), CONNECT_ONE_SHOT)
	events.clear()
	dragon.play_animation(&"atk")
	_check(events == ["interrupted:pose2", "started:fall"] and player.current_animation == &"fall",
		"interruption handler request wins without duplicate signals")


func _verify_blending(dragon: Node3D, player: AnimationPlayer, source: AnimationPlayer) -> void:
	dragon.blend_time = 0.2
	dragon.play_animation(&"idle", true)
	player.advance(0.4)
	dragon.play_animation(&"fly")
	player.advance(0.1)
	var skeleton: Skeleton3D = dragon.get_node("Model/Armature/Skeleton3D")
	var bone: int = skeleton.find_bone("root")
	var actual: Vector3 = skeleton.get_bone_pose_position(bone)
	var fly: Animation = source.get_animation(&"fly")
	var track: int = fly.find_track(NodePath("Armature/Skeleton3D:root"), Animation.TYPE_POSITION_3D)
	var target: Vector3 = fly.position_track_interpolate(track, 0.1)
	_check(actual.distance_to(target) > 0.001, "0.2-second transition blends instead of cutting")
	player.advance(0.2)
	target = fly.position_track_interpolate(track, 0.3)
	actual = skeleton.get_bone_pose_position(bone)
	_check(actual.distance_to(target) < 0.001, "transition reaches target after blend duration")


func _record_events(dragon: Node, events: Array[String]) -> void:
	dragon.animation_started.connect(func(name: StringName) -> void: events.append("started:" + name))
	dragon.animation_finished.connect(func(name: StringName) -> void: events.append("finished:" + name))
	dragon.animation_interrupted.connect(func(name: StringName) -> void: events.append("interrupted:" + name))


func _verify_mouth(dragon: Node3D, other: Node3D) -> void:
	var anchor: Marker3D = dragon.get_mouth_anchor()
	var attachment: BoneAttachment3D = anchor.get_parent() as BoneAttachment3D
	var skeleton: Skeleton3D = dragon.get_node("Model/Armature/Skeleton3D")
	var head: int = skeleton.find_bone("head2")
	_check(anchor == dragon.get_node("%MouthAnchor"), "mouth getter exposes scene-owned unique marker")
	_check(attachment != null and attachment.get_parent() == skeleton,
		"mouth attachment is a Skeleton3D child")
	_check(attachment.get_skeleton() == skeleton and attachment.bone_name == "head2"
		and attachment.bone_idx == head, "mouth attachment binds measured upper-jaw bone")
	_check(not attachment.override_pose, "mouth attachment does not override skeleton animation")
	_check(anchor != other.get_mouth_anchor(), "mouth anchors are separate per instance")
	var mesh: MeshInstance3D = skeleton.get_node("mesh")
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skin: Skin = mesh.skin
	# Vertex 3122 is the upper-lip center, checked against the actual GPU mesh.
	var lip_vertex: int = 3122
	var head_binding: int = -1
	for binding: int in range(skin.get_bind_count()):
		if skin.get_bind_name(binding) == &"head2":
			head_binding = binding
	var head_weight: float = 0.0
	for influence: int in range(4):
		if bones[lip_vertex * 4 + influence] == head_binding:
			head_weight += weights[lip_vertex * 4 + influence]
	_check(is_equal_approx(head_weight, 1.0), "lip reference is fully weighted to head2")
	var lip_local: Vector3 = skin.get_bind_pose(head_binding) * vertices[lip_vertex]
	var clearance: Vector3 = Vector3(0.0, 0.2, -0.2)
	_check(anchor.position.distance_to(lip_local + clearance) < 0.00001,
		"mouth offset derives from lip vertex plus measured exit clearance")
	await process_frame
	await process_frame
	var other_anchor: Marker3D = other.get_mouth_anchor()
	var other_transform: Transform3D = other_anchor.global_transform
	var original_transform: Transform3D = dragon.transform
	var original_blend_time: float = dragon.blend_time
	# Pose sampling must not retain a zero-progress transition from the blend test.
	dragon.blend_time = 0.0
	var player: AnimationPlayer = dragon.get_node("Model/AnimationPlayer")
	var fractions: Array[float] = [0.0, 0.25, 0.5, 0.75, 0.999]
	for root_scale: float in [1.0, 2.0, 5.0]:
		dragon.position = Vector3(0.0, 6.4, -16.019)
		dragon.rotation_degrees = Vector3(13.0, 90.0, 7.0)
		dragon.scale = Vector3.ONE * root_scale
		for name: String in EXPECTED_NAMES:
			dragon.play_animation(StringName(name), true)
			player.advance(0.0)
			var clip: Animation = player.get_animation(name)
			var follows_bone: bool = true
			var follows_lip: bool = true
			var faces_outward: bool = true
			var first_position: Vector3 = Vector3.ZERO
			var movement: float = 0.0
			var maximum_error: float = 0.0
			for index: int in range(fractions.size()):
				player.seek(clip.length * fractions[index], true)
				# Exercise BoneAttachment3D's normal frame update, not a manual copy.
				await process_frame
				await process_frame
				var head_world: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(head)
				var expected: Transform3D = head_world * anchor.transform
				maximum_error = maxf(maximum_error, expected.origin.distance_to(anchor.global_position))
				follows_bone = follows_bone and anchor.global_transform.is_equal_approx(expected)
				# CPU skinning of a real mesh vertex validates anatomical registration.
				var lip_world: Vector3 = head_world * lip_local
				follows_lip = follows_lip and anchor.global_position.distance_to(lip_world) < 0.016 * root_scale
				var forward: Vector3 = -anchor.global_basis.z.normalized()
				faces_outward = faces_outward and forward.dot(head_world.basis.y.normalized()) > 0.9999
				if index == 0:
					first_position = anchor.global_position
				movement = maxf(movement, first_position.distance_to(anchor.global_position))
			var label: String = "%s root_scale=%s" % [name, root_scale]
			_check(follows_bone, label + " mouth follows animated bone and rotated/translated root")
			_check(follows_lip, label + " mouth stays within upper-lip exit clearance")
			_check(faces_outward, label + " local -Z faces out along upper jaw")
			if name != "pose" and name != "pose2":
				_check(movement > 0.0001, label + " mouth actually moves with animation")
			print("MOUTH_SAMPLE ", label, " maximum_tracking_error=", maximum_error)
		_check(anchor.global_basis.get_scale().is_equal_approx(Vector3.ONE * 0.05 * root_scale),
			"mouth inherits model and root scale " + str(root_scale))
	_check(other_anchor.global_transform.is_equal_approx(other_transform),
		"animating and transforming one mouth does not move the other instance")
	dragon.stop_animation()
	var held: Transform3D = anchor.global_transform
	await process_frame
	await process_frame
	_check(anchor.global_transform.is_equal_approx(held), "mouth remains aligned after stop with held pose")
	dragon.transform = original_transform
	dragon.blend_time = original_blend_time


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL " + label)
	else:
		print("PASS ", label)
