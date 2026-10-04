extends Node3D
## F6 preview only. This scene never subscribes to gameplay or microphone input.

@onready var dragon: Node3D = $RedDragon
var _camera: Camera3D
var _slider: HSlider
var _status: Label
var _immediate: CheckButton


func _ready() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.055, 0.07, 0.10)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.85, 1.0)
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -25, 0)
	sun.light_energy = 1.6
	add_child(sun)
	_camera = Camera3D.new()
	_camera.name = "HeadTurnCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 7.5
	add_child(_camera)
	_camera.position = Vector3(0, 2.0, 8)
	_camera.look_at(Vector3(0, 0.6, 0.9))
	_camera.current = true
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "Controls"
	add_child(canvas)
	var panel: PanelContainer = PanelContainer.new()
	canvas.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -166
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "擺頭：0 左側食材　｜　0.5 正前　｜　1 右側鍋子"
	column.add_child(title)
	_slider = HSlider.new()
	_slider.max_value = 1.0
	_slider.step = 0.001
	_slider.value = 0.5
	_slider.custom_minimum_size.y = 24
	_slider.value_changed.connect(_on_turn_changed)
	column.add_child(_slider)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	for value: float in [0.0, 0.5, 1.0]:
		var button: Button = Button.new()
		button.text = ["左", "正前", "右"][roundi(value * 2.0)]
		button.pressed.connect(func() -> void: _slider.value = value)
		row.add_child(button)
	var clips: OptionButton = OptionButton.new()
	for name: String in dragon.get_animation_names():
		clips.add_item(name)
		if name == "fly":
			clips.select(clips.item_count - 1)
	clips.item_selected.connect(func(index: int) -> void: dragon.play_animation(StringName(clips.get_item_text(index)), true))
	row.add_child(clips)
	var replay: Button = Button.new()
	replay.text = "重播"
	replay.pressed.connect(func() -> void: dragon.play_animation(StringName(clips.get_item_text(clips.selected)), true))
	row.add_child(replay)
	var stop: Button = Button.new()
	stop.text = "停止保留姿勢"
	stop.pressed.connect(func() -> void: dragon.stop_animation(true))
	row.add_child(stop)
	var reset: Button = Button.new()
	reset.text = "停止回中立"
	reset.pressed.connect(func() -> void: dragon.stop_animation(false))
	row.add_child(reset)
	_immediate = CheckButton.new()
	_immediate.text = "立即"
	row.add_child(_immediate)
	var close: CheckButton = CheckButton.new()
	close.text = "近看"
	close.toggled.connect(set_close_view)
	row.add_child(close)
	_status = Label.new()
	column.add_child(_status)
	_add_mouth_pointer()
	for side: float in [-1.0, 1.0]:
		var label: Label3D = Label3D.new()
		label.text = "左側食材" if side < 0.0 else "右側鍋子"
		label.position = Vector3(side * 2.2, 2.9, 0)
		label.font_size = 32
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)


func _process(_delta: float) -> void:
	_slider.set_value_no_signal(dragon.get_head_turn())
	var player: AnimationPlayer = dragon.get_node("Model/AnimationPlayer")
	_status.text = "目標 %.3f　目前 %.3f　動畫 %s（%s）　黃箭頭：嘴巴朝向" % [dragon.get_head_turn(), dragon.get_current_head_turn(), player.assigned_animation, "播放中" if player.is_playing() else "已停止"]


func _on_turn_changed(value: float) -> void:
	dragon.set_head_turn(value, _immediate.button_pressed)


func set_close_view(enabled: bool) -> void:
	_camera.size = 3.4 if enabled else 7.5
	_camera.look_at(Vector3(0, 1.1 if enabled else 0.6, 0.9))


func _add_mouth_pointer() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.YELLOW
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.13
	cylinder.bottom_radius = 0.13
	cylinder.height = 8.0
	var arrow: MeshInstance3D = MeshInstance3D.new()
	arrow.mesh = cylinder
	arrow.material_override = material
	arrow.rotation_degrees.x = -90
	arrow.position.z = -4
	dragon.get_mouth_anchor().add_child(arrow)
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = 0.6
	cone.height = 1.5
	var tip: MeshInstance3D = MeshInstance3D.new()
	tip.mesh = cone
	tip.material_override = material
	tip.rotation_degrees.x = -90
	tip.position.z = -8.5
	dragon.get_mouth_anchor().add_child(tip)
