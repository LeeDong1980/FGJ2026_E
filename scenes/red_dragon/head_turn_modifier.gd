extends SkeletonModifier3D
## Adds model-space yaw after animation playback. Skeleton3D restores the input
## poses between updates, so this never feeds yesterday's offset back into today.

const BONE_NAMES: Array[StringName] = [&"neck1", &"neck2", &"head1"]
const BONE_WEIGHTS: Array[float] = [0.35, 0.4, 0.25]

var target_turn: float = 0.5
var current_turn: float = 0.5
var turn_speed: float = 2.0
var max_yaw_degrees: float = 90.0
var _bones: Array[int] = []


func _ready() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	for bone_name: StringName in BONE_NAMES:
		var bone: int = skeleton.find_bone(bone_name)
		if bone < 0:
			push_error("RedDragon head turn requires bone: " + str(bone_name))
			active = false
			return
		_bones.append(bone)


func set_target(value: float, immediate: bool) -> void:
	target_turn = value
	if immediate:
		current_turn = value


func _process_modification_with_delta(delta: float) -> void:
	if _bones.size() != BONE_NAMES.size():
		return
	current_turn = move_toward(current_turn, target_turn, turn_speed * maxf(delta, 0.0))
	var yaw: float = deg_to_rad(max_yaw_degrees) * (current_turn * 2.0 - 1.0)
	# Also submit the identity offset. A stopped/static base must publish its
	# neutral pose to skin and attachments when the previous yaw is removed.
	var skeleton: Skeleton3D = get_skeleton()
	for index: int in range(_bones.size()):
		var bone: int = _bones[index]
		var parent: int = skeleton.get_bone_parent(bone)
		var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis
		# All three joints turn around the same model-space up axis, not around
		# whichever local axis happens to point upward in the imported rest pose.
		var local_axis: Vector3 = (parent_basis.inverse() * Vector3.UP).normalized()
		var extra: Quaternion = Quaternion(local_axis, yaw * BONE_WEIGHTS[index])
		skeleton.set_bone_pose_rotation(bone, extra * skeleton.get_bone_pose_rotation(bone))
