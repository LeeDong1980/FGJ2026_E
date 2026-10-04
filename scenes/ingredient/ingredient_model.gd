class_name IngredientModel
extends Node3D
## 暫時的食材模型：依種類上色的膠囊，加上名稱標籤、噴火進度條與攻擊蓄力條；凍住時變冰藍色。

const BURN_BAR_WIDTH := 0.6
const ICE_COLOR := Color(0.6, 0.85, 1.0)

var _material: StandardMaterial3D
var _color: Color
var _name: String
var _frozen := false


func setup(type: IngredientType.Type) -> void:
	_material = StandardMaterial3D.new()
	_color = IngredientType.COLORS[type]
	_name = IngredientType.NAMES[type]
	_material.albedo_color = _color
	%Mesh.material_override = _material
	%NameLabel.text = _name


## 凍住時膠囊變冰藍色，名稱後面加「（凍）」。
func set_frozen(frozen: bool) -> void:
	if frozen == _frozen:
		return
	_frozen = frozen
	_material.albedo_color = _color.lerp(ICE_COLOR, 0.7) if frozen else _color
	%NameLabel.text = _name + ("（凍）" if frozen else "")


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
