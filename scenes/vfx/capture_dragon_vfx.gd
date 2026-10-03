extends SceneTree
## GPU QA on the current main layout. Outputs outside the resource tree.

var _output: String = ""
var _viewport: SubViewport
var _preview: Node3D


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
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
	await _save("vfx_idle.png")
	if not effects.play_suction(target.global_position, 2.0):
		push_error(effects.last_error)
		quit(3)
		return
	await create_timer(0.45).timeout
	await _save("vfx_suction.png")
	effects.play_fire(target.global_position, 2.0)
	await create_timer(0.45).timeout
	await _save("vfx_fire.png")
	# Also show the same target reached with an explicit, larger visual range.
	effects.effect_range = 12.0
	effects.play_fire(target.global_position, 2.0)
	await create_timer(0.45).timeout
	await _save("vfx_fire_range12.png")
	effects.stop_effects()
	await process_frame
	await process_frame
	await _save("vfx_stopped.png")
	print("VFX_GPU_CAPTURE_COMPLETE")
	quit(0)


func _save(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var result: Error = _viewport.get_texture().get_image().save_png(_output.path_join(filename))
	print("PNG ", filename, " result=", result)
	if result != OK:
		quit(4)
