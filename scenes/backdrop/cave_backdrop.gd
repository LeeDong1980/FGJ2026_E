class_name CaveBackdrop
extends Sprite3D
## 龍洞穴的 2D 背景圖：每幀放在目前攝影機正前方的遠處、面向攝影機，並放大到蓋滿畫面，
## 所以永遠在 3D 場景的最後面，換攝影機（例如 GM-16 改用 PrototypePresentation 鏡頭）也不用調整。
## 構圖：左邊三層山洞隧道，中間是龍飛行的巨大山中洞穴與龍巢，右邊是上中下三個料理洞窟。

## 背景圖放在攝影機最遠可視距離（far）的這個比例處，確保比場景裡所有東西都遠。
@export_range(0.5, 0.99) var far_ratio: float = 0.95


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or texture == null:
		return
	var distance := camera.far * far_ratio
	var view := camera.global_transform
	global_transform = Transform3D(view.basis, view.origin - view.basis.z * distance)

	var viewport_size := get_viewport().get_visible_rect().size
	var view_height: float
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		view_height = camera.size
	else:
		view_height = 2.0 * distance * tan(deg_to_rad(camera.fov) / 2.0)
	var view_size := Vector2(view_height * viewport_size.x / viewport_size.y, view_height)
	# 等比例放大到蓋滿畫面，超出的部分裁掉。
	var texture_size := texture.get_size()
	pixel_size = maxf(view_size.x / texture_size.x, view_size.y / texture_size.y)
