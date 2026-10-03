extends Node3D
## F6 demonstration only; does not create food, damage, or InputMap actions.

var _floor_index: int = 1
var _alternate_target: bool = false
var _playback_error: String = ""

@onready var main: Node3D = $Main
@onready var effects: DragonEffects = %DragonEffects
@onready var target: Marker3D = %Target
@onready var _dragon: Node3D = main.get_node("RedDragon") as Node3D
@onready var _status: Label = %Status


func _ready() -> void:
	effects.bind_dragon(_dragon)
	_update_target()
	_refresh_status()


func _process(_delta: float) -> void:
	_refresh_status()


func _refresh_status() -> void:
	var text: String = "1：吸取　2：噴火　空白：停止　Tab：切換目標　PageUp/Down：換層\nQ/A：吸取加寬／縮窄　W/S：噴火加寬／縮窄　＋/－：調整射程\n吸取寬 %.2f　噴火寬 %.2f　射程 %.1f（世界單位；寬度為完整直徑）\n圓環是特效目標；此處「吐」指噴火，未串接胃袋吐食材。" % [effects.suction_width, effects.fire_width, effects.effect_range]
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
	effects.set_target_global_position(target.global_position)
