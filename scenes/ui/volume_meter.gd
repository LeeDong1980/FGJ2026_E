class_name VolumeMeter
extends Control
## 玩家 A 的音量條：即時音量、各層門檻線與層名，龍所在的層會亮起。
## 音量與門檻都是 0～1 的比例，0 在最下面。第 0 層是最低層。

const BAR_LEFT := 20.0
const BAR_WIDTH := 70.0
const BAR_PADDING := 8.0
const BG_COLOR := Color(1, 1, 1, 0.08)
const BORDER_COLOR := Color(1, 1, 1, 0.27)
const FILL_COLOR := Color("4cc3ff")
const LINE_COLOR := Color(1, 1, 1, 0.8)
const ACTIVE_COLOR := Color("ffd34d")
const LABEL_COLOR := Color(1, 1, 1, 0.53)
const THREE_LANE_NAMES: Array[String] = ["低", "中", "高"]

var level: float = 0.0:
	set(value):
		level = clampf(value, 0.0, 1.0)
		queue_redraw()
## 相鄰兩層的分界，由低到高排列，數量是層數 - 1。
var thresholds: PackedFloat32Array = [1.0 / 3.0, 2.0 / 3.0]:
	set(value):
		thresholds = value
		queue_redraw()
## 龍目前所在的層，-1 表示不顯示。
var current_lane: int = -1:
	set(value):
		current_lane = value
		queue_redraw()


func get_lane_count() -> int:
	return thresholds.size() + 1


func _draw() -> void:
	var bar := Rect2(BAR_LEFT, 0.0, BAR_WIDTH, size.y)
	draw_rect(bar, BG_COLOR)
	if current_lane >= 0 and current_lane < get_lane_count():
		draw_rect(_lane_rect(bar, current_lane), Color(ACTIVE_COLOR, 0.13))

	var fill_height := (bar.size.y - BAR_PADDING * 2.0) * level
	var fill := Rect2(bar.position.x + BAR_PADDING, bar.end.y - BAR_PADDING - fill_height,
			bar.size.x - BAR_PADDING * 2.0, fill_height)
	draw_rect(fill, FILL_COLOR)
	draw_rect(bar, BORDER_COLOR, false, 2.0)

	for threshold in thresholds:
		var y := _y_of(bar, threshold)
		draw_dashed_line(Vector2(bar.position.x - 10.0, y), Vector2(bar.end.x + 10.0, y), LINE_COLOR, 3.0, 8.0)

	var font := get_theme_default_font()
	for i in get_lane_count():
		var active := i == current_lane
		var font_size := 40 if active else 32
		var color := ACTIVE_COLOR if active else LABEL_COLOR
		var label := _lane_name(i)
		var center_y := _lane_rect(bar, i).get_center().y
		var baseline := Vector2(bar.end.x + 30.0, center_y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
		draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		if active:
			var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var marker_baseline := Vector2(baseline.x + label_width + 12.0,
					center_y + (font.get_ascent(24) - font.get_descent(24)) / 2.0)
			draw_string(font, marker_baseline, "◀ 龍", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ACTIVE_COLOR)


func _y_of(bar: Rect2, ratio: float) -> float:
	return bar.end.y - bar.size.y * ratio


## 第 lane 層在音量條上的範圍。
func _lane_rect(bar: Rect2, lane: int) -> Rect2:
	var low := 0.0 if lane == 0 else thresholds[lane - 1]
	var high := 1.0 if lane >= thresholds.size() else thresholds[lane]
	var top := _y_of(bar, high)
	return Rect2(bar.position.x, top, bar.size.x, _y_of(bar, low) - top)


func _lane_name(lane: int) -> String:
	if get_lane_count() == THREE_LANE_NAMES.size():
		return THREE_LANE_NAMES[lane]
	return str(lane + 1)
