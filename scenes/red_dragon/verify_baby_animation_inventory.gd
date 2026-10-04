extends SceneTree
## Read-only inventory: cross-checks source GLB JSON and Godot imported nodes.

const SOURCE: String = "res://Models/dragonBabies/baby_dragon.glb"
var _skeletons: int = 0
var _players: int = 0
var _skinned_meshes: int = 0
var _clips: PackedStringArray = []


func _initialize() -> void:
	var file: FileAccess = FileAccess.open(SOURCE, FileAccess.READ)
	if file == null or file.get_32() != 0x46546c67:
		push_error("Baby source is missing or not GLB.")
		quit(1)
		return
	file.seek(12)
	var length: int = file.get_32()
	if file.get_32() != 0x4e4f534a:
		push_error("Baby GLB first chunk is not JSON.")
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	file.close()
	var skins: Array = data.get("skins", [])
	var animations: Array = data.get("animations", [])
	print("BABY_SOURCE path=", SOURCE, " skins=", skins.size(), " animations=", animations.size(), " meshes=", data.get("meshes", []).size())
	var model: Node = (load(SOURCE) as PackedScene).instantiate()
	_walk(model, str(model.name))
	model.free()
	print("BABY_IMPORTED skeletons=", _skeletons, " animation_players=", _players, " skinned_meshes=", _skinned_meshes, " clips=", _clips)
	print("BABY_INVENTORY_RESULT walk_idle_available=", _skeletons > 0 and not _clips.is_empty())
	quit()


func _walk(node: Node, path: String) -> void:
	print("BABY_NODE path=", path, " type=", node.get_class())
	if node is Skeleton3D:
		_skeletons += 1
		print("BABY_BONES ", (node as Skeleton3D).get_bone_count())
	if node is AnimationPlayer:
		_players += 1
		_clips.append_array((node as AnimationPlayer).get_animation_list())
	if node is MeshInstance3D and (node as MeshInstance3D).skin != null:
		_skinned_meshes += 1
	for child: Node in node.get_children():
		_walk(child, path + "/" + str(child.name))
