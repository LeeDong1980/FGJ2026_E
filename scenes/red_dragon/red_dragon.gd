class_name RedDragon
extends Node3D
## Owns instance-local animation resources. Move this node to change floors.

signal animation_started(animation_name: StringName)
signal animation_finished(animation_name: StringName)
signal animation_interrupted(animation_name: StringName)

const BASE_ANIMATIONS: Array[StringName] = [&"idle", &"fly"]
const RETURN_TO_BASE_ANIMATIONS: Array[StringName] = [&"atk", &"roar"]

@export var base_animation: StringName = &"idle"
@export_range(0.0, 2.0, 0.01) var blend_time: float = 0.2
@export var attack_in_place: bool = true
## Blends the final part of fly's arm3.R track back to its first rotation.
@export_range(0.05, 1.0, 0.01) var fly_loop_blend_time: float = 0.2

var _animation_player: AnimationPlayer
var _source_attack: Animation
var _active_animation: StringName = &""
var _unfinished: bool = false
var _holding_pose: bool = false
var _playback_serial: int = 0

@onready var _mouth_anchor: Marker3D = %MouthAnchor


func _ready() -> void:
	_animation_player = get_node_or_null("Model/AnimationPlayer") as AnimationPlayer
	if _animation_player == null:
		push_error("RedDragon requires Model/AnimationPlayer.")
		return
	_make_animations_local()
	_animation_player.animation_finished.connect(_on_animation_finished)
	if not BASE_ANIMATIONS.has(base_animation):
		push_warning("RedDragon base_animation must be idle or fly; using idle.")
		base_animation = &"idle"
	play_animation(base_animation)


## Returns false before ready or for an unavailable name. Explicit calls interrupt.
## use_original_attack_motion applies only to atk and overrides attack_in_place.
func play_animation(
	animation_name: StringName,
	restart: bool = false,
	use_original_attack_motion: bool = false
) -> bool:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return false
	if animation_name == _active_animation and not restart:
		if _animation_player.is_playing() or _holding_pose:
			return true
	var interrupted: StringName = _active_animation if _unfinished else &""
	_playback_serial += 1
	var serial: int = _playback_serial
	_unfinished = false
	if interrupted != &"":
		animation_interrupted.emit(interrupted)
	# An interruption handler may issue a newer request. Do not overwrite it.
	if serial != _playback_serial:
		return true
	_active_animation = animation_name
	_unfinished = true
	_holding_pose = false
	if animation_name == &"atk":
		_configure_attack_motion(attack_in_place and not use_original_attack_motion)
	# stop(true) clears playback time for a forced replay while preserving the
	# current pose for the transition. A normal switch uses AnimationPlayer blending.
	if restart and _animation_player.assigned_animation == animation_name:
		_animation_player.stop(true)
	_animation_player.play(animation_name, blend_time)
	animation_started.emit(animation_name)
	return true


## May be called before ready. During a one-shot/held pose it changes only the
## return target. During idle/fly it immediately switches the playing base.
func set_base_animation(animation_name: StringName) -> bool:
	if not BASE_ANIMATIONS.has(animation_name):
		return false
	base_animation = animation_name
	if _animation_player != null and _animation_player.is_playing():
		if not BASE_ANIMATIONS.has(_active_animation):
			return true
		return play_animation(animation_name)
	return true


## keep_pose=false applies the selected base animation's first pose, then stops.
## Stopping is an interruption, never a natural completion.
func stop_animation(keep_pose: bool = true) -> void:
	if _animation_player == null:
		return
	var interrupted: StringName = _active_animation if _unfinished else &""
	_playback_serial += 1
	_unfinished = false
	_holding_pose = false
	_animation_player.stop(true)
	if not keep_pose:
		_animation_player.play(base_animation, 0.0)
		_animation_player.advance(0.0)
		_animation_player.stop(true)
	_active_animation = &""
	if interrupted != &"":
		animation_interrupted.emit(interrupted)


func get_animation_names() -> PackedStringArray:
	if _animation_player == null:
		return PackedStringArray()
	return _animation_player.get_animation_list()


## Valid after ready. Local -Z points out of the mouth; transforms include all
## character/model scales. Attach effects here or read its global_transform.
func get_mouth_anchor() -> Marker3D:
	return _mouth_anchor


func _make_animations_local() -> void:
	for library_name: StringName in _animation_player.get_animation_library_list():
		var source: AnimationLibrary = _animation_player.get_animation_library(library_name)
		var local: AnimationLibrary = AnimationLibrary.new()
		for animation_name: StringName in source.get_animation_list():
			var original: Animation = source.get_animation(animation_name)
			var animation: Animation = original.duplicate(true) as Animation
			animation.loop_mode = (
				Animation.LOOP_LINEAR if BASE_ANIMATIONS.has(animation_name)
				else Animation.LOOP_NONE
			)
			if animation_name == &"atk":
				_source_attack = original
			elif animation_name == &"fly":
				_close_fly_loop(animation)
			local.add_animation(animation_name, animation)
		_animation_player.remove_animation_library(library_name)
		_animation_player.add_animation_library(library_name, local)


func _close_fly_loop(animation: Animation) -> void:
	for track: int in range(animation.get_track_count()):
		var path: NodePath = animation.track_get_path(track)
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		if path.get_subname_count() != 1 or path.get_subname(0) != &"arm3.R":
			continue
		if animation.track_get_key_count(track) < 2:
			continue
		var first: Quaternion = animation.track_get_key_value(track, 0)
		var last: Quaternion = animation.track_get_key_value(
			track, animation.track_get_key_count(track) - 1
		)
		if first.angle_to(last) < 0.001:
			continue
		var duration: float = minf(fly_loop_blend_time, animation.length)
		var start: float = animation.length - duration
		var start_rotation: Quaternion = animation.rotation_track_interpolate(track, start)
		for key: int in range(animation.track_get_key_count(track) - 1, -1, -1):
			if animation.track_get_key_time(track, key) >= start:
				animation.track_remove_key(track, key)
		# Six intervals within 0.2 seconds, eased to avoid a sudden correction.
		for step: int in range(7):
			var weight: float = float(step) / 6.0
			var eased_weight: float = weight * weight * (3.0 - 2.0 * weight)
			animation.rotation_track_insert_key(
				track, start + duration * weight, start_rotation.slerp(first, eased_weight)
			)


func _configure_attack_motion(in_place: bool) -> void:
	if _source_attack == null:
		return
	var attack: Animation = _animation_player.get_animation(&"atk")
	for track: int in range(_source_attack.get_track_count()):
		var path: NodePath = _source_attack.track_get_path(track)
		if _source_attack.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		if path.get_subname_count() != 1 or path.get_subname(0) != &"root":
			continue
		if _source_attack.track_get_key_count(track) == 0:
			continue
		var origin: Vector3 = _source_attack.track_get_key_value(track, 0)
		for key: int in range(_source_attack.track_get_key_count(track)):
			var position_value: Vector3 = _source_attack.track_get_key_value(track, key)
			if in_place:
				position_value.x = origin.x
				position_value.z = origin.z
			attack.track_set_key_value(track, key, position_value)


func _on_animation_finished(animation_name: StringName) -> void:
	if not _unfinished or animation_name != _active_animation:
		return
	var serial: int = _playback_serial
	_unfinished = false
	_holding_pose = true
	animation_finished.emit(animation_name)
	# A signal handler may explicitly play or stop another animation.
	if serial != _playback_serial:
		return
	if RETURN_TO_BASE_ANIMATIONS.has(animation_name):
		play_animation(base_animation)
