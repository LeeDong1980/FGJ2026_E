extends SceneTree
## Run in an imported project copy: --headless --script res://scenes/vfx/verify_dragon_vfx.gd

class TestDragon extends Node3D:
	var anchor: Marker3D

	func _init() -> void:
		anchor = Marker3D.new()
		anchor.position = Vector3(0.3, 0.4, 0.5)
		add_child(anchor)

	func get_mouth_anchor() -> Marker3D:
		return anchor

class WrongAnchorDragon extends Node3D:
	func get_mouth_anchor() -> String:
		return "not a Marker3D"

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_verify")


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL ", description)


func _verify() -> void:
	var scene: PackedScene = load("res://scenes/vfx/dragon_effects.tscn")
	_expect(scene != null, "controller scene loads")
	if scene == null:
		quit(1)
		return
	var effects: DragonEffects = scene.instantiate() as DragonEffects
	var second: DragonEffects = scene.instantiate() as DragonEffects
	_expect(not effects.play_fire(Vector3.LEFT), "playback before ready rejected")
	root.add_child(effects)
	root.add_child(second)
	var events: Array[String] = []
	effects.effect_started.connect(func(kind: StringName) -> void: events.append("S:" + str(kind)))
	effects.effect_finished.connect(func(kind: StringName) -> void: events.append("F:" + str(kind)))
	effects.effect_interrupted.connect(func(kind: StringName) -> void: events.append("I:" + str(kind)))
	_expect(not effects.play_fire(Vector3.LEFT), "missing dragon rejects playback")
	_expect(not effects.last_error.is_empty(), "missing anchor explains rejection")
	var plain: Node3D = Node3D.new()
	root.add_child(plain)
	_expect(not effects.bind_dragon(plain), "node without mouth API rejected")
	_expect(not effects.play_suction(Vector3.LEFT), "no fallback to root origin")
	var wrong: WrongAnchorDragon = WrongAnchorDragon.new()
	root.add_child(wrong)
	_expect(not effects.bind_dragon(wrong), "incorrect anchor return type rejected safely")
	var dragon: TestDragon = TestDragon.new()
	root.add_child(dragon)
	_expect(effects.bind_dragon(dragon), "mouth API binds")
	_expect(second.bind_dragon(dragon), "second controller binds")
	var target: Vector3 = Vector3(-4.0, 0.6, 0.8)
	_expect(not effects.play_fire(target, 0.0), "zero duration rejected")
	_expect(not effects.play_fire(target, -0.1), "negative duration rejected")
	_expect(not effects.play_fire(target, NAN), "nonfinite duration rejected")
	_expect(not effects.play_fire(Vector3(INF, 0, 0)), "nonfinite target rejected")
	_expect(not effects.play_suction(dragon.anchor.global_position), "zero direction rejected")
	_expect(events.is_empty(), "invalid calls emit no lifecycle events")
	for node: Node in effects.find_children("*", "GPUParticles3D", true, false):
		var emitter: GPUParticles3D = node as GPUParticles3D
		_expect(not emitter.emitting and not emitter.visible, "all emitters idle at load")
		_expect(not emitter.local_coords, "world coordinates enabled")
	var flow: GPUParticles3D = effects.get_node("SuctionEffect/Flow") as GPUParticles3D
	var second_flow: GPUParticles3D = second.get_node("SuctionEffect/Flow") as GPUParticles3D
	var core: MeshInstance3D = effects.get_node("FireBreathEffect/FlameCore") as MeshInstance3D
	var second_core: MeshInstance3D = second.get_node("FireBreathEffect/FlameCore") as MeshInstance3D
	_expect(not core.visible, "cone core idle at load")
	_expect(core.material_override != second_core.material_override, "cone core materials isolated")
	_expect(flow.process_material != second_flow.process_material, "process materials isolated")
	_expect(flow.draw_pass_1 != second_flow.draw_pass_1, "draw meshes isolated")
	_expect(flow.draw_pass_1.surface_get_material(0) != second_flow.draw_pass_1.surface_get_material(0), "surface materials isolated")
	_expect(effects.play_suction(target, 0.1), "suction starts")
	_expect(effects.get_active_effect() == &"suction" and flow.emitting, "suction emits")
	_expect(effects.play_fire(target, 0.1), "fire replaces suction")
	_expect(core.visible, "fire has a continuous cone core")
	_expect(is_equal_approx(core.global_basis.y.length(), dragon.anchor.global_position.distance_to(target)), "cone length matches world endpoints")
	_expect(events == ["S:suction", "I:suction", "S:fire"], "switch lifecycle order")
	_expect(not flow.visible and not flow.emitting, "old particles clear on switch")
	_expect(effects.play_fire(target, 0.1), "same effect restarts")
	_expect(events.slice(-2) == ["I:fire", "S:fire"], "replay lifecycle order")
	effects.stop_effects()
	_expect(effects.get_active_effect() == &"", "explicit stop clears active state")
	_expect(not core.visible, "stop clears cone core")
	var stopped_count: int = events.size()
	effects.stop_effects()
	_expect(events.size() == stopped_count, "idle stop emits nothing")
	_expect(effects.play_suction(target, 0.06), "finite effect starts")
	await create_timer(0.45).timeout
	_expect(effects.get_active_effect() == &"", "finite effect drains and completes")
	_expect(events.back() == "F:suction", "natural completion is finished")
	_expect(effects.play_fire(target, 0.06), "finite fire starts")
	await create_timer(0.55).timeout
	_expect(effects.get_active_effect() == &"" and not core.visible, "cone core drains and clears naturally")
	_expect(effects.play_suction(target, 2.0), "long effect starts")
	dragon.scale = Vector3.ONE * 2.0
	await process_frame
	await process_frame
	var material: ShaderMaterial = flow.process_material as ShaderMaterial
	var source: Vector3 = material.get_shader_parameter(&"source_position")
	_expect(source.is_equal_approx(dragon.anchor.global_position), "mouth follows scale2")
	dragon.position = Vector3(1.0, 2.0, 3.0)
	dragon.scale = Vector3.ONE * 5.0
	dragon.rotation.y = -0.7
	await process_frame
	await process_frame
	source = material.get_shader_parameter(&"source_position")
	_expect(source.is_equal_approx(dragon.anchor.global_position), "mouth follows translation rotation scale5")
	_expect(effects.get_node("SuctionEffect").global_transform.is_equal_approx(Transform3D.IDENTITY), "particle root ignores inherited scale")
	effects.set_target_global_position(Vector3(-1.0, 2.0, 3.0))
	var endpoint: Vector3 = material.get_shader_parameter(&"target_position")
	_expect(endpoint.is_equal_approx(Vector3(-1.0, 2.0, 3.0)), "target switches during playback")
	effects.set_target_global_position(Vector3(-100.0, 2.0, 3.0))
	_expect(is_equal_approx(source.distance_to(effects.get_visual_end_global_position()), effects.effect_range), "far target clamps to world range")
	_expect(flow.visibility_aabb.has_point(source) and flow.visibility_aabb.has_point(effects.get_visual_end_global_position()), "bounds include both endpoints")
	_expect(second.play_suction(Vector3(3.0, 2.0, 3.0)), "second effect plays independently")
	var isolated_target: Vector3 = (second_flow.process_material as ShaderMaterial).get_shader_parameter(&"target_position")
	_expect(not isolated_target.is_equal_approx(effects.get_visual_end_global_position()), "target uniforms remain isolated")
	effects.stop_effects()
	_expect(second.get_active_effect() == &"suction", "stop does not affect other instance")
	second.stop_effects()
	var callback_replayed: bool = false
	var replay_callback: Callable = func(_kind: StringName) -> void:
		if not callback_replayed:
			callback_replayed = true
			effects.play_suction(target, 0.2)
	effects.effect_interrupted.connect(replay_callback)
	effects.play_fire(target, 1.0)
	effects.play_fire(target, 1.0)
	_expect(effects.get_active_effect() == &"suction", "newer signal callback request wins")
	effects.effect_interrupted.disconnect(replay_callback)
	effects.stop_effects()
	effects.play_fire(target, 1.0)
	dragon.anchor.queue_free()
	await process_frame
	await process_frame
	_expect(effects.get_active_effect() == &"", "freed anchor interrupts and clears")
	_expect(not effects.play_fire(target), "freed anchor rejects new playback")
	# Validate the animator's actual public interface, without changing their scene.
	var real_scene: PackedScene = load("res://scenes/red_dragon/red_dragon.tscn")
	var real_dragon: Node3D = real_scene.instantiate() as Node3D
	root.add_child(real_dragon)
	await process_frame
	await process_frame
	_expect(effects.bind_dragon(real_dragon), "actual RedDragon mouth API binds")
	_expect(effects.play_fire(Vector3(-4.6, 1.0, 1.1), 0.1), "actual RedDragon accepts target")
	effects.stop_effects()
	real_dragon.scale = Vector3.ONE * 5.0
	real_dragon.position = Vector3(0.0, 6.4, -16.018951)
	real_dragon.call(&"play_animation", &"fly", true)
	_expect(effects.play_suction(Vector3(-4.6, 6.0, 1.1), 1.0), "actual scale5 dragon starts")
	await create_timer(0.12).timeout
	await process_frame
	var real_anchor: Marker3D = real_dragon.call(&"get_mouth_anchor") as Marker3D
	source = material.get_shader_parameter(&"source_position")
	_expect(source.distance_to(real_anchor.global_position) < 0.01, "animated mouth matches particle source after skeleton update")
	effects.stop_effects()
	var main_scene: Node3D = load("res://scenes/main/main.tscn").instantiate() as Node3D
	root.add_child(main_scene)
	var integrated: DragonEffects = main_scene.get_node_or_null("Effects") as DragonEffects
	if integrated != null:
		_expect(integrated.get_active_effect() == &"", "main integrated controller starts idle")
		_expect(integrated.play_fire(Vector3(-4.6, 6.0, 1.1), 0.1), "main dragon_path automatically binds")
		integrated.stop_effects()
	print("VFX_RESULT checks=", _checks, " failures=", _failures)
	quit(0 if _failures == 0 else 1)
