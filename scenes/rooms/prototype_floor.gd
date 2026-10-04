@tool
extends Node3D
## One reusable left room / dragon channel / right room module.

const ROOM_SIZE: Vector3 = Vector3(8.0, 4.0, 8.0)
const CHANNEL_WIDTH: float = 8.0
const FLOOR_SPACING: float = 5.0

## Runtime draft: cover the current viewport without changing its framing bounds.
@export var fit_screen_edges: bool = true
@export_range(0.0, 0.5, 0.01) var edge_overscan: float = 0.1
var _presentation: Node3D
var _fit_queued: bool = false

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
	for side: StringName in [&"left", &"right"]:
		var room: Node3D = get_room(side)
		var distance: float = left_distance if side == &"left" else right_distance
		distance += maxf(0.0, edge_overscan)
		if not is_equal_approx(room.get("outer_extension"), distance):
			room.call("set_outer_extension", distance)
	return true


## Restore the eight-unit core rooms; anchors and camera stay unchanged.
func reset_outer_extensions() -> void:
	fit_screen_edges = false
	for side: StringName in [&"left", &"right"]:
		get_room(side).call("set_outer_extension", 0.0)


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


func _apply_ceiling_visibility() -> void:
	for side in [&"left", &"right"]:
		get_room(side).set("ceiling_visible", ceilings_visible)
