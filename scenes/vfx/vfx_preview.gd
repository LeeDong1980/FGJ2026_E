extends Node3D
## F6 demonstration only; does not create food, damage, or InputMap actions.

var _floor_index: int = 1
var _alternate_target: bool = false

@onready var main: Node3D = $Main
@onready var effects: DragonEffects = %DragonEffects
@onready var target: Marker3D = %Target
@onready var _dragon: Node3D = main.get_node("RedDragon") as Node3D
@onready var _status: Label = %Status


func _ready() -> void:
	effects.bind_dragon(_dragon)
	_update_target()
	_status.text = "1: suction   2: fire   Space: stop   Tab: switch target   +/-: visual range   PgUp/PgDn: move dragon\nTarget ring is a VFX marker. Gameplay and action animations are not connected."


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


func _play(fire: bool) -> void:
	var accepted: bool = effects.play_fire(target.global_position, effects.default_duration) if fire else effects.play_suction(target.global_position, effects.default_duration)
	if not accepted:
		_status.text = "Effect unavailable: " + effects.last_error + "\n1 / 2: retry after the mouth anchor is ready."


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
