extends SceneTree
## 依「食材模型通用動畫規範」（docs/ingredient_animation.md）為三種食材產生標準名稱動畫庫：Idle、Walk、Atk。
##   人類、史萊姆：把模型原有動畫複製並改成標準名稱。
##   蝙蝠：從 bat.glb 的 `Armature_006|Take 001|BaseLayer` 以 24 fps 逐格擷取片段（格數 = 時間 × 24）。
## 用法：Godot --headless --path . -s res://scenes/ingredient/build_ingredient_animations.gd

const FPS := 24.0

## 模型 -> 輸出路徑 -> 標準名稱 -> 來源（String＝整段複製原動畫；Array＝[起始格, 結束格] 擷取）
const SETS := [
	{
		"model": "res://Models/heroHuman/hero.glb",
		"output": "res://Models/heroHuman/human_animations.tres",
		"clips": {&"Idle": "Idle_001", &"Walk": "walk", &"Atk": "attack"},
	},
	{
		"model": "res://Models/slime/Slime_glb.glb",
		"output": "res://Models/slime/slime_animations.tres",
		"clips": {&"Idle": "Idle", &"Walk": "Scoot_Move", &"Atk": "Emote_Anger"},
	},
	{
		"model": "res://Models/bat/bat.glb",
		"output": "res://Models/bat/bat_animations.tres",
		"source": "Armature_006|Take 001|BaseLayer", # Godot 匯入時把 "." 換成 "_"
		"clips": {&"Idle": [2, 36], &"Walk": [2, 36], &"Atk": [76, 105]},
	},
	{
		"model": "res://Models/heroElf/elf.glb",
		"output": "res://Models/heroElf/elf_animations.tres",
		# 動畫在獨立 FBX（Mixamo 風格，動畫名 mixamo_com）；去掉作用在 metarig 根節點上的位移／旋轉軌道，避免改變朝向與位置。
		"clips": {
			&"Idle": {"scene": "res://Models/heroElf/Idle.fbx", "anim": "mixamo_com"},
			&"Walk": {"scene": "res://Models/heroElf/Walk.fbx", "anim": "mixamo_com"},
			&"Atk": {"scene": "res://Models/heroElf/Atk.fbx", "anim": "mixamo_com"},
		},
	},
]
func _init() -> void:
	for set_info in SETS:
		var root := (load(set_info["model"]) as PackedScene).instantiate()
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var lib := AnimationLibrary.new()
		for clip_name in set_info["clips"]:
			var spec: Variant = set_info["clips"][clip_name]
			var anim: Animation
			if spec is Dictionary:
				anim = _from_scene(spec["scene"], spec["anim"])
			elif spec is Array:
				anim = _extract(player.get_animation(set_info["source"]), spec[0] / FPS, spec[1] / FPS)
			else:
				anim = player.get_animation(spec).duplicate()
			lib.add_animation(clip_name, anim)
			print(set_info["model"].get_file(), " ", clip_name, " 長度=", anim.length)
		print("save ", set_info["output"], " -> ", ResourceSaver.save(lib, set_info["output"]))
		root.free()
	quit()


func _extract(src: Animation, t0: float, t1: float) -> Animation:
	var out := Animation.new()
	out.length = t1 - t0
	var steps := int(round((t1 - t0) * FPS))
	for i in src.get_track_count():
		var type := src.track_get_type(i)
		if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_SCALE_3D:
			push_warning("略過不支援的軌道類型 %d：%s" % [type, src.track_get_path(i)])
			continue
		var t := out.add_track(type)
		out.track_set_path(t, src.track_get_path(i))
		for s in steps + 1:
			var time := t0 + s / FPS
			var value: Variant
			match type:
				Animation.TYPE_POSITION_3D:
					value = src.position_track_interpolate(i, time)
				Animation.TYPE_ROTATION_3D:
					value = src.rotation_track_interpolate(i, time)
				_:
					value = src.scale_track_interpolate(i, time)
			out.track_insert_key(t, s / FPS, value)
	return out


## 從另一個 FBX 取動畫，並移除作用在根節點（路徑沒有骨頭名稱）的軌道。
func _from_scene(scene_path: String, anim_name: String) -> Animation:
	var root := (load(scene_path) as PackedScene).instantiate()
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var anim := player.get_animation(anim_name).duplicate() as Animation
	for t in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_path(t).get_subname_count() == 0:
			anim.remove_track(t)
	root.free()
	return anim