class_name UIRoot
extends CanvasLayer
## UI 根節點：依遊戲狀態開關遊戲開始、遊玩狀態、遊戲結束三個介面，同一時間只顯示一個。
## UI 不決定遊戲流程：玩家按下的選項用 signal 通知出去，由遊戲流程呼叫 show_* 切換介面。

signal start_requested
signal next_level_requested
signal retry_requested

enum Screen { NONE, START, PLAYING, RESULT }

var current_screen: Screen = Screen.START

@onready var start_screen: StartScreen = %StartScreen
@onready var play_hud: PlayHud = %PlayHud
@onready var result_screen: ResultScreen = %ResultScreen


func _ready() -> void:
	start_screen.start_pressed.connect(start_requested.emit)
	result_screen.action_pressed.connect(_on_result_action_pressed)
	show_start()


## 關閉所有介面。
func hide_all() -> void:
	_show(Screen.NONE)


func show_start() -> void:
	_show(Screen.START)


func show_playing() -> void:
	_show(Screen.PLAYING)


## has_next_level 為 false 時，成功畫面的按鍵是「關閉遊戲」。
func show_result(success: bool, has_next_level: bool, completed: int, target: int, cleared: int, limit: int) -> void:
	result_screen.show_result(success, has_next_level, completed, target, cleared, limit)
	_show(Screen.RESULT)


func _show(screen: Screen) -> void:
	current_screen = screen
	start_screen.visible = screen == Screen.START
	play_hud.visible = screen == Screen.PLAYING
	result_screen.visible = screen == Screen.RESULT


func _on_result_action_pressed(action: ResultScreen.Action) -> void:
	match action:
		ResultScreen.Action.NEXT_LEVEL:
			next_level_requested.emit()
		ResultScreen.Action.RETRY:
			retry_requested.emit()
		ResultScreen.Action.QUIT:
			get_tree().quit()
