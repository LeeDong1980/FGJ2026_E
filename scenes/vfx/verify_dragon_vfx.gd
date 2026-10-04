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
	var main_scene: Node3D = load("res://scenes/main/art_prev.tscn").instantiate() as Node3D
	root.add_child(main_scene)
	var integrated: DragonEffects = main_scene.get_node_or_null("Effects") as DragonEffects
	if integrated != null:
		_expect(integrated.get_active_effect() == &"", "main integrated controller starts idle")
		_expect(integrated.play_fire(Vector3(-4.6, 6.0, 1.1), 0.1), "main dragon_path automatically binds")
		integrated.stop_effects()
	_verify_width_controls(scene)
	_verify_preview_controls()
	await _verify_fire_density(scene)
	await _verify_spit(scene)
	print("VFX_RESULT checks=", _checks, " failures=", _failures)
	quit(0 if _failures == 0 else 1)


func _verify_width_controls(scene: PackedScene) -> void:
	var effects: DragonEffects = scene.instantiate() as DragonEffects
	var second: DragonEffects = scene.instantiate() as DragonEffects
	var dragon: TestDragon = TestDragon.new()
	root.add_child(dragon)
	dragon.scale = Vector3.ONE * 5.0
	dragon.rotation.y = -0.7
	dragon.position = Vector3(1.0, 2.0, 3.0)
	root.add_child(effects)
	root.add_child(second)
	effects.bind_dragon(dragon)
	_expect(effects.suction_width == 4.0 and effects.fire_width == 3.0, "exaggerated defaults remain independent")
	var source: Vector3 = dragon.anchor.global_position
	var target: Vector3 = source + Vector3.LEFT * 4.0
	var suction: GPUParticles3D = effects.get_node("SuctionEffect/Flow") as GPUParticles3D
	var fire: GPUParticles3D = effects.get_node("FireBreathEffect/Flow") as GPUParticles3D
	var core: MeshInstance3D = effects.get_node("FireBreathEffect/FlameCore") as MeshInstance3D
	for widths: Vector2 in [Vector2(0.1, 0.1), Vector2(4.0, 3.0), Vector2(8.0, 8.0)]:
		_expect(effects.set_effect_widths(widths.x, widths.y), "valid min/default/max pair accepted")
		effects.play_suction(target, 1.0)
		var suction_radius: float = (suction.process_material as ShaderMaterial).get_shader_parameter(&"radius")
		_expect(is_equal_approx(suction_radius, widths.x * 0.5), "suction shader receives diameter / 2")
		_expect(suction.visibility_aabb.has_point(source + Vector3.UP * suction_radius), "suction bounds cover selected width at scale5")
		effects.play_fire(target, 1.0)
		var fire_radius: float = (fire.process_material as ShaderMaterial).get_shader_parameter(&"radius")
		_expect(is_equal_approx(fire_radius, widths.y * 0.5), "fire shader receives diameter / 2")
		_expect(is_equal_approx(core.global_basis.x.length(), widths.y * 0.5), "cone world radius follows width at scale5")
		_expect(is_equal_approx(core.global_basis.y.length(), 4.0), "width does not change cone length")
		_expect(fire.visibility_aabb.has_point(source + Vector3.UP * fire_radius), "fire bounds cover selected width")
	var events: Array[StringName] = []
	effects.effect_started.connect(func(kind: StringName) -> void: events.append(kind))
	effects.effect_interrupted.connect(func(kind: StringName) -> void: events.append(kind))
	var range_before: float = effects.effect_range
	effects.set_effect_widths(1.0, 2.0)
	_expect(is_equal_approx(core.global_basis.x.length(), 1.0), "pair setter updates active cone immediately")
	_expect(events.is_empty(), "width update does not restart or interrupt playback")
	effects.fire_width = 5.0
	_expect(is_equal_approx(core.global_basis.x.length(), 2.5), "property setter updates active cone immediately")
	_expect((fire.process_material as ShaderMaterial).get_shader_parameter(&"radius") == 2.5, "active particle spread updates immediately")
	_expect(fire.visibility_aabb.has_point(source + Vector3.UP * 2.5), "active bounds expand immediately")
	_expect(second.suction_width == 4.0 and second.fire_width == 3.0, "width changes remain instance local")
	for invalid: Vector2 in [Vector2(0.0, 3.0), Vector2(-1.0, 3.0), Vector2(NAN, 2.0), Vector2(2.0, INF)]:
		_expect(not effects.set_effect_widths(invalid.x, invalid.y), "invalid pair rejected")
		_expect(effects.suction_width == 1.0 and effects.fire_width == 5.0, "invalid pair changes neither effect")
	effects.suction_width = 0.0
	effects.fire_width = NAN
	_expect(effects.suction_width == 1.0 and effects.fire_width == 5.0, "invalid property assignments retain widths")
	_expect(effects.set_effect_widths(0.001, 999.0), "positive out-of-range pair clamps")
	_expect(effects.suction_width == 0.1 and effects.fire_width == 8.0, "new API clamps to legal bounds")
	effects.suction_width = 999.0
	effects.fire_width = 0.001
	_expect(effects.suction_width == 8.0 and effects.fire_width == 0.1, "property assignments clamp to legal bounds")
	effects.radius = 0.35
	_expect(is_equal_approx(effects.radius, 0.35), "legacy getter remains radius")
	_expect(is_equal_approx(effects.suction_width, 0.7) and is_equal_approx(effects.fire_width, 0.7), "legacy radius writes both diameters")
	_expect(is_equal_approx(core.global_basis.x.length(), 0.35), "legacy radius updates active geometry")
	effects.radius = 0.01
	_expect(is_equal_approx(effects.suction_width, 0.02), "old minimum radius remains supported")
	effects.radius = INF
	_expect(is_equal_approx(effects.radius, 0.01), "invalid legacy radius ignored")
	_expect(effects.effect_range == range_before, "all width APIs leave range unchanged")
	effects.stop_effects()
	_expect(not core.visible and not fire.visible and not suction.visible, "stop clears widened effects")
	# Derived legacy radius must not overwrite the distinct widths when saved.
	effects.set_effect_widths(2.4, 3.8)
	var saved: PackedScene = PackedScene.new()
	_expect(saved.pack(effects) == OK, "configured controller packs")
	var state: SceneState = saved.get_state()
	var radius_saved: bool = false
	for property_index: int in range(state.get_node_property_count(0)):
		radius_saved = radius_saved or state.get_node_property_name(0, property_index) == &"radius"
	_expect(not radius_saved, "derived radius not serialized into new scenes")
	var restored: DragonEffects = saved.instantiate() as DragonEffects
	_expect(is_equal_approx(restored.suction_width, 2.4) and is_equal_approx(restored.fire_width, 3.8), "independent widths survive PackedScene round trip")
	restored.free()
	var legacy_text: String = FileAccess.get_file_as_string("res://scenes/vfx/dragon_effects.tscn").replace('script = ExtResource("1")', 'script = ExtResource("1")\nradius = 0.35')
	var legacy_file: FileAccess = FileAccess.open("user://legacy_width.tscn", FileAccess.WRITE)
	legacy_file.store_string(legacy_text)
	legacy_file.close()
	var legacy_scene: PackedScene = load("user://legacy_width.tscn")
	var legacy_instance: DragonEffects = legacy_scene.instantiate() as DragonEffects
	_expect(is_equal_approx(legacy_instance.suction_width, 0.7) and is_equal_approx(legacy_instance.fire_width, 0.7), "old serialized radius still loads as half width")
	legacy_instance.free()


