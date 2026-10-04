class_name IngredientModel
extends Node3D
## 暫時的食材模型：依種類上色的膠囊，加上名稱標籤、噴火進度條與攻擊蓄力條。

const BURN_BAR_WIDTH := 0.6


func setup(type: IngredientType.Type) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = IngredientType.COLORS[type]
	%Mesh.material_override = material
	%NameLabel.text = IngredientType.NAMES[type]


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
