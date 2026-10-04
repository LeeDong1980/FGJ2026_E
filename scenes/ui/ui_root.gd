class_name UIRoot
extends CanvasLayer
## UI 根節點：依遊戲狀態開關遊玩狀態、遊戲結束兩個介面，同一時間只顯示一個。主選單是獨立場景（scenes/main_menu/main_menu.tscn）。
## UI 不決定遊戲流程：玩家按下的選項用 signal 通知出去，由遊戲流程呼叫 show_* 切換介面。

signal next_level_requested
signal retry_requested
## 結果畫面按「回主選單」
signal back_requested

enum Screen { NONE, PLAYING, RESULT }

var current_screen: Screen = Screen.NONE

@onready var play_hud: PlayHud = %PlayHud
@onready var result_screen: ResultScreen = %ResultScreen


func _ready() -> void:
	result_screen.action_pressed.connect(_on_result_action_pressed)
	hide_all()


## 關閉所有介面。
func hide_all() -> void:
	_show(Screen.NONE)


func show_playing() -> void:
	_show(Screen.PLAYING)


## has_next_level 為 false 時，成功畫面的按鍵是「回主選單」。
func show_result(success: bool, has_next_level: bool, completed: int, target: int, cleared: int, limit: int) -> void:
	result_screen.show_result(success, has_next_level, completed, target, cleared, limit)
	_show(Screen.RESULT)


func _show(screen: Screen) -> void:
	current_screen = screen
	play_hud.visible = screen == Screen.PLAYING
	result_screen.visible = screen == Screen.RESULT


func _on_result_action_pressed(action: ResultScreen.Action) -> void:
	match action:
		ResultScreen.Action.NEXT_LEVEL:
			next_level_requested.emit()
		ResultScreen.Action.RETRY:
			retry_requested.emit()
		ResultScreen.Action.MAIN_MENU:
			back_requested.emit()
