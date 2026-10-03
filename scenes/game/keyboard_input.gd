class_name KeyboardInput
extends Node
## 測試用鍵盤輸入：數字鍵 1／2／3 設定龍的目標層（1 是最低層）。

const LANE_ACTIONS: Array[StringName] = [&"lane_1", &"lane_2", &"lane_3"]

@export var dragon: Dragon


func _unhandled_input(event: InputEvent) -> void:
	for i in LANE_ACTIONS.size():
		if event.is_action_pressed(LANE_ACTIONS[i]):
			dragon.set_target_lane(i)
			get_viewport().set_input_as_handled()
			return
