@tool
extends Node3D
## Shared prototype camera and lighting. Bounds use this node's local coordinates.

const SOURCE_CAMERA_POSITION: Vector3 = Vector3(0.0, 40.0, 280.0)

@export_group("Layout Framing")
@export var layout_bounds: AABB = AABB(Vector3(-12.3, -0.25, -4.3), Vector3(24.6, 14.55, 8.6)):
	set(value):
		layout_bounds = value
		_queue_reframe()
@export_range(0.0, 0.25, 0.01) var safe_border: float = 0.08:
	set(value):
		safe_border = clampf(value, 0.0, 0.25)
		_queue_reframe()
@export var framing_offset: Vector3 = Vector3.ZERO:
	set(value):
		framing_offset = value
		_queue_reframe()

@export_group("Perspective Lens")
@export_range(1.0, 500.0, 1.0) var focal_length_mm: float = 150.0:
	set(value):
		focal_length_mm = maxf(value, 1.0)
		_queue_reframe()
@export_range(1.0, 100.0, 0.1) var sensor_width_mm: float = 36.0:
	set(value):
		sensor_width_mm = maxf(value, 1.0)
		_queue_reframe()
@export var reference_aspect: Vector2 = Vector2(16.0, 9.0):
	set(value):
		reference_aspect = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_queue_reframe()
@export_range(0.0, 30.0, 0.1) var pitch_degrees: float = 5.0:
	set(value):
		pitch_degrees = clampf(value, 0.0, 30.0)
		_queue_reframe()
@export_range(0.1, 5.0, 0.1) var near_clip: float = 0.5:
	set(value):
		near_clip = maxf(value, 0.1)
		_queue_reframe()
@export_range(1.0, 50.0, 0.5) var far_padding: float = 8.0:
	set(value):
		far_padding = maxf(value, 1.0)
		_queue_reframe()

@onready var _camera: Camera3D = %PresentationCamera
@onready var _key_light: DirectionalLight3D = %WarmKey
@onready var _light_rig: Node3D = $LightRig

var _reframe_queued: bool = false
var _framing_distance: float = 0.0
var _source_scale: float = 1.0
var _source_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	get_viewport().size_changed.connect(_queue_reframe)
	reframe()


## Refit the eight bounds corners, including depth, to the current viewport.
func reframe() -> void:
	_reframe_queued = false
	if not is_instance_valid(_camera):
		return
	var bounds: AABB = layout_bounds.abs()
	if not bounds.has_volume():
		push_warning("PrototypePresentation needs layout bounds with positive volume.")
		return
	var reference_ratio: float = reference_aspect.x / reference_aspect.y
	var tangent_vertical: float = sensor_width_mm / (2.0 * focal_length_mm * reference_ratio)
	var tangent_horizontal: float = tangent_vertical * _get_viewport_aspect()
	var usable_frame: float = 1.0 - 2.0 * safe_border
	var camera_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(-pitch_degrees))
	var target: Vector3 = bounds.get_center() + framing_offset
	var distance: float = near_clip
	var camera_space_points: Array[Vector3] = []
	for index: int in range(8):
		var point: Vector3 = camera_basis.transposed() * (bounds.get_endpoint(index) - target)
		camera_space_points.append(point)
		var horizontal_distance: float = absf(point.x) / (tangent_horizontal * usable_frame)
		var vertical_distance: float = absf(point.y) / (tangent_vertical * usable_frame)
		distance = maxf(distance, point.z + maxf(horizontal_distance, vertical_distance))
		distance = maxf(distance, point.z + near_clip + 1.0)
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.fov = rad_to_deg(2.0 * atan(tangent_vertical))
	_camera.basis = camera_basis
	_camera.position = target + camera_basis.z * distance
	_camera.near = near_clip
	var maximum_depth: float = 0.0
	for point: Vector3 in camera_space_points:
		maximum_depth = maxf(maximum_depth, distance - point.z)
	_camera.far = maximum_depth + far_padding
	_key_light.directional_shadow_max_distance = _camera.far
	_light_rig.position = bounds.get_center()
	_framing_distance = distance
	# Preserve the converted source Z distance, then translate to the stage center.
	_source_scale = camera_basis.z.z * distance / SOURCE_CAMERA_POSITION.z
	_source_offset = _camera.position - SOURCE_CAMERA_POSITION * _source_scale


## Called after a level generator has built a different number of floors.
## room_size is (width, height, depth); floor_origin is in presentation local space.
func configure_for_layers(layer_count: int, layer_spacing: float = 5.0,
		room_size: Vector3 = Vector3(8.0, 4.0, 8.0), room_center_x: float = 8.0,
		floor_origin: Vector3 = Vector3.ZERO) -> void:
	if layer_count < 1 or layer_spacing <= 0.0 or room_size.x <= 0.0 \
			or room_size.y <= 0.0 or room_size.z <= 0.0 or room_center_x < 0.0:
		push_warning("PrototypePresentation received invalid floor dimensions.")
		return
	var half_width: float = room_center_x + room_size.x * 0.5 + 0.3
	var half_depth: float = room_size.z * 0.5 + 0.3
	var height: float = (layer_count - 1) * layer_spacing + room_size.y
	layout_bounds = AABB(floor_origin + Vector3(-half_width, -0.25, -half_depth),
		Vector3(half_width * 2.0, height + 0.55, half_depth * 2.0))
	reframe()


func get_framing_settings() -> Dictionary:
	return {
		"distance": _framing_distance,
		"source_scale": _source_scale,
		"source_offset": _source_offset,
		"camera_position": _camera.position,
		"camera_rotation_degrees": _camera.rotation_degrees,
		"vertical_fov_degrees": _camera.fov,
		"near_clip": _camera.near,
		"far_clip": _camera.far,
		"viewport_aspect": _get_viewport_aspect(),
	}


func _get_viewport_aspect() -> float:
	# The editor's 3D panel has a different shape than the intended game frame.
	if not Engine.is_editor_hint():
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			return viewport_size.x / viewport_size.y
	return reference_aspect.x / reference_aspect.y


func _queue_reframe() -> void:
	if is_node_ready() and not _reframe_queued:
		_reframe_queued = true
		reframe.call_deferred()
