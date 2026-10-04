extends SceneTree
## 檢查食材模型匯入結果：列印節點、AnimationPlayer 動畫、材質與世界座標高度。用法：
## Godot --headless --path . -s res://scenes/ingredient/inspect_models.gd

const PATHS := [
	"res://Models/heroHuman/hero.glb",
	"res://Models/slime/Slime_glb.glb",
	"res://Models/bat/Bat_Level_1.fbx",
]


func _init() -> void:
	for p in PATHS:
		var scene := load(p) as PackedScene
		if scene == null:
			print("LOAD FAIL ", p)
			continue
		var root := scene.instantiate()
		get_root().add_child(root)
		print("== ", p)
		_dump(root, 1)
		for n in root.find_children("*", "AnimationPlayer", true, false):
			for a in (n as AnimationPlayer).get_animation_list():
				var anim := (n as AnimationPlayer).get_animation(a)
				print("  ANIM ", a, " len=", anim.length, " loop=", anim.loop_mode)
		for m in root.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var box := mi.global_transform * mi.get_aabb()
			print("  WORLD AABB ", mi.name, " pos=", box.position, " size=", box.size)
			for i in mi.get_surface_override_material_count():
				var mat := mi.get_active_material(i)
				print("  MAT ", i, " ", mat, " ", (mat as BaseMaterial3D).albedo_texture if mat is BaseMaterial3D else null)
		root.queue_free()
	quit()


func _dump(n: Node, d: int) -> void:
	print("  ".repeat(d), n.name, " (", n.get_class(), ")")
	if d < 5:
		for c in n.get_children():
			_dump(c, d + 1)