func _verify_preview_controls() -> void:
	var preview: Node3D = load("res://scenes/vfx/vfx_preview.tscn").instantiate() as Node3D
	root.add_child(preview)
	var effects: DragonEffects = preview.get_node("DragonEffects") as DragonEffects
	var initial_range: float = effects.effect_range
	for entry: Vector2i in [Vector2i(KEY_Q, 1), Vector2i(KEY_A, -1), Vector2i(KEY_W, 1), Vector2i(KEY_S, -1)]:
		var old_suction: float = effects.suction_width
		var old_fire: float = effects.fire_width
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = entry.x
		key.pressed = true
		preview.call(&"_unhandled_key_input", key)
		if entry.x == KEY_Q or entry.x == KEY_A:
			_expect(is_equal_approx(effects.suction_width, old_suction + entry.y * 0.25) and effects.fire_width == old_fire, "preview suction controls affect only suction")
		else:
			_expect(is_equal_approx(effects.fire_width, old_fire + entry.y * 0.25) and effects.suction_width == old_suction, "preview fire controls affect only fire")
	_expect(effects.effect_range == initial_range, "preview width keys leave range unchanged")
	preview.call(&"_refresh_status")
	var label: Label = preview.get_node("Instructions/Status") as Label
	_expect(label.text.contains("吸取寬 4.00") and label.text.contains("噴火寬 3.00"), "preview displays live widths in Traditional Chinese")
	_expect(label.text.contains("完整直徑") and label.text.contains("胃袋吐食材"), "preview states diameter and fire-only scope")
	var old_count: int = effects.particle_count
	for code: int in [KEY_E, KEY_D, KEY_R]:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = code
		key.pressed = true
		preview.call(&"_unhandled_key_input", key)
		_expect(effects.particle_count == old_count, "preview fire density key preserves suction setting")
	_expect(effects.fire_particle_count == 0 and effects.get_fire_particle_count() == old_count, "preview R restores legacy shared count")


