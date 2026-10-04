@tool
extends Node3D
## One reusable left room / dragon channel / right room module.

const ROOM_SIZE: Vector3 = Vector3(8.0, 4.0, 8.0)
const CHANNEL_WIDTH: float = 8.0
const FLOOR_SPACING: float = 5.0

## Runtime draft: cover the current viewport without changing its framing bounds.
@export var fit_screen_edges: bool = true
@export_range(0.0, 0.5, 0.01) var edge_overscan: float = 0.1
## Minimum outside slab thickness, also used before a runtime camera is available.
@export_range(0.05, 2.0, 0.05) var boundary_cap_min_height: float = 0.3
var _presentation: Node3D
var _fit_queued: bool = false
var _top_cap_enabled: bool = false
var _bottom_cap_enabled: bool = false

@export var floor_index: int = 0
@export var ceilings_visible: bool = false:
	set(value):
		ceilings_visible = value
		if is_node_ready():
			_apply_ceiling_visibility()


func _ready() -> void:
	_apply_ceiling_visibility()
	if not Engine.is_editor_hint() and fit_screen_edges:
		_connect_presentation.call_deferred()


func _connect_presentation() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var ancestor: Node = get_parent()
	while ancestor != null:
		var candidate: Node = ancestor.get_node_or_null("PrototypePresentation")
		if candidate is Node3D and candidate.has_method("get_visible_horizontal_span"):
			_presentation = candidate as Node3D
			if _presentation.has_signal("framing_changed") \
					and not _presentation.is_connected("framing_changed", _queue_fit):
				_presentation.connect("framing_changed", _queue_fit)
			fit_to_presentation_edges()
			return
		ancestor = ancestor.get_parent()


func _queue_fit() -> void:
	if not _fit_queued:
		_fit_queued = true
		fit_to_presentation_edges.call_deferred()


## Camera queries are world coordinates; room extension distances are local.
## An invalid sample leaves the existing geometry intact, without reframing.
func fit_to_presentation_edges() -> bool:
	_fit_queued = false
	if Engine.is_editor_hint() or not is_inside_tree() or is_queued_for_deletion() \
			or not fit_screen_edges or not is_instance_valid(_presentation):
		return false
	if not is_finite(edge_overscan):
		return false
	var left_distance: float = 0.0
	var right_distance: float = 0.0
	for height: float in [0.0, ROOM_SIZE.y]:
		for depth: float in [-ROOM_SIZE.z * 0.5, ROOM_SIZE.z * 0.5]:
			var row: Vector3 = to_global(Vector3(0.0, height, depth))
			var span: Dictionary = _presentation.call("get_visible_horizontal_span", row.y, row.z)
			if not span.get("valid", false):
				return false
			left_distance = maxf(left_distance, -get_room(&"left").to_local(span["left"]).x - ROOM_SIZE.x * 0.5)
			right_distance = maxf(right_distance, get_room(&"right").to_local(span["right"]).x - ROOM_SIZE.x * 0.5)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var planes: Array[Plane] = camera.get_frustum() if camera != null else []
	for side: StringName in [&"left", &"right"]:
		var room: Node3D = get_room(side)
		var distance: float = left_distance if side == &"left" else right_distance
		var cap_heights: Vector2 = _get_boundary_cap_heights(room, planes)
		distance = maxf(distance, _get_boundary_cap_extension(room, planes, cap_heights))
		distance += maxf(0.0, edge_overscan)
		if not is_equal_approx(room.get("outer_extension"), distance):
			room.call("set_outer_extension", distance)
		_apply_boundary_caps(room, cap_heights)
	return true


## Frustum planes are near/far/left/top/right/bottom. Project their Y boundaries
## at both depths so the outside slabs cover the entire inclined camera frame.
func _get_boundary_cap_heights(room: Node3D, planes: Array[Plane]) -> Vector2:
	var heights := Vector2(boundary_cap_min_height if _top_cap_enabled else 0.0,
			boundary_cap_min_height if _bottom_cap_enabled else 0.0)
	if planes.size() != 6 or absf(planes[3].normal.y) < 0.000001 \
			or absf(planes[5].normal.y) < 0.000001:
		return heights
	var foundation: MeshInstance3D = room.get_node("Architecture/Foundation/Mesh") as MeshInstance3D
	var ceiling: Node3D = room.get_node("CeilingAnchor/RoomCeiling") as Node3D
	var bounds: AABB = foundation.get_aabb()
	var underside_y: float = room.to_local(foundation.to_global(Vector3(0.0, bounds.position.y, 0.0))).y
	for i in 8:
		var corner: Vector3 = foundation.to_global(bounds.get_endpoint(i))
		if _top_cap_enabled:
			var top_y: float = (planes[3].d - planes[3].normal.x * corner.x - planes[3].normal.z * corner.z) / planes[3].normal.y
			heights.x = maxf(heights.x, ceiling.to_local(Vector3(corner.x, top_y, corner.z)).y + edge_overscan)
		if _bottom_cap_enabled:
			var bottom_y: float = (planes[5].d - planes[5].normal.x * corner.x - planes[5].normal.z * corner.z) / planes[5].normal.y
			heights.y = maxf(heights.y, underside_y - room.to_local(Vector3(corner.x, bottom_y, corner.z)).y + edge_overscan)
	return heights


