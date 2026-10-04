class_name EffectsView
extends Node
## 依 GameManager 的事件播放龍的吸取與噴火特效（scenes/vfx/dragon_effects.tscn）。
## 吸：吞下食材時，從所在層隊伍最前端吸向嘴部。吐：噴火期間持續朝隊伍最前端噴（對已滿的鍋子煮時改朝鍋子），停止喊「吐」就停。
## 沒有效果的吸或吐不播特效（原因由 ActionHintBanner 在畫面上方提示）。
## 元素是冰時改播冰息特效（play_ice），噴吐途中切換元素會立刻換成另一種。

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
	game_manager.game_started.connect(effects.stop_effects)
	game_manager.game_won.connect(effects.stop_effects)
	game_manager.game_lost.connect(effects.stop_effects)


func _process(_delta: float) -> void:
	var active := effects.get_active_effect()
	var firing := active == &"fire" or active == &"ice"
	var wanted: StringName = &"ice" if game_manager.element == GameManager.Element.ICE else &"fire"
	var target: Vector3
	var breathing := true
	if game_manager.is_breathing_fire() and game_manager.get_front(dragon.current_lane) != null:
		target = _target_position(dragon.current_lane)
	elif game_manager.is_cooking():
		target = _anchor_position(dragon.current_lane, &"PotAnchor")
	else:
		breathing = false
	if breathing:
		if active == wanted:
			effects.set_target_global_position(target)
		elif wanted == &"ice":
			effects.play_ice(target, FIRE_HOLD_DURATION)
		else:
			effects.play_fire(target, FIRE_HOLD_DURATION)
	elif firing:
		effects.stop_effects()


func _play_suction(lane: int) -> void:
	effects.play_suction(_target_position(lane), suction_duration)


func _target_position(lane: int) -> Vector3:
	return _anchor_position(lane, &"QueueFrontAnchor")


func _anchor_position(lane: int, anchor: StringName) -> Vector3:
	var local := lane_layout.get_anchor_position(lane, anchor) + Vector3.UP * target_height
	return lane_layout.to_global(local)
