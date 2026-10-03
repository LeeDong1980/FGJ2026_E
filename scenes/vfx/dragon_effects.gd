class_name DragonEffects
extends Node3D
## Uses get_mouth_anchor() without depending on imported Skeleton3D paths.

signal effect_started(effect_name: StringName)
signal effect_finished(effect_name: StringName)
signal effect_interrupted(effect_name: StringName)

@export_node_path("Node3D") var dragon_path: NodePath
@export_range(0.05, 10.0, 0.05) var default_duration: float = 0.6
@export_range(0.1, 20.0, 0.1) var effect_range: float = 6.0
@export_range(0.01, 1.5, 0.01) var radius: float = 0.35
@export_range(8, 512, 1) var particle_count: int = 96

var last_error: String = ""
var _dragon: Node3D
var _active_effect: DirectedDragonEffect
var _active_name: StringName = &""
var _target: Vector3
var _visual_end: Vector3
var _remaining: float = 0.0
var _tail_remaining: float = 0.0
var _draining: bool = false
var _request_serial: int = 0

@onready var _suction: DirectedDragonEffect = %SuctionEffect
@onready var _fire: DirectedDragonEffect = %FireBreathEffect


func _ready() -> void:
	process_priority = 50
	if not dragon_path.is_empty():
		bind_dragon(get_node_or_null(dragon_path) as Node3D)


func bind_dragon(dragon: Node3D) -> bool:
	_request_serial += 1
	var serial: int = _request_serial
	_cancel_current()
	if serial != _request_serial:
		return false
	_dragon = dragon
	return _get_mouth_anchor() != null


func play_suction(target_global_position: Vector3, duration: float = 0.6) -> bool:
	return _play(&"suction", target_global_position, duration)


func play_fire(target_global_position: Vector3, duration: float = 0.6) -> bool:
	return _play(&"fire", target_global_position, duration)


func stop_effects() -> void:
	_request_serial += 1
	_cancel_current()


func set_target_global_position(target_global_position: Vector3) -> void:
	if not target_global_position.is_finite():
		last_error = "Target must contain finite world coordinates."
		return
	_target = target_global_position
	if _active_effect != null:
		_update_endpoints()


func get_active_effect() -> StringName:
	return _active_name


func get_visual_end_global_position() -> Vector3:
	return _visual_end


func _play(effect_name: StringName, target: Vector3, duration: float) -> bool:
	last_error = ""
	if not is_node_ready():
		last_error = "DragonEffects must be ready before playback."
		return false
	if not target.is_finite() or not is_finite(duration) or duration <= 0.0:
		last_error = "Target must be finite and duration must be positive."
		return false
	if not is_finite(effect_range) or effect_range <= 0.0 or not is_finite(radius) or radius <= 0.0:
		last_error = "Effect range and radius must be positive and finite."
		return false
	var anchor: Marker3D = _get_mouth_anchor()
	if anchor == null:
		return false
	if anchor.global_position.distance_squared_to(target) < 0.0001:
		last_error = "Target is too close to the mouth to define a direction."
		return false
	_request_serial += 1
	var serial: int = _request_serial
	_cancel_current()
	if serial != _request_serial:
		return true
	_target = target
	_active_effect = _suction if effect_name == &"suction" else _fire
	_active_name = effect_name
	_remaining = duration
	_draining = false
	_active_effect.radius = radius
	_active_effect.particle_count = clampi(particle_count, 8, 512)
	_update_endpoints()
	if _active_effect == null:
		return false
	_active_effect.begin(anchor.global_position, _visual_end)
	effect_started.emit(effect_name)
	return true


func _get_mouth_anchor() -> Marker3D:
	if not is_instance_valid(_dragon) or not _dragon.has_method(&"get_mouth_anchor"):
		last_error = "Bind a dragon that provides get_mouth_anchor() -> Marker3D."
		return null
	var candidate: Variant = _dragon.call(&"get_mouth_anchor")
	if typeof(candidate) != TYPE_OBJECT or not is_instance_valid(candidate):
		last_error = "The dragon's mouth anchor is unavailable."
		return null
	var anchor: Marker3D = candidate as Marker3D
	if anchor == null or not anchor.is_inside_tree() or not anchor.global_position.is_finite():
		last_error = "The dragon's mouth anchor is unavailable."
		return null
	return anchor


func _update_endpoints() -> void:
	var anchor: Marker3D = _get_mouth_anchor()
	if anchor == null:
		stop_effects()
		return
	var offset: Vector3 = _target - anchor.global_position
	if offset.length_squared() < 0.0001:
		last_error = "Target is too close to the mouth to define a direction."
		stop_effects()
		return
	_visual_end = anchor.global_position + offset.limit_length(effect_range)
	_active_effect.set_endpoints(anchor.global_position, _visual_end)


func _process(delta: float) -> void:
	if _active_effect == null:
		return
	_update_endpoints()
	if _active_effect == null:
		return
	# BoneAttachment3D can update after the animation process callback.
	# Refresh once more after deferred skeleton updates, before drawing.
	_refresh_endpoints.call_deferred()
	if not _draining:
		_remaining -= delta
		if _remaining <= 0.0:
			_active_effect.end_emission()
			_tail_remaining = _active_effect.get_tail_duration()
			_draining = true
	else:
		_tail_remaining -= delta
		if _tail_remaining <= 0.0:
			var finished_name: StringName = _active_name
			_clear_state()
			effect_finished.emit(finished_name)


func _refresh_endpoints() -> void:
	if _active_effect != null:
		_update_endpoints()


func _cancel_current() -> void:
	var interrupted_name: StringName = _active_name
	_clear_state()
	if interrupted_name != &"":
		effect_interrupted.emit(interrupted_name)


func _clear_state() -> void:
	if _active_effect != null:
		_active_effect.clear()
	_active_effect = null
	_active_name = &""
	_remaining = 0.0
	_tail_remaining = 0.0
	_draining = false
