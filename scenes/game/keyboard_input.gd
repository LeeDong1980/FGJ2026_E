class_name KeyboardInput
extends Node
## 測試用鍵盤輸入：數字鍵 1／2／3 設定龍的目標層（1 是最低層），J 吸、K 吐（按住 K 噴火）、4 轉頭、L 切換火／冰，Enter 開始或重新遊玩。

const LANE_ACTIONS: Array[StringName] = [&"lane_1", &"lane_2", &"lane_3"]

@export var dragon: Dragon
@export var game_manager: GameManager
## 關閉時玩家 1 的鍵（1／2／3 換層、4 轉頭）沒有作用（連線局房主坐玩家 2 時，這些由對方負責）。
@export var allow_player1_keys: bool = true


func _unhandled_input(event: InputEvent) -> void:
	for i in LANE_ACTIONS.size():
		if allow_player1_keys and event.is_action_pressed(LANE_ACTIONS[i]):
			dragon.set_target_lane(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"start_game"):
		game_manager.start_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"suck"):
		game_manager.suck()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"spit"):
		game_manager.spit_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"spit"):
		game_manager.spit_released()
		get_viewport().set_input_as_handled()
	elif allow_player1_keys and event.is_action_pressed(&"turn_head"):
		game_manager.turn_head()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"toggle_element"):
		game_manager.toggle_element()
		get_viewport().set_input_as_handled()
