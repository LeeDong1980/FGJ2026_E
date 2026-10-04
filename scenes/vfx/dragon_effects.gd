class_name DragonEffects
extends Node3D
## Uses get_mouth_anchor() without depending on imported Skeleton3D paths.

signal effect_started(effect_name: StringName)
signal effect_finished(effect_name: StringName)
signal effect_interrupted(effect_name: StringName)
signal spit_started(shot_id: int)
signal spit_finished(shot_id: int)
signal spit_interrupted(shot_id: int)

const MIN_EFFECT_WIDTH: float = 0.1
const MAX_EFFECT_WIDTH: float = 8.0
const MIN_LEGACY_RADIUS: float = 0.01
## Ice breath shares the fire width. Created in code so dragon_effects.tscn stays unchanged.
const ICE_BREATH_SCENE: PackedScene = preload("res://scenes/vfx/ice_breath_effect.tscn")
const SPIT_SCENE: PackedScene = preload("res://scenes/vfx/spit_projectile.tscn")
const MAX_SPIT_SHOTS: int = 8

var _suction_width: float = 4.0
var _fire_width: float = 3.0
var _fire_particle_count: int = 384

@export_node_path("Node3D") var dragon_path: NodePath
@export_range(0.05, 10.0, 0.05) var default_duration: float = 0.6
@export_range(0.1, 20.0, 0.1) var effect_range: float = 6.0
@export_range(8, 512, 1) var particle_count: int = 192

@export_group("Fire Density")
## Main flame particles only. Zero inherits the legacy shared particle_count.
@export_range(0, 512, 1) var fire_particle_count: int = 384:
	get:
		return _fire_particle_count
	set(value):
		set_fire_particle_count(value)

@export_group("Effect Widths")
## Diameter at the widest cross-section, in world units. Does not change range.
@export_range(0.1, 8.0, 0.1) var suction_width: float = 4.0:
	get:
		return _suction_width
	set(value):
		if not _is_valid_width(value):
			return
		_suction_width = clampf(value, MIN_EFFECT_WIDTH, MAX_EFFECT_WIDTH)
		_apply_active_width()
@export_range(0.1, 8.0, 0.1) var fire_width: float = 3.0:
	get:
		return _fire_width
	set(value):
		if not _is_valid_width(value):
			return
		_fire_width = clampf(value, MIN_EFFECT_WIDTH, MAX_EFFECT_WIDTH)
		_apply_active_width()

## Compatibility: read suction radius; writing sets both widths to radius * 2.
## Old positive radii down to 0.01 remain valid, including widths below 0.1.
## Kept as a script property, not serialized by new scenes: a derived radius
## must not overwrite independent widths when a PackedScene is saved/reloaded.
var radius: float:
	get:
		return _suction_width * 0.5
	set(value):
		if not _is_valid_width(value):
			return
		var legacy_radius: float = clampf(value, MIN_LEGACY_RADIUS, MAX_EFFECT_WIDTH * 0.5)
		_suction_width = legacy_radius * 2.0
		_fire_width = legacy_radius * 2.0
		_apply_active_width()

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
var _spit_serial: int = 0
var _spits: Dictionary[int, SpitProjectile] = {}

@onready var _suction: DirectedDragonEffect = %SuctionEffect
@onready var _fire: DirectedDragonEffect = %FireBreathEffect
var _ice: DirectedDragonEffect


func _ready() -> void:
	process_priority = 50
	_ice = ICE_BREATH_SCENE.instantiate() as DirectedDragonEffect
	add_child(_ice)
	if not dragon_path.is_empty():
		bind_dragon(get_node_or_null(dragon_path) as Node3D)


func bind_dragon(dragon: Node3D) -> bool:
	_request_serial += 1
	var serial: int = _request_serial
	_cancel_all()
	if serial != _request_serial:
		return false
	_dragon = dragon
	return _get_mouth_anchor() != null


func play_suction(target_global_position: Vector3, duration: float = 0.6) -> bool:
	return _play(&"suction", target_global_position, duration)


func play_fire(target_global_position: Vector3, duration: float = 0.6) -> bool:
	return _play(&"fire", target_global_position, duration)


## Same shape and width as fire, in ice colors.
func play_ice(target_global_position: Vector3, duration: float = 0.6) -> bool:
	return _play(&"ice", target_global_position, duration)


func stop_effects() -> void:
	_request_serial += 1
	_cancel_all()


## For releasing a held fire input without cancelling food already in flight.
func stop_breath_effects() -> void:
	_request_serial += 1
	_cancel_current()


