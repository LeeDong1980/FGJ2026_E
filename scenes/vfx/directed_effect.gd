class_name DirectedDragonEffect
extends Node3D
## Visual particles only. Endpoints and all size settings use world units.

@export_range(8, 512, 1) var particle_count: int = 96
@export_range(0.01, 1.0, 0.01) var particle_lifetime: float = 0.28
@export_range(0.01, 4.0, 0.01) var radius: float = 0.35

var _emitters: Array[GPUParticles3D] = []
var _core: MeshInstance3D
var _core_material: ShaderMaterial
var _core_strength: float = 0.0
var _core_draining: bool = false


func _ready() -> void:
	# Never inherit any dragon root or imported model scale into world-space particles.
	top_level = true
	global_transform = Transform3D.IDENTITY
	for child: Node in get_children():
		if child is GPUParticles3D:
			var emitter: GPUParticles3D = child as GPUParticles3D
			emitter.process_material = emitter.process_material.duplicate(true)
			emitter.draw_pass_1 = emitter.draw_pass_1.duplicate(true)
			var mesh: Mesh = emitter.draw_pass_1
			mesh.surface_set_material(0, mesh.surface_get_material(0).duplicate(true))
			_emitters.append(emitter)
	_core = get_node_or_null("FlameCore") as MeshInstance3D
	if _core != null:
		_core.material_override = _core.material_override.duplicate(true)
		_core_material = _core.material_override as ShaderMaterial
	clear()


func begin(source: Vector3, target: Vector3) -> void:
	set_endpoints(source, target)
	if _core != null:
		_core_strength = 1.0
		_core_draining = false
		_core_material.set_shader_parameter(&"strength", _core_strength)
		_core.visible = true
	for emitter: GPUParticles3D in _emitters:
		if emitter.name == &"Flow":
			emitter.amount = particle_count
			emitter.lifetime = particle_lifetime
		var process_material: ShaderMaterial = emitter.process_material as ShaderMaterial
		process_material.set_shader_parameter(&"enabled", true)
		emitter.visible = true
		emitter.restart()
		emitter.emitting = true


func set_endpoints(source: Vector3, target: Vector3) -> void:
	var bounds: AABB = AABB(source, Vector3.ZERO).expand(target).grow(radius + 0.6)
	if _core != null:
		var offset: Vector3 = target - source
		var axis: Vector3 = offset.normalized()
		var reference: Vector3 = Vector3.RIGHT if absf(axis.y) > 0.95 else Vector3.UP
		var side: Vector3 = axis.cross(reference).normalized()
		_core.global_transform = Transform3D(Basis(side * radius, axis * offset.length(), side.cross(axis) * radius), (source + target) * 0.5)
	for emitter: GPUParticles3D in _emitters:
		var process_material: ShaderMaterial = emitter.process_material as ShaderMaterial
		process_material.set_shader_parameter(&"source_position", source)
		process_material.set_shader_parameter(&"target_position", target)
		process_material.set_shader_parameter(&"radius", radius)
		var surface: ShaderMaterial = emitter.draw_pass_1.surface_get_material(0) as ShaderMaterial
		surface.set_shader_parameter(&"source_position", source)
		surface.set_shader_parameter(&"target_position", target)
		emitter.visibility_aabb = bounds


func end_emission() -> void:
	_core_draining = true
	for emitter: GPUParticles3D in _emitters:
		emitter.emitting = false


func clear() -> void:
	_core_draining = false
	_core_strength = 0.0
	if _core != null:
		_core.visible = false
		_core_material.set_shader_parameter(&"strength", 0.0)
	for emitter: GPUParticles3D in _emitters:
		emitter.emitting = false
		emitter.visible = false
		(emitter.process_material as ShaderMaterial).set_shader_parameter(&"enabled", false)


func get_tail_duration() -> float:
	var longest: float = particle_lifetime
	for emitter: GPUParticles3D in _emitters:
		longest = maxf(longest, emitter.lifetime)
	return longest + 0.05


func get_emitters() -> Array[GPUParticles3D]:
	return _emitters.duplicate()


func _process(delta: float) -> void:
	if _core != null and _core_draining:
		_core_strength = maxf(0.0, _core_strength - delta / get_tail_duration())
		_core_material.set_shader_parameter(&"strength", _core_strength)
