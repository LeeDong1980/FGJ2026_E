class_name LaneState
extends RefCounted
## 一層的資料。queue[0] 是隊伍最前端（最靠近龍）的食材。

var queue: Array[IngredientState] = []
