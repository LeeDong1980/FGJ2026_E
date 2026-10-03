class_name PotState
extends RefCounted
## 一層鍋子與旁邊小龍的資料。小龍的要求只有禁止清單與需求數量。

var forbidden: Array[IngredientType.Type] = []
var required: int = 0
var count: int = 0
## 小龍是否到位。換小龍期間為 false，這時不能吐入食材。
var has_baby: bool = false


func is_forbidden(type: IngredientType.Type) -> bool:
	return forbidden.has(type)


## 換上一隻新的小龍，隨機產生禁止清單（不重複）與需求數量。
func randomize_request(forbidden_min: int, forbidden_max: int, required_min: int, required_max: int) -> void:
	var types: Array = IngredientType.Type.values()
	types.shuffle()
	forbidden.assign(types.slice(0, randi_range(forbidden_min, forbidden_max)))
	required = randi_range(required_min, required_max)
	count = 0
