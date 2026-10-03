class_name EffectsView
extends Node
## 依 GameManager 的事件播放龍的吸取與噴火特效（scenes/vfx/dragon_effects.tscn）。
## 吸：吞下食材或吸空時，從所在層隊伍最前端吸向嘴部。吐：噴火期間持續朝隊伍最前端噴，停止喊「吐」就停。

## 噴火一次播放的秒數，設得很長，實際長度由喊「吐」的時間決定。
const FIRE_HOLD_DURATION := 3600.0

@export var game_manager: GameManager
@export var dragon: Dragon
@export var lane_layout: LaneLayout
@export var effects: DragonEffects
@export var suction_duration: float = 0.6
## 目標點在隊伍定位點上方的高度（食材模型的中段）。
@export var target_height: float = 0.4


func _ready() -> void:
	effects.bind_dragon(dragon)
	game_manager.ingredient_swallowed.connect(func(lane: int, _ingredient: IngredientState) -> void: _play_suction(lane))
	game_manager.suck_missed.connect(_play_suction)
	game_manager.game_started.connect(effects.stop_effects)
	game_manager.game_won.connect(effects.stop_effects)
	game_manager.game_lost.connect(effects.stop_effects)


func _process(_delta: float) -> void:
	var firing := effects.get_active_effect() == &"fire"
	if game_manager.is_breathing_fire():
		var target := _target_position(dragon.current_lane)
		if firing:
			effects.set_target_global_position(target)
		else:
			effects.play_fire(target, FIRE_HOLD_DURATION)
	elif firing:
		effects.stop_effects()


func _play_suction(lane: int) -> void:
	effects.play_suction(_target_position(lane), suction_duration)


func _target_position(lane: int) -> Vector3:
	var local := lane_layout.get_anchor_position(lane, &"QueueFrontAnchor") + Vector3.UP * target_height
	return lane_layout.to_global(local)
