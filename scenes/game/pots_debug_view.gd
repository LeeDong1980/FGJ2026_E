class_name PotsDebugView
extends Node3D
## 測試用：在各層鍋子上方顯示禁止清單與進度。正式介面由 UI 負責。

@export var game_manager: GameManager
@export var lane_layout: LaneLayout
## 標籤在鍋子定位點上方的高度。
@export var label_height: float = 1.4

var _labels: Array[Label3D] = []


func _ready() -> void:
	for i in lane_layout.lane_count:
		var label := Label3D.new()
		label.position = lane_layout.position + lane_layout.get_anchor_position(i, &"PotAnchor") + Vector3.UP * label_height
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
