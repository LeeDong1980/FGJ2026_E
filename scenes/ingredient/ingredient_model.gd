class_name IngredientModel
extends Node3D
## 暫時的食材模型：依種類上色的膠囊，加上名稱標籤。


func setup(type: IngredientType.Type) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = IngredientType.COLORS[type]
	%Mesh.material_override = material
	%NameLabel.text = IngredientType.NAMES[type]
