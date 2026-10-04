class_name GameSounds
extends Node
## 依 GameManager 的事件播放遊戲中的音效（Sound autoload 的 UI 音效庫）。
## 連線局 Client 的 GameManager 副本也會重現這些 signal，所以兩邊都聽得到。

## 噴火開始時播的噴火聲（單次，噴得比聲音短時淡出）。
const FIRE_SOUND := "res://SFX/Dragon/dragon_fire.wav"
## 冰息期間循環播放的暴風雪聲（匯入設定已開循環）。
const ICE_SOUND := "res://SFX/Dragon/ice_breath_loop.wav"
## 停止噴吐或換元素時，前一個聲音淡出的秒數。
const BREATH_FADE_TIME := 0.25

@export var game_manager: GameManager

var _fire_player: AudioStreamPlayer
var _ice_player: AudioStreamPlayer
## 目前在播的噴吐聲：&"fire"、&"ice"，沒在噴是 &""。
var _breath: StringName = &""
## 正在淡出的聲音 → 淡出用的 Tween。
var _fades: Dictionary[AudioStreamPlayer, Tween] = {}


func _ready() -> void:
	_fire_player = _create_breath_player([FIRE_SOUND])
	_ice_player = _create_breath_player([ICE_SOUND])
	game_manager.game_started.connect(Sound.play.bind(&"confirm"))
	game_manager.ingredient_swallowed.connect(func(_lane: int, _ingredient: IngredientState) -> void:
		Sound.play(&"suck"))
	game_manager.dragon_stunned.connect(Sound.play.bind(&"stunned"))
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


func _process(_delta: float) -> void:
	var breath: StringName = &""
	if game_manager.is_breathing_fire() or game_manager.is_cooking():
		breath = &"ice" if game_manager.element == GameManager.Element.ICE else &"fire"
	if breath == _breath:
		return
	if _breath != &"":
		_fade_out(_player_for(_breath))
	_breath = breath
	if breath != &"":
		var player := _player_for(breath)
		if _fades.has(player):
			_fades[player].kill()
			_fades.erase(player)
		player.volume_db = 0.0
		player.play()


func _player_for(breath: StringName) -> AudioStreamPlayer:
	return _ice_player if breath == &"ice" else _fire_player


func _fade_out(player: AudioStreamPlayer) -> void:
	if not player.playing:
		return
	var tween := create_tween()
	tween.tween_property(player, ^"volume_db", -40.0, BREATH_FADE_TIME)
	tween.tween_callback(player.stop)
	tween.tween_callback(func() -> void: _fades.erase(player))
	_fades[player] = tween


func _create_breath_player(paths: Array[String]) -> AudioStreamPlayer:
	var randomizer := AudioStreamRandomizer.new()
	randomizer.random_pitch = 1.05
	for path in paths:
		randomizer.add_stream(-1, load(path) as AudioStream)
	var player := AudioStreamPlayer.new()
	player.stream = randomizer
	player.bus = AudioSettings.SFX
	add_child(player)
	return player
