extends SceneTree
## GPU QA on the current main layout. Outputs outside the resource tree.

var _output: String = ""
var _viewport: SubViewport
var _preview: Node3D
var _density_only: bool = false
var _spit_only: bool = false


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--spit":
			_spit_only = true
		if argument == "--density":
			_density_only = true
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	call_deferred("_capture")


func _capture() -> void:
	if _output.is_empty():
		push_error("Supply -- --output=<absolute directory> for PNG captures.")
		quit(1)
		return
	DisplayServer.window_set_position(Vector2i(-20000, -20000))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1600, 900)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_preview = load("res://scenes/vfx/vfx_preview.tscn").instantiate() as Node3D
	_viewport.add_child(_preview)
	await create_timer(0.4).timeout
	var dragon: Node3D = _preview.get_node("Main/RedDragon") as Node3D
	var effects: DragonEffects = _preview.get_node("DragonEffects") as DragonEffects
	var target: Marker3D = _preview.get_node("Target") as Marker3D
	print("RENDERER ", RenderingServer.get_current_rendering_method())
	print("DRAGON ", dragon.global_position, " scale=", dragon.scale)
	if not effects.bind_dragon(dragon):
		push_error(effects.last_error)
		quit(2)
		return
	print("MOUTH ", (dragon.call(&"get_mouth_anchor") as Marker3D).global_position, " target=", target.global_position)
	# Keep the sampled fly pose constant so captures compare only VFX changes.
	dragon.call(&"stop_animation", true)
	for emitter_node: Node in effects.find_children("*", "GPUParticles3D", true, false):
		var emitter: GPUParticles3D = emitter_node as GPUParticles3D
		emitter.use_fixed_seed = true
		emitter.seed = 235
	if _spit_only:
		await _capture_spit(effects)
		quit(0)
		return
	if _density_only:
		await _capture_density(effects, target)
		quit(0)
		return
	effects.fire_particle_count = 0 # Historical width QA uses the shared count throughout.
	await _save("vfx_idle.png")
	# Original 0.35 radius / 96-particle budget, with the same pose and camera.
	effects.radius = 0.35
	effects.particle_count = 96
	effects.fire_particle_count = 0 # Preserve the ART-07 historical comparison.
	await _capture_effect(effects, target, false, "width_suction_before.png")
	await _capture_effect(effects, target, true, "width_fire_before.png")
	effects.particle_count = 192
	effects.set_effect_widths(0.1, 0.1)
	await _capture_effect(effects, target, false, "width_suction_min.png")
	await _capture_effect(effects, target, true, "width_fire_min.png")
	effects.set_effect_widths(4.0, 3.0)
	if not effects.play_suction(target.global_position, 2.0):
		push_error(effects.last_error)
		quit(3)
		return
	await create_timer(0.45).timeout
	await _save("vfx_suction.png")
	effects.play_fire(target.global_position, 2.0)
	await create_timer(0.45).timeout
	await _save("vfx_fire.png")
	effects.set_effect_widths(8.0, 8.0)
	await _capture_effect(effects, target, false, "width_suction_max.png")
	await _capture_effect(effects, target, true, "width_fire_max.png")
	effects.set_effect_widths(4.0, 3.0)
	# Also show the same target reached with an explicit, larger visual range.
	effects.effect_range = 12.0
	effects.play_fire(target.global_position, 2.0)
	await create_timer(0.45).timeout
	await _save("vfx_fire_range12.png")
	effects.stop_effects()
	effects.effect_range = 6.0
	await process_frame
	await process_frame
	await _save("vfx_stopped.png")
	print("VFX_GPU_CAPTURE_COMPLETE")
	quit(0)


func _capture_effect(effects: DragonEffects, target: Marker3D, fire: bool, filename: String) -> void:
	var duration: float = 3600.0 if _density_only else 2.0
	var accepted: bool = effects.play_fire(target.global_position, duration) if fire else effects.play_suction(target.global_position, duration)
	if not accepted:
		push_error(effects.last_error)
		quit(3)
		return
	await create_timer(0.45).timeout
	await _save(filename)


func _save(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var result: Error = _viewport.get_texture().get_image().save_png(_output.path_join(filename))
	print("PNG ", filename, " result=", result)
	if result != OK:
		quit(4)


func _capture_density(effects: DragonEffects, target: Marker3D) -> void:
	RenderingServer.viewport_set_measure_render_time(_viewport.get_viewport_rid(), true)
	effects.particle_count = 192
	effects.set_effect_widths(4.0, 3.0)
	effects.fire_particle_count = 384
	await _save("density_idle.png")
	for count: int in [192, 384, 512]:
		effects.set_fire_particle_count(count)
		await _capture_effect(effects, target, true, "density_fire_%d.png" % count)
		await _measure("fire_width3_count%d" % count)
	effects.fire_width = 8.0
	await _capture_effect(effects, target, true, "density_fire_512_width8.png")
	await _measure("fire_width8_count512")
	effects.set_effect_widths(4.0, 3.0)
	effects.fire_particle_count = 384
	await _capture_effect(effects, target, false, "density_suction_192.png")
	effects.stop_effects()
	await process_frame
	await process_frame
	await _save("density_stopped.png")
	print("VFX_DENSITY_CAPTURE_COMPLETE")


func _measure(label: String) -> void:
	var cpu_total: float = 0.0
	var gpu_total: float = 0.0
	var gpu_peak: float = 0.0
	for sample: int in range(120):
		await RenderingServer.frame_post_draw
		cpu_total += RenderingServer.viewport_get_measured_render_time_cpu(_viewport.get_viewport_rid())
		var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(_viewport.get_viewport_rid())
		gpu_total += gpu
		gpu_peak = maxf(gpu_peak, gpu)
	print("DENSITY_TIMING ", label, " samples=120 cpu_ms=", cpu_total / 120.0, " gpu_ms=", gpu_total / 120.0, " gpu_peak_ms=", gpu_peak)


func _capture_spit(effects: DragonEffects) -> void:
	var target: Marker3D = _preview.get_node("SpitTarget") as Marker3D
	var food: PackedScene = load("res://scenes/ingredient/ingredient_model.tscn")
	await _save("spit_idle.png")
	var id: int = effects.play_spit(target.global_position, food, 0.8, 1.2, IngredientType.Type.SLIME)
	print("SPIT_ID ", id, " full_target=", target.global_position)
	if id < 0:
		push_error(effects.last_error)
		quit(5)
		return
	await create_timer(0.4).timeout
	await _save("spit_mid_arc.png")
	await create_timer(0.6).timeout
	await _save("spit_arrived.png")
	effects.play_spit(target.global_position, food, 2.0, 1.2, IngredientType.Type.HUMAN)
	await create_timer(0.2).timeout
	effects.stop_effects()
	await process_frame
	await process_frame
	await _save("spit_cancelled.png")
	print("VFX_SPIT_CAPTURE_COMPLETE count=", effects.get_active_spit_count())