## The bottom of a tall outside slab may need more width than the room itself.
## Query side planes directly because the overscan is intentionally off screen.
func _get_boundary_cap_extension(room: Node3D, planes: Array[Plane], heights: Vector2) -> float:
	if planes.size() != 6 or heights == Vector2.ZERO:
		return 0.0
	var direction: float = float(room.get("outward_direction"))
	var plane: Plane = planes[2] if direction < 0.0 else planes[4]
	if absf(plane.normal.x) < 0.000001:
		return 0.0
	var sample_heights: Array[float] = []
	if heights.x > 0.0:
		sample_heights.append((room.get_node("CeilingAnchor") as Node3D).position.y + heights.x)
	if heights.y > 0.0:
		var foundation: MeshInstance3D = room.get_node("Architecture/Foundation/Mesh") as MeshInstance3D
		var underside: Vector3 = room.to_local(foundation.to_global(Vector3(0.0, foundation.get_aabb().position.y, 0.0)))
		sample_heights.append(underside.y - heights.y)
	var extension: float = 0.0
	for height: float in sample_heights:
		for depth: float in [-ROOM_SIZE.z * 0.5, ROOM_SIZE.z * 0.5]:
			var row: Vector3 = room.to_global(Vector3(0.0, height, depth))
			var world_x: float = (plane.d - plane.normal.y * row.y - plane.normal.z * row.z) / plane.normal.x
			extension = maxf(extension, direction * room.to_local(Vector3(world_x, row.y, row.z)).x - ROOM_SIZE.x * 0.5)
	return extension


func _apply_boundary_caps(room: Node3D, heights: Vector2) -> void:
	if _top_cap_enabled:
		room.set(&"ceiling_visible", true)
		room.get_node("CeilingAnchor/RoomCeiling").call("set_fill_height", heights.x)
	room.call(&"set_bottom_ceiling_height", heights.y)


## Called by LaneLayout for the highest/lowest generated floors (both if single).
func configure_boundary_caps(top_enabled: bool, bottom_enabled: bool) -> void:
	_top_cap_enabled = top_enabled
	_bottom_cap_enabled = bottom_enabled
	if top_enabled:
		set_ceilings_visible(true)
	for side: StringName in [&"left", &"right"]:
		_apply_boundary_caps(get_room(side), Vector2(
				boundary_cap_min_height if top_enabled else 0.0,
				boundary_cap_min_height if bottom_enabled else 0.0))
	if is_instance_valid(_presentation):
		_queue_fit()


## Restore the eight-unit core rooms; anchors and camera stay unchanged.
func reset_outer_extensions() -> void:
	fit_screen_edges = false
	for side: StringName in [&"left", &"right"]:
		get_room(side).call("set_outer_extension", 0.0)
		_apply_boundary_caps(get_room(side), Vector2(
				boundary_cap_min_height if _top_cap_enabled else 0.0,
				boundary_cap_min_height if _bottom_cap_enabled else 0.0))


func get_room(side: StringName) -> Node3D:
	match side:
		&"left":
			return get_node("LeftRoom") as Node3D
		&"right":
			return get_node("RightRoom") as Node3D
	return null


func get_anchor(anchor_name: StringName) -> Marker3D:
	match anchor_name:
		&"DragonAnchor":
			return get_node("DragonAnchor") as Marker3D
		&"QueueSpawnAnchor", &"QueueFrontAnchor":
			return get_room(&"left").get_node_or_null(NodePath(str(anchor_name))) as Marker3D
		&"PotAnchor", &"NestAnchor", &"HatchlingAnchor", &"EggAnchor":
			return get_room(&"right").get_node_or_null(NodePath(str(anchor_name))) as Marker3D
	return null


func set_ceilings_visible(enabled: bool) -> void:
	ceilings_visible = enabled


## Close only the gap below the next floor, using its actual foundation underside.
## Both room ceilings remain separate so the central dragon channel stays open.
func fit_ceilings_to_floor(upper_floor: Node3D) -> void:
	set_ceilings_visible(upper_floor != null)
	if upper_floor == null:
		return
	for side: StringName in [&"left", &"right"]:
		var room: Node3D = get_room(side)
		var ceiling: Node3D = room.get_node("CeilingAnchor/RoomCeiling") as Node3D
		var upper_room: Node3D = upper_floor.call(&"get_room", side)
		var foundation: MeshInstance3D = upper_room.get_node("Architecture/Foundation/Mesh") as MeshInstance3D
		var underside: Vector3 = foundation.to_global(Vector3(0.0, foundation.get_aabb().position.y, 0.0))
		var fill_height: float = ceiling.to_local(underside).y
		# A zero/negative gap must not create an inverted slab or intersect the room.
		room.set(&"ceiling_visible", fill_height > 0.0)
		if fill_height > 0.0:
			ceiling.call(&"set_fill_height", fill_height)


func _apply_ceiling_visibility() -> void:
	for side in [&"left", &"right"]:
		get_room(side).set("ceiling_visible", ceilings_visible)
