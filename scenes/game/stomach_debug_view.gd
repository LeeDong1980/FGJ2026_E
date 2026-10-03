class_name StomachDebugView
extends Node3D
## 測試用：在龍的上方顯示胃袋裡的食材。

@export var game_manager: GameManager
@export var dragon: Dragon
@export var model_scene: PackedScene = preload("res://scenes/ingredient/ingredient_model.tscn")
## 相對龍的位置。
@export var offset: Vector3 = Vector3(0.0, 2.5, 1.5)

var _model: IngredientModel


func _ready() -> void:
	game_manager.stomach_changed.connect(_on_stomach_changed)


func _process(_delta: float) -> void:
	global_position = dragon.global_position + offset


func _on_stomach_changed(ingredient: IngredientState) -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	if ingredient != null:
		_model = model_scene.instantiate() as IngredientModel
		add_child(_model)
		_model.setup(ingredient.type)