func _verify_fire_density(scene: PackedScene) -> void:
	var effects: DragonEffects = scene.instantiate() as DragonEffects
	var second: DragonEffects = scene.instantiate() as DragonEffects
	var dragon: TestDragon = TestDragon.new()
	root.add_child(dragon)
	root.add_child(effects)
	root.add_child(second)
	effects.bind_dragon(dragon)
	var target: Vector3 = dragon.anchor.global_position + Vector3.LEFT * 4.0
	var suction: GPUParticles3D = effects.get_node("SuctionEffect/Flow") as GPUParticles3D
	var fire: GPUParticles3D = effects.get_node("FireBreathEffect/Flow") as GPUParticles3D
	var sparks: GPUParticles3D = effects.get_node("FireBreathEffect/Sparks") as GPUParticles3D
	var smoke: GPUParticles3D = effects.get_node("FireBreathEffect/Smoke") as GPUParticles3D
	_expect(effects.fire_particle_count == 384 and effects.particle_count == 192, "new fire default doubles only main flame")
	effects.play_suction(target, 2.0)
	_expect(suction.amount == 192, "suction retains original density")
	effects.set_fire_particle_count(512)
	_expect(suction.amount == 192 and effects.get_active_effect() == &"suction", "fire tuning does not alter active suction")
	effects.play_fire(target, 2.0)
	var events: Array[StringName] = []
	effects.effect_started.connect(func(kind: StringName) -> void: events.append(kind))
	effects.effect_interrupted.connect(func(kind: StringName) -> void: events.append(kind))
	var remaining: float = effects._remaining
	for entry: Vector2i in [Vector2i(8, 8), Vector2i(384, 384), Vector2i(512, 512), Vector2i(1, 8), Vector2i(999, 512)]:
		_expect(effects.set_fire_particle_count(entry.x), "valid or positive clamped density accepted")
		_expect(fire.amount == entry.y and fire.emitting, "active flame receives selected count")
	_expect(events.is_empty() and effects._remaining == remaining, "density tuning preserves lifecycle and time")
	_expect(sparks.amount == 16 and smoke.amount == 12, "sparks and smoke budgets unchanged")
	_expect(effects.fire_width == 3.0 and effects.suction_width == 4.0 and effects.effect_range == 6.0, "density leaves width and range unchanged")
	_expect(not effects.set_fire_particle_count(-1) and fire.amount == 512, "negative API input rejected without mutation")
	effects.fire_particle_count = -4
	_expect(effects.fire_particle_count == 512, "negative property write ignored")
	effects.particle_count = 96
	_expect(effects.set_fire_particle_count(0) and fire.amount == 96, "zero restores legacy shared particle count")
	effects.stop_effects()
	effects.play_suction(target)
	_expect(suction.amount == 96, "legacy particle count remains usable for suction")
	effects.set_fire_particle_count(384)
	effects.play_fire(target, 0.01)
	effects._process(0.02)
	_expect(effects._draining and not fire.emitting, "finite fire enters drain")
	effects.fire_particle_count = 512
	_expect(fire.amount == 384 and not fire.emitting and effects._draining, "tail tuning does not revive or reset fading particles")
	await create_timer(0.55).timeout
	_expect(effects.get_active_effect() == &"", "density tuned tail finishes naturally")
	effects.play_fire(target)
	_expect(fire.amount == 512, "next playback applies density saved during drain")
	_expect(second.fire_particle_count == 384, "fire density remains instance local")
	var packed: PackedScene = PackedScene.new()
	_expect(packed.pack(effects) == OK, "density configured scene packs")
	var restored: DragonEffects = packed.instantiate() as DragonEffects
	_expect(restored.fire_particle_count == 512 and restored.particle_count == 96, "independent density survives scene serialization")
	restored.free()
	effects.stop_effects()
	_expect(not fire.visible and not sparks.visible and not smoke.visible, "new density stops without residual emitters")
	effects.queue_free()
	second.queue_free()
	dragon.queue_free()


