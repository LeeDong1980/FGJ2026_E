class_name PotElementView
extends Node3D
## 每層鍋子底下的發光圈與同色小燈，顯示這鍋食譜要用火（橘）還是冰（藍）煮。
## 換小龍時跟著新食譜變色，換小龍期間隱藏；正在煮時光圈跳動。

const FIRE_COLOR := Color(1.0, 0.45, 0.1)
const ICE_COLOR := Color(0.35, 0.75, 1.0)

@export var game_manager: GameManager
@export var lane_layout: LaneLayout
## 光圈的內外半徑（鍋子寬約 1.6）。
@export var ring_inner_radius: float = 0.7
@export var ring_outer_radius: float = 1.15
@export var light_energy: float = 5.0
@export var light_range: float = 3.0

var _rings: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	for i in lane_layout.lane_count:
		var anchor := lane_layout.position + lane_layout.get_anchor_position(i, &"PotAnchor")
		var torus := TorusMesh.new()
		torus.inner_radius = ring_inner_radius
		torus.outer_radius = ring_outer_radius
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = material
		ring.scale = Vector3(1.0, 0.15, 1.0)
		ring.position = anchor + Vector3.UP * 0.03
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)

		var light := OmniLight3D.new()
		light.position = anchor + Vector3.UP * 0.6
		light.omni_range = light_range
		light.light_energy = light_energy
		add_child(light)

		_rings.append(ring)
		_lights.append(light)
		_materials.append(material)
		# 放在遊戲場景裡時 GameManager 還沒建立鍋子，等它開場的 pot_changed 再上色。
		if i < game_manager.pots.size():
			_refresh(i)
	game_manager.pot_changed.connect(_refresh)


func _process(_delta: float) -> void:
	var cooking_lane := game_manager.dragon.current_lane if game_manager.is_cooking() else -1
	var pulse := 1.0 + 0.6 * sin(Time.get_ticks_msec() / 80.0)
	for i in _lights.size():
		_lights[i].light_energy = light_energy * (pulse if i == cooking_lane else 1.0)


func _refresh(lane: int) -> void:
	var pot := game_manager.get_pot(lane)
	var color := ICE_COLOR if pot.element == GameManager.Element.ICE else FIRE_COLOR
	_materials[lane].albedo_color = color
	_lights[lane].light_color = color
	_rings[lane].visible = pot.has_baby
	_lights[lane].visible = pot.has_baby
