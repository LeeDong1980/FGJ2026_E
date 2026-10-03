class_name PotsDebugView
extends Node3D
## 測試用：在右平台放暫時的鍋子，上方顯示禁止清單與進度。正式介面由 UI 負責。

@export var game_manager: GameManager
@export var lane_layout: LaneLayout
@export var pot_x: float = 3.8
@export var label_height: float = 1.4

var _labels: Array[Label3D] = []


func _ready() -> void:
	for i in lane_layout.lane_count:
		var y := lane_layout.position.y + lane_layout.get_lane_position(i)
		var pot := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.45
		mesh.bottom_radius = 0.35
		mesh.height = 0.5
		pot.mesh = mesh
		pot.position = Vector3(pot_x, y + 0.25, 0.0)
		add_child(pot)

		var label := Label3D.new()
		label.position = Vector3(pot_x, y + label_height, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.outline_size = 10
		add_child(label)
		_labels.append(label)
	game_manager.pot_changed.connect(_refresh)
	game_manager.completed_count_changed.connect(func(count: int) -> void: print("完成鍋數：%d" % count))
	game_manager.cleared_count_changed.connect(func(count: int) -> void: print("清空次數：%d" % count))
	game_manager.game_won.connect(func() -> void: print("遊戲成功"))
	game_manager.game_lost.connect(func() -> void: print("遊戲失敗"))


func _refresh(lane: int) -> void:
	var pot := game_manager.get_pot(lane)
	if not pot.has_baby:
		_labels[lane].text = "換小龍中…"
		return
	var names: PackedStringArray = []
	for type in pot.forbidden:
		names.append(IngredientType.NAMES[type])
	_labels[lane].text = "不吃：%s\n%d / %d" % ["、".join(names), pot.count, pot.required]
