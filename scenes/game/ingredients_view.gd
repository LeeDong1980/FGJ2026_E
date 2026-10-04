class_name IngredientsView
extends Node3D
## 依 GameManager 的資料顯示所有層的食材模型；走路時播走路動畫，攻擊時播攻擊動畫。

@export var game_manager: GameManager
@export var lane_layout: LaneLayout
@export var model_scene: PackedScene = preload("res://scenes/ingredient/ingredient_model.tscn")

## IngredientState -> 模型節點
var _models: Dictionary = {}
## IngredientState -> 層的編號
var _lanes: Dictionary = {}


func _ready() -> void:
	game_manager.ingredient_spawned.connect(_on_ingredient_spawned)
	game_manager.ingredient_removed.connect(_on_ingredient_removed)
	game_manager.ingredient_attacked.connect(func(_lane: int, ingredient: IngredientState, _hit: bool) -> void:
		if _models.has(ingredient):
			_models[ingredient].play_attack())


func _process(_delta: float) -> void:
	for ingredient: IngredientState in _models:
		# 隊伍沿著房間定位點的高度與深度排列。
		var anchor := lane_layout.get_anchor_position(_lanes[ingredient], &"QueueFrontAnchor")
		var spot := lane_layout.position + Vector3(ingredient.x, anchor.y, anchor.z)
		_models[ingredient].set_moving(not spot.is_equal_approx(_models[ingredient].position))
		_models[ingredient].position = spot
		_models[ingredient].set_burn_progress(ingredient.burn_progress)
		_models[ingredient].set_attack_progress(ingredient.attack_progress)
		_models[ingredient].set_frozen(ingredient.is_frozen())


func _on_ingredient_spawned(lane: int, ingredient: IngredientState) -> void:
	var model := model_scene.instantiate() as IngredientModel
	add_child(model)
	model.setup(ingredient.type)
	_models[ingredient] = model
	_lanes[ingredient] = lane


func _on_ingredient_removed(_lane: int, ingredient: IngredientState) -> void:
	_models[ingredient].queue_free()
	_models.erase(ingredient)
	_lanes.erase(ingredient)
