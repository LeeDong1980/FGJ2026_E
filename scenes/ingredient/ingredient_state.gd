class_name IngredientState
extends RefCounted
## 隊伍中一個食材的資料。x 是沿著隊伍的位置，往右（靠近龍）為正。

var type: IngredientType.Type
var x: float


func _init(p_type: IngredientType.Type, p_x: float) -> void:
	type = p_type
	x = p_x
