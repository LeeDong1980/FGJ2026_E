extends Node3D
## 食材角色展示：F6 執行。按鍵切換動畫：1 待機、2 移動、3 動作。

@onready var _characters: Array[IngredientCharacter] = [%Human, %Elf, %Slime, %Bat, %Dwarf]


func _ready() -> void:
	for c in _characters:
		print(c.name, " 動畫：", c.get_animation_names())


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	var key := (event as InputEventKey).keycode
	for c in _characters:
		match key:
			KEY_1:
				c.play_idle()
			KEY_2:
				c.play_move()
			KEY_3:
				c.play_action()

