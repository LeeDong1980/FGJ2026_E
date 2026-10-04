class_name GameSounds
extends Node
## 依 GameManager 的事件播放遊戲中的音效（Sound autoload 的 UI 音效庫）。
## 連線局 Client 的 GameManager 副本也會重現這些 signal，所以兩邊都聽得到。

@export var game_manager: GameManager


func _ready() -> void:
	game_manager.game_started.connect(Sound.play.bind(&"confirm"))
	game_manager.completed_count_changed.connect(func(count: int) -> void:
		if count > 0:
			Sound.play(&"notify"))
	game_manager.cleared_count_changed.connect(func(count: int) -> void:
		if count > 0:
			Sound.play(&"error"))
	game_manager.action_missed.connect(func(_lane: int, _reason: GameManager.MissReason) -> void:
		Sound.play(&"cancel"))
	game_manager.facing_changed.connect(func(_facing: GameManager.Facing) -> void:
		Sound.play(&"toggle"))
	game_manager.element_changed.connect(func(_element: GameManager.Element) -> void:
		Sound.play(&"toggle"))
	game_manager.score_changed.connect(func(_score: int, _gained: int, fast: bool) -> void:
		if fast:
			Sound.play(&"popup"))
	game_manager.game_won.connect(Sound.play.bind(&"confirm"))
	game_manager.game_lost.connect(Sound.play.bind(&"error"))
