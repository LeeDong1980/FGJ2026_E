class_name IngredientCharacter
extends Node3D
## 食材角色（正式模型）共用腳本：找到模型內的 AnimationPlayer，設定循環並提供播放接口。
## 各角色場景只需設定 Inspector 的動畫名稱，其餘共用。

## 待機動畫名稱（循環播放，場景載入後自動播放）。
@export var idle_animation: StringName = &"Idle"
## 移動動畫名稱（循環播放），留空表示沒有。
@export var move_animation: StringName = &"Walk"
## 一次性動作動畫名稱（播完回到待機），留空表示沒有。
@export var action_animation: StringName = &"Atk"
## 動畫混合時間（秒）。
@export var blend_time: float = 0.2
## 額外動畫庫（例如從模型擷取的片段），載入時併入模型的 AnimationPlayer，名稱可直接填入上面的欄位。
@export var extra_library: AnimationLibrary

var _player: AnimationPlayer


func _ready() -> void:
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null and extra_library and get_child_count() > 0:
		# 純骨架模型（例如精靈的 rig FBX）沒有 AnimationPlayer：建立在模型根節點下，軌道路徑相對於模型根節點。
		_player = AnimationPlayer.new()
		_player.name = "AnimationPlayer"
		_player.add_animation_library(&"", AnimationLibrary.new())
		get_child(0).add_child(_player)
	if _player == null:
		# 沒有動畫的靜態模型（例如矮人、獸人）不需要 AnimationPlayer；有指定動畫庫卻找不到才警告。
		if extra_library:
			push_warning("%s 找不到 AnimationPlayer" % name)
		return
	if extra_library:
		var lib := _player.get_animation_library(&"")
		for anim_name in extra_library.get_animation_list():
			if lib.has_animation(anim_name):
				lib.remove_animation(anim_name)
			lib.add_animation(anim_name, extra_library.get_animation(anim_name))
	_player.playback_default_blend_time = blend_time
	_set_loop(idle_animation, true)
	_set_loop(move_animation, true)
	_set_loop(action_animation, false)
	_player.animation_finished.connect(_on_animation_finished)
	play_idle()


## 取得模型內所有動畫名稱，供除錯與展示用。
func get_animation_names() -> PackedStringArray:
	return _player.get_animation_list() if _player else PackedStringArray()


func play_idle() -> void:
	_play(idle_animation)


func play_move() -> void:
	_play(move_animation if move_animation != &"" else idle_animation)


## 播放一次性動作，播完自動回到待機。
func play_action() -> void:
	if action_animation == &"":
		return
	_play(action_animation)


## 播放任意模型內動畫（不改變循環設定）。
func play_animation(anim_name: StringName) -> void:
	_play(anim_name)


func _play(anim_name: StringName) -> void:
	if _player and anim_name != &"" and _player.has_animation(anim_name):
		_player.play(anim_name)


func _set_loop(anim_name: StringName, loop: bool) -> void:
	if anim_name == &"" or not _player.has_animation(anim_name):
		return
	_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


func _on_animation_finished(finished: StringName) -> void:
	if finished == action_animation:
		play_idle()
