extends Node3D
## F6 demonstration only; food replicas are visual, with no gameplay mutation.

const FOOD_SCENE: PackedScene = preload("res://scenes/ingredient/ingredient_model.tscn")

var _floor_index: int = 1
var _alternate_target: bool = false
var _playback_error: String = ""
var _payload_type: int = 0

@onready var main: Node3D = $Main
@onready var effects: DragonEffects = %DragonEffects
@onready var target: Marker3D = %Target
@onready var spit_target: Marker3D = %SpitTarget
@onready var _dragon: Node3D = main.get_node("RedDragon") as Node3D
@onready var _status: Label = %Status


func _ready() -> void:
	effects.bind_dragon(_dragon)
	_update_target()
	_refresh_status()


func _process(_delta: float) -> void:
	_refresh_status()


func _refresh_status() -> void:
	var text: String = "1：吸取　2：噴火　3：吐食材草案　空白：全部停止　Tab：切換目標　PageUp/Down：換層\nQ/A：吸取加寬／縮窄　W/S：噴火加寬／縮窄　＋/－：調整射程\n吸取寬 %.2f　噴火寬 %.2f　射程 %.1f（世界單位；寬度為完整直徑）\nE/D：噴火粒子增減 32　R：沿用共用粒子數　噴火主粒子 %d／吸取 %d\nT：切換吐出種類（%s）　飛行食材 %d；胃袋吐食材僅視覺草案，未接玩法。" % [effects.suction_width, effects.fire_width, effects.effect_range, effects.get_fire_particle_count(), clampi(effects.particle_count, 8, 512), IngredientType.NAMES[_payload_type], effects.get_active_spit_count()]
	if not _playback_error.is_empty():
		text += "\n無法播放特效：" + _playback_error
	if _status.text != text:
		_status.text = text


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_1:
			_play(false)
		KEY_2:
			_play(true)
		KEY_3:
			var shot_id: int = effects.play_spit(spit_target.global_position, FOOD_SCENE, 0.6, 1.2, _payload_type)
			_playback_error = "" if shot_id >= 0 else effects.last_error
		KEY_T:
			_payload_type = (_payload_type + 1) % IngredientType.NAMES.size()
		KEY_SPACE:
			effects.stop_effects()
			_playback_error = ""
		KEY_TAB:
			_alternate_target = not _alternate_target
			_update_target()
		KEY_PAGEUP:
			_move_floor(1)
		KEY_PAGEDOWN:
			_move_floor(-1)
		KEY_EQUAL, KEY_KP_ADD:
			effects.effect_range = minf(20.0, effects.effect_range + 1.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			effects.effect_range = maxf(1.0, effects.effect_range - 1.0)
		KEY_Q:
			effects.suction_width += 0.25
		KEY_A:
			effects.suction_width = maxf(DragonEffects.MIN_EFFECT_WIDTH, effects.suction_width - 0.25)
		KEY_W:
			effects.fire_width += 0.25
		KEY_S:
			effects.fire_width = maxf(DragonEffects.MIN_EFFECT_WIDTH, effects.fire_width - 0.25)
		KEY_E:
			effects.set_fire_particle_count(effects.get_fire_particle_count() + 32)
		KEY_D:
			effects.set_fire_particle_count(maxi(8, effects.get_fire_particle_count() - 32))
		KEY_R:
			effects.set_fire_particle_count(0)


func _play(fire: bool) -> void:
	var accepted: bool = effects.play_fire(target.global_position, effects.default_duration) if fire else effects.play_suction(target.global_position, effects.default_duration)
	_playback_error = "" if accepted else effects.last_error


func _move_floor(direction: int) -> void:
	var previous: int = _floor_index
	_floor_index = clampi(_floor_index + direction, 0, 2)
	effects.stop_effects()
	_dragon.position.y += float(_floor_index - previous) * 5.0
	_update_target()


func _update_target() -> void:
	var floor_names: Array[StringName] = [&"LowFloor", &"MiddleFloor", &"HighFloor"]
	var floor_node: Node3D = main.get_node("Floors").get_node(NodePath(floor_names[_floor_index])) as Node3D
	var front: Marker3D = floor_node.call(&"get_anchor", &"QueueFrontAnchor") as Marker3D
	target.global_position = front.global_position + Vector3(-1.4 if _alternate_target else 0.0, 1.0, 0.0)
	var pot: Marker3D = floor_node.call(&"get_anchor", &"PotAnchor") as Marker3D
	spit_target.global_position = pot.global_position + Vector3.UP * 0.9
	effects.set_target_global_position(target.global_position)