## Returns an instance ID; -1 rejects without affecting other visuals.
## Positions are captured at launch; range/width settings do not truncate spit.
func play_spit(target: Vector3, payload: PackedScene, duration: float = 0.6, arc_height: float = 1.2, payload_type: int = -1) -> int:
	last_error = ""
	if not is_node_ready() or payload == null or not target.is_finite() or not is_finite(duration) or duration <= 0.0 or not is_finite(arc_height) or arc_height < 0.0:
		last_error = "Spit needs a ready controller, payload, finite target, positive duration and nonnegative arc height."
		return -1
	var anchor: Marker3D = _get_mouth_anchor()
	if anchor == null:
		return -1
	if _spits.size() >= MAX_SPIT_SHOTS or anchor.global_position.distance_squared_to(target) < 0.0001:
		last_error = "Spit capacity reached or target is too close to mouth."
		return -1
	var node: Node = payload.instantiate()
	var visual: Node3D = node as Node3D
	if visual == null or (payload_type != -1 and (not visual is IngredientModel or not IngredientType.NAMES.has(payload_type))):
		node.free()
		last_error = "Spit payload must be Node3D; optional type requires the existing IngredientModel and a valid ingredient type."
		return -1
	var source: Vector3 = anchor.global_position
	var shot: SpitProjectile = SPIT_SCENE.instantiate() as SpitProjectile
	_spit_serial += 1
	var shot_id: int = _spit_serial
	_spits[shot_id] = shot
	add_child(shot)
	shot.launch(source, target, visual, duration, arc_height)
	if payload_type != -1:
		(visual as IngredientModel).setup(payload_type)
	shot.completed.connect(_on_spit_completed.bind(shot_id), CONNECT_ONE_SHOT)
	spit_started.emit(shot_id)
	return shot_id


func get_active_spit_count() -> int:
	return _spits.size()


func _on_spit_completed(shot_id: int) -> void:
	if _spits.has(shot_id):
		_spits.erase(shot_id)
		spit_finished.emit(shot_id)


func _cancel_all() -> void:
	# Snapshot and detach old shots before signals, preserving newer callback requests.
	var old_shots: Dictionary[int, SpitProjectile] = _spits.duplicate()
	_spits.clear()
	for shot: SpitProjectile in old_shots.values():
		shot.cancel()
	_cancel_current()
	for shot_id: int in old_shots:
		spit_interrupted.emit(shot_id)


## Changing GPU amount restarts flame particles, but not the controller timer.
## While draining, store the setting for the next play without reviving the tail.
func set_fire_particle_count(count: int) -> bool:
	if count < 0:
		last_error = "Fire particle count must be nonnegative; zero inherits particle_count."
		return false
	_fire_particle_count = 0 if count == 0 else clampi(count, 8, 512)
	last_error = ""
	if _active_name == &"fire" and _active_effect != null and not _draining:
		_active_effect.set_particle_count(get_fire_particle_count())
	return true


func get_fire_particle_count() -> int:
	return clampi(particle_count, 8, 512) if _fire_particle_count == 0 else _fire_particle_count


## Validates both inputs before updating either width. Positive values clamp.
func set_effect_widths(suction: float, fire: float) -> bool:
	if not _is_valid_width(suction) or not _is_valid_width(fire):
		return false
	_suction_width = clampf(suction, MIN_EFFECT_WIDTH, MAX_EFFECT_WIDTH)
	_fire_width = clampf(fire, MIN_EFFECT_WIDTH, MAX_EFFECT_WIDTH)
	last_error = ""
	_apply_active_width()
	return true


func _is_valid_width(value: float) -> bool:
	if not is_finite(value) or value <= 0.0:
		last_error = "Effect width/radius must be positive and finite."
		return false
	return true


func _apply_active_width() -> void:
	if _active_effect != null:
		_update_endpoints()


func _get_effect_radius(effect_name: StringName) -> float:
	return (_suction_width if effect_name == &"suction" else _fire_width) * 0.5


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
	if not is_finite(effect_range) or effect_range <= 0.0:
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
	match effect_name:
		&"suction":
			_active_effect = _suction
		&"ice":
			_active_effect = _ice
		_:
			_active_effect = _fire
	_active_name = effect_name
	_remaining = duration
	_draining = false
	_active_effect.radius = _get_effect_radius(effect_name)
	_active_effect.particle_count = get_fire_particle_count() if effect_name == &"fire" else clampi(particle_count, 8, 512)
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
	_active_effect.radius = _get_effect_radius(_active_name)
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
