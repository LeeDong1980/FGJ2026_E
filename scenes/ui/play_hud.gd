class_name PlayHud
extends Control
## 遊玩狀態介面。只負責顯示，資料由遊戲機制與麥克風輸入呼叫下列方法更新。

const POT_INFO_SCENE := preload("res://scenes/ui/pot_info.tscn")
## 剩下幾次清空就失敗時，清空次數開始閃爍。
const CLEARED_WARNING_LEFT := 1
## 剩餘秒數低於這個值時，倒數文字變紅色。
const COUNTDOWN_WARNING_SECONDS := 10.0
const COUNTDOWN_WARNING_COLOR := Color("ff7a7d")

## 鍋子資訊底部到鍋子錨點的距離（像素）。
@export var pot_info_gap: float = 12.0

var _pot_infos: Array[PotInfo] = []
var _camera: Camera3D
## 各層鍋子資訊要跟隨的世界座標。
var _pot_anchors: Array[Vector3] = []
var _cleared_warning := false
var _word_tween: Tween

@onready var _completed_label: Label = %CompletedLabel
@onready var _cleared_label: Label = %ClearedLabel
@onready var _pot_container: Control = %PotInfoContainer
@onready var _volume_meter: VolumeMeter = %VolumeMeter
@onready var _word_label: Label = %WordLabel
@onready var _countdown_panel: PanelContainer = %CountdownPanel
@onready var _countdown_label: Label = %CountdownLabel


func _process(_delta: float) -> void:
	_layout_pot_infos()
	if _cleared_warning:
		_cleared_label.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.5)


## 依層數建立各層的鍋子資訊，並把音量門檻設為平均分段。
func setup_lanes(lane_count: int) -> void:
	for info in _pot_infos:
		info.queue_free()
	_pot_infos.clear()
	for i in lane_count:
		var info := POT_INFO_SCENE.instantiate() as PotInfo
		_pot_container.add_child(info)
		_pot_infos.append(info)
	var thresholds := PackedFloat32Array()
	for i in range(1, lane_count):
		thresholds.append(float(i) / lane_count)
	_volume_meter.thresholds = thresholds
	_volume_meter.current_lane = -1


## 讓各層鍋子資訊跟著鍋子在畫面上的位置。沒有設定時，鍋子資訊排在畫面右側。
func set_pot_anchors(camera: Camera3D, world_positions: Array[Vector3]) -> void:
	_camera = camera
	_pot_anchors = world_positions


func set_pot(lane: int, forbidden: Array, have: int, need: int) -> void:
	_pot_infos[lane].set_forbidden(forbidden)
	_pot_infos[lane].set_progress(have, need)


func set_pot_progress(lane: int, have: int, need: int) -> void:
	_pot_infos[lane].set_progress(have, need)


func flash_pot_completed(lane: int) -> void:
	_pot_infos[lane].flash_completed()


func flash_pot_cleared(lane: int) -> void:
	_pot_infos[lane].flash_cleared()


func set_completed(completed: int, target: int) -> void:
	_completed_label.text = "完成 %d / %d" % [completed, target]


func set_cleared(cleared: int, limit: int) -> void:
	_cleared_label.text = "✕ 清空 %d / %d" % [cleared, limit]
	_cleared_warning = limit - cleared == CLEARED_WARNING_LEFT
	if not _cleared_warning:
		_cleared_label.modulate.a = 1.0


func set_current_lane(lane: int) -> void:
	for i in _pot_infos.size():
		_pot_infos[i].set_active(i == lane)
	_volume_meter.current_lane = lane


## level 是 0～1 的音量比例。
func set_volume(level: float) -> void:
	_volume_meter.level = level


## 相鄰兩層的音量分界，0～1，由低到高排列，數量是層數 - 1。
func set_volume_thresholds(thresholds: PackedFloat32Array) -> void:
	_volume_meter.thresholds = thresholds


## 顯示玩家 B 最後辨識到的字音，剛辨識到時放大並閃一下，之後變淡。
func show_word(word: String) -> void:
	_word_label.text = word
	_word_label.pivot_offset = _word_label.size / 2.0
	if _word_tween:
		_word_tween.kill()
	_word_label.scale = Vector2.ONE * 1.35
	_word_label.modulate.a = 1.0
	_word_tween = create_tween().set_parallel()
	_word_tween.tween_property(_word_label, ^"scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_word_tween.tween_property(_word_label, ^"modulate:a", 0.45, 1.2).set_delay(0.3)


## 顯示倒數計時。正式遊戲不限時間，目前只有測試用的控制中心會呼叫。
func show_time_left(seconds: float) -> void:
	var whole := ceili(maxf(seconds, 0.0))
	_countdown_label.text = "剩餘時間 %d:%02d" % [floori(whole / 60.0), whole % 60]
	if seconds <= COUNTDOWN_WARNING_SECONDS:
		_countdown_label.add_theme_color_override(&"font_color", COUNTDOWN_WARNING_COLOR)
	else:
		_countdown_label.remove_theme_color_override(&"font_color")
	_countdown_panel.visible = true


func hide_time_left() -> void:
	_countdown_panel.visible = false


func _layout_pot_infos() -> void:
	var count := _pot_infos.size()
	for i in count:
		var info := _pot_infos[i]
		var bottom_center: Vector2
		if _camera != null and i < _pot_anchors.size() and not _camera.is_position_behind(_pot_anchors[i]):
			bottom_center = _camera.unproject_position(_pot_anchors[i]) - Vector2(0.0, pot_info_gap)
		else:
			# 排在畫面右側、上方資訊列與右下玩家 B 面板之間，最高層在最上面。
			var area := _pot_container.size
			var top := 200.0
			var bottom := area.y - 320.0
			bottom_center = Vector2(area.x - 220.0, bottom - (bottom - top) / count * i)
		info.position = bottom_center - Vector2(info.size.x / 2.0, info.size.y)
