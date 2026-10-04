class_name CaveBackdrop
extends MeshInstance3D
## 龍洞穴的 2D 背景圖：每幀放在目前攝影機正前方、面向攝影機，並放大到蓋滿畫面。
## 著色器把背景的深度寫成最遠，所以場景裡所有 3D 物件（包括穿過背景位置的大型龍模型）都會完整畫在它前面，
## 換攝影機（例如 PrototypePresentation 鏡頭）也不用調整。
## 構圖：左邊三層山洞隧道，中間是龍飛行的巨大山中洞穴與龍巢，右邊是上中下三個料理洞窟。

const BACKDROP_SHADER := preload("res://scenes/backdrop/cave_backdrop.gdshader")

@export var texture: Texture2D:
	set(value):
		texture = value
		if _material != null:
			_material.set_shader_parameter(&"backdrop_texture", texture)
## 背景放在攝影機 near 到 far 之間的這個比例處。深度一律當作最遠，所以位置只影響是否在可視範圍內。
@export_range(0.05, 0.95) var depth_ratio: float = 0.5

var _material: ShaderMaterial
var _quad := QuadMesh.new()


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = BACKDROP_SHADER
	_material.set_shader_parameter(&"backdrop_texture", texture)
	mesh = _quad
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or texture == null:
		return
	var distance := lerpf(camera.near, camera.far, depth_ratio)
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
	var cover := maxf(view_size.x / texture_size.x, view_size.y / texture_size.y)
	_quad.size = texture_size * cover
