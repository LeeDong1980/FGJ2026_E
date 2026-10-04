class_name LaneState
extends RefCounted
## 一層的資料。queue[0] 是隊伍最前端（最靠近龍）的食材。

var queue: Array[IngredientState] = []
## 隊伍有空位後累計的秒數，到生成間隔才產生新食材；隊伍滿時歸零。
var spawn_timer: float = 0.0
