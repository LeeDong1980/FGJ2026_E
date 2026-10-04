class_name IngredientModel
extends Node3D
## 食材在遊戲中的外觀：有正式角色模型的種類（CHARACTER_SCENES）換成角色並播放動畫，
## 其他種類先用依種類上色的膠囊。名稱標籤、噴火進度條與攻擊蓄力條共用；凍住時變冰藍色、動畫停住。

const BURN_BAR_WIDTH := 0.6
const ICE_COLOR := Color(0.6, 0.85, 1.0)
## 有正式模型的食材種類 → 角色子場景（ART-20）。沒有列出的種類用膠囊。
const CHARACTER_SCENES: Dictionary = {
	IngredientType.Type.HUMAN: preload("res://scenes/ingredient/human_character.tscn"),
	IngredientType.Type.SLIME: preload("res://scenes/ingredient/slime_character.tscn"),
	IngredientType.Type.BAT: preload("res://scenes/ingredient/bat_character.tscn"),
}

## 角色顯示時的額外縮放（各角色子場景的比例未定案前，在這裡配合隊伍間隔調整）。沒列出的種類為 1。
const CHARACTER_SCALES: Dictionary = {
	IngredientType.Type.SLIME: 0.65,
	IngredientType.Type.BAT: 1.8,
}

## 食材本體（膠囊或角色模型）的整體放大倍數；名稱標籤與進度條跟著往上移，字不放大。
@export var body_scale: float = 2.0
## 角色模型轉向的角度（度）：模型預設面向 +Z（鏡頭），90 度是完全側面面向 +X（龍）。
## 預設 60 度是斜向，看得到臉和蝙蝠的翅膀。
@export var character_yaw: float = 60.0

var _material: StandardMaterial3D
var _frost: StandardMaterial3D
var _color: Color
var _name: String
var _frozen := false
var _moving := false
var _character: IngredientCharacter
var _anim_player: AnimationPlayer


func setup(type: IngredientType.Type) -> void:
	_color = IngredientType.COLORS[type]
	_name = IngredientType.NAMES[type]
	%NameLabel.text = _name
	for node: Node3D in [%NameLabel, %BurnBar, %AttackBar]:
		node.position.y *= body_scale
	if CHARACTER_SCENES.has(type):
		_character = (CHARACTER_SCENES[type] as PackedScene).instantiate() as IngredientCharacter
		_character.rotation.y = deg_to_rad(character_yaw)
		_character.scale = Vector3.ONE * float(CHARACTER_SCALES.get(type, 1.0)) * body_scale
		add_child(_character)
		_anim_player = _character.find_child("AnimationPlayer", true, false) as AnimationPlayer
		%Mesh.visible = false
	else:
		%Mesh.scale = Vector3.ONE * body_scale
		%Mesh.position.y *= body_scale
		_material = StandardMaterial3D.new()
		_material.albedo_color = _color
		%Mesh.material_override = _material


## 正在走路時播走路動畫，停下來播待機。
func set_moving(moving: bool) -> void:
	if moving == _moving or _character == null:
		return
	_moving = moving
	if moving:
		_character.play_move()
	else:
		_character.play_idle()


## 攻擊龍時播一次攻擊動畫。
func play_attack() -> void:
	if _character != null and not _frozen:
		_character.play_action()


## 凍住時變冰藍色、名稱後面加「（凍）」；角色模型的動畫同時停住。
func set_frozen(frozen: bool) -> void:
	if frozen == _frozen:
		return
	_frozen = frozen
	%NameLabel.text = _name + ("（凍）" if frozen else "")
	if _character == null:
		_material.albedo_color = _color.lerp(ICE_COLOR, 0.7) if frozen else _color
		return
	if _anim_player != null:
		_anim_player.speed_scale = 0.0 if frozen else 1.0
	for mesh: MeshInstance3D in _character.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _frost_material() if frozen else null


## progress 為 0～1，0 時隱藏進度條。進度條從左往右增長。
func set_burn_progress(progress: float) -> void:
	%BurnBar.visible = progress > 0.0
	%BurnBar.scale.x = maxf(progress, 0.001)
	%BurnBar.position.x = -BURN_BAR_WIDTH / 2.0 * (1.0 - progress)


## 攻擊蓄力條，用法同 set_burn_progress()。
func set_attack_progress(progress: float) -> void:
	%AttackBar.visible = progress > 0.0
	%AttackBar.scale.x = maxf(progress, 0.001)
	%AttackBar.position.x = -BURN_BAR_WIDTH / 2.0 * (1.0 - progress)


func _frost_material() -> StandardMaterial3D:
	if _frost == null:
		_frost = StandardMaterial3D.new()
		_frost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_frost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_frost.albedo_color = Color(ICE_COLOR, 0.55)
	return _frost
