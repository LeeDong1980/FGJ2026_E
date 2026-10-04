extends Node
## 暫時的遊戲流程（autoload 名稱 SceneFlow）：主選單 ↔ 遊戲。
## 各畫面只發 signal，這裡決定下一步並換場景。Samuel 的流程控制器（RoomManager 擴充）完成後併過去或換掉。

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const GAME := "res://scenes/game/main.tscn"


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	# 直接 F6 執行主選單時，第一個場景不會觸發 scene_changed
	_on_scene_changed.call_deferred()


func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU)


func go_to_game() -> void:
	_change_scene(GAME)


func _change_scene(path: String) -> void:
	# 從暫停選單離開時也要解除暫停
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)


func _on_scene_changed() -> void:
	var menu := get_tree().current_scene as MainMenu
	if menu != null and not menu.start_requested.is_connected(go_to_game):
		menu.start_requested.connect(go_to_game)
		menu.quit_requested.connect(get_tree().quit)
