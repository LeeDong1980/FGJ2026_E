class_name IngredientState
extends RefCounted
## 隊伍中一個食材的資料。x 是沿著隊伍的位置，往右（靠近龍）為正。

var type: IngredientType.Type
var x: float
## 被噴火燒的進度，0～1，到 1 就燒掉。中途停止噴火不會歸零。
var burn_progress: float = 0.0
## 攻擊蓄力進度，0～1，到 1 就攻擊龍並歸零。只有隊伍最前端的食材會蓄力。
var attack_progress: float = 0.0
## 這一次蓄滿需要的秒數，每次開始蓄力時重新隨機。
var attack_time: float = 0.0
## 被冰凍住的剩餘秒數，大於 0 表示凍住（不蓄力）。
var freeze_remaining: float = 0.0


func _init(p_type: IngredientType.Type, p_x: float) -> void:
	type = p_type
	x = p_x


func is_frozen() -> bool:
	return freeze_remaining > 0.0
