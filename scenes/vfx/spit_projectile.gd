class_name SpitProjectile
extends Node3D
## Visual-only world-space quadratic arc. No gameplay collision or pot mutation.

signal completed

var _source: Vector3
var _target: Vector3
var _duration: float
var _arc_height: float
var _elapsed: float = 0.0
var _flying: bool = false

@onready var _trail: CPUParticles3D = $Trail


func launch(source: Vector3, target: Vector3, visual: Node3D, duration: float, arc_height: float) -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_source = source
	_target = target
	_duration = duration
	_arc_height = arc_height
	add_child(visual)
	visual.position = Vector3.ZERO
	for node: Node in visual.find_children("*", "CollisionObject3D", true, false):
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if visual is CollisionObject3D:
		(visual as CollisionObject3D).collision_layer = 0
		(visual as CollisionObject3D).collision_mask = 0
	global_position = source
	_trail.emitting = true
	_flying = true


func get_position_at(progress: float) -> Vector3:
	var t: float = clampf(progress, 0.0, 1.0)
	return _source.lerp(_target, t) + Vector3.UP * (4.0 * _arc_height * t * (1.0 - t))


func cancel() -> void:
	_flying = false
	_trail.emitting = false
	visible = false
	queue_free()


func _process(delta: float) -> void:
	if not _flying:
		return
	_elapsed += delta
	global_position = get_position_at(_elapsed / _duration)
	if _elapsed >= _duration:
		_flying = false
		_trail.emitting = false
		visible = false
		completed.emit()
		queue_free()