func _verify_spit(scene: PackedScene) -> void:
	var effects: DragonEffects = scene.instantiate() as DragonEffects
	var food: PackedScene = load("res://scenes/ingredient/ingredient_model.tscn")
	var dragon: TestDragon = TestDragon.new()
	root.add_child(dragon)
	root.add_child(effects)
	effects.bind_dragon(dragon)
	var source: Vector3 = dragon.anchor.global_position
	var target: Vector3 = source + Vector3.RIGHT * 12.0
	var events: Array[String] = []
	effects.spit_started.connect(func(id: int) -> void: events.append("S:%d" % id))
	effects.spit_finished.connect(func(id: int) -> void: events.append("F:%d" % id))
	effects.spit_interrupted.connect(func(id: int) -> void: events.append("I:%d" % id))
	_expect(effects.play_spit(target, null) == -1, "missing payload rejected")
	_expect(effects.play_spit(Vector3(INF, 0, 0), food) == -1, "nonfinite spit target rejected")
	_expect(effects.play_spit(target, food, 0.0) == -1, "zero spit duration rejected")
	_expect(effects.play_spit(target, food, NAN) == -1, "nonfinite spit duration rejected")
	_expect(effects.play_spit(target, food, 0.6, -1.0) == -1, "negative arc rejected")
	_expect(effects.play_spit(target, food, 0.6, INF) == -1, "nonfinite arc rejected")
	_expect(effects.play_spit(source, food) == -1, "zero length spit rejected")
	_expect(effects.play_spit(target, food, 0.6, 1.2, 99) == -1, "invalid ingredient type rejected")
	var bad_root: Node = Node.new()
	var invalid_scene: PackedScene = PackedScene.new()
	invalid_scene.pack(bad_root)
	bad_root.free()
	_expect(effects.play_spit(target, invalid_scene) == -1, "non3D payload rejected")
	_expect(events.is_empty() and effects.get_active_spit_count() == 0, "invalid spit calls preserve state and events")
	var id: int = effects.play_spit(target, food, 0.3, 1.2, IngredientType.Type.SLIME)
	_expect(id > 0 and effects.get_active_spit_count() == 1, "typed food spit starts")
	var shot: SpitProjectile = effects._spits[id]
	_expect(shot.get_position_at(0.0).is_equal_approx(source), "spit starts at captured mouth")
	_expect(shot.get_position_at(1.0).is_equal_approx(target), "spit reaches full target beyond effect_range")
	_expect(shot.get_position_at(0.5).is_equal_approx(source.lerp(target, 0.5) + Vector3.UP * 1.2), "arc_height is midpoint lift over line")
	dragon.position += Vector3.UP * 5.0
	_expect(shot.get_position_at(0.0).is_equal_approx(source), "inflight shot not dragged by dragon lane changes")
	_expect(effects.play_fire(source + Vector3.LEFT * 4.0, 2.0), "fire can run alongside food")
	effects.stop_breath_effects()
	_expect(effects.get_active_spit_count() == 1 and effects.get_active_effect() == &"", "fire release preserves food already in flight")
	await create_timer(0.4).timeout
	_expect(effects.get_active_spit_count() == 0 and events == ["S:%d" % id, "F:%d" % id], "arrival completes once and frees food")
	events.clear()
	for type: int in IngredientType.NAMES:
		_expect(effects.play_spit(target, food, 2.0, 0.0, type) > 0, "all six existing food types accepted")
	_expect(effects.get_active_spit_count() == 6, "rapid successful spits coexist")
	effects.play_spit(target, food, 2.0)
	effects.play_spit(target, food, 2.0)
	_expect(effects.get_active_spit_count() == 8 and effects.play_spit(target, food) == -1, "concurrency cap rejects excess without replacement")
	effects.stop_effects()
	_expect(effects.get_active_spit_count() == 0 and events.size() == 16, "global stop interrupts each active shot once")
	var stopped: int = events.size()
	effects.stop_effects()
	_expect(events.size() == stopped, "idle global stop emits no spit events")
	var rebound: int = effects.play_spit(target, food, 2.0)
	effects.bind_dragon(dragon)
	_expect(effects.get_active_spit_count() == 0 and events.back() == "I:%d" % rebound, "rebind clears food transit")
	var newer_ids: Array[int] = []
	var callback: Callable = func(_old_id: int) -> void:
		newer_ids.append(effects.play_spit(target, food, 1.0))
	effects.play_spit(target, food, 2.0)
	effects.spit_interrupted.connect(callback, CONNECT_ONE_SHOT)
	effects.stop_effects()
	_expect(newer_ids.size() == 1 and effects._spits.has(newer_ids[0]), "newer cancellation callback shot survives old snapshot")
	effects.stop_effects()
	await process_frame
	var remaining_shots: int = 0
	for child: Node in effects.get_children():
		if child is SpitProjectile:
			remaining_shots += 1
	_expect(remaining_shots == 0, "global clear frees all shot nodes")
	effects.queue_free()
	dragon.queue_free()
