class_name ActiveBuffsPanel
extends Control

const LANDMARK_TEXTURE = preload("res://assets/generated/map_landmarks_v1.png")
const LANDMARK_FRAME_SIZE := Vector2(543.0, 724.0)
const LANDMARK_FRAMES := {"altar": 0, "obelisk": 1, "tree": 2, "portal": 3}
const LANDMARK_COLORS := {
	"altar": Color("ff5c61"),
	"obelisk": Color("69ddff"),
	"tree": Color("58e3d0"),
	"portal": Color("c36cff"),
}

var content_box: VBoxContainer
var rows_by_id: Dictionary = {}
var active_ids: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	content_box = VBoxContainer.new()
	content_box.name = "Content"
	content_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_box.add_theme_constant_override("separation", 6)
	content_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_box)


func set_buffs(buffs: Array[Dictionary]) -> void:
	var next_ids: Array[String] = []
	for buff in buffs:
		next_ids.append(str(buff.get("id", "buff")))
	if next_ids != active_ids:
		_rebuild_rows(buffs)
	else:
		for buff in buffs:
			_update_row(buff)
	visible = not buffs.is_empty()


func highlight_buff(buff_id: String) -> void:
	var row_data: Dictionary = rows_by_id.get(buff_id, {})
	var row := row_data.get("row") as Control
	if not is_instance_valid(row):
		return
	row.pivot_offset = row.size * 0.5
	row.scale = Vector2.ONE * 1.06
	row.modulate.a = 0.58
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(row, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(row, "modulate:a", 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func displayed_buff_ids() -> Array[String]:
	return active_ids.duplicate()


func _rebuild_rows(buffs: Array[Dictionary]) -> void:
	for child in content_box.get_children():
		child.queue_free()
	rows_by_id.clear()
	active_ids.clear()
	for buff in buffs:
		var buff_id := str(buff.get("id", "buff"))
		active_ids.append(buff_id)
		var row := _create_row(buff_id)
		content_box.add_child(row)
		_update_row(buff)


func _create_row(buff_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Buff_" + buff_id
	row.custom_minimum_size = Vector2(0.0, 46.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(36.0, 44.0)
	icon.texture = _landmark_icon(buff_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color("f0e8ff"))
	text_box.add_child(name_label)
	var effect_line := HBoxContainer.new()
	effect_line.name = "EffectLine"
	text_box.add_child(effect_line)
	var effect_label := Label.new()
	effect_label.name = "Effect"
	effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	effect_label.add_theme_font_size_override("font_size", 10)
	effect_label.add_theme_color_override("font_color", Color("bcb1c9"))
	effect_line.add_child(effect_label)
	var time_label := Label.new()
	time_label.name = "Time"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.add_theme_font_size_override("font_size", 11)
	time_label.add_theme_color_override("font_color", Color(LANDMARK_COLORS.get(buff_id, Color("d89cff"))))
	effect_line.add_child(time_label)
	rows_by_id[buff_id] = {
		"row": row,
		"name": name_label,
		"effect": effect_label,
		"time": time_label,
	}
	return row


func _update_row(buff: Dictionary) -> void:
	var buff_id := str(buff.get("id", "buff"))
	var row_data: Dictionary = rows_by_id.get(buff_id, {})
	if row_data.is_empty():
		return
	(row_data.name as Label).text = str(buff.get("name", "BÊNÇÃO"))
	(row_data.effect as Label).text = str(buff.get("effect", ""))
	var permanent := bool(buff.get("permanent", false))
	(row_data.time as Label).text = "" if permanent else "%ds" % ceili(float(buff.get("remaining", 0.0)))


func _landmark_icon(buff_id: String) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = LANDMARK_TEXTURE
	var frame := int(LANDMARK_FRAMES.get(buff_id, 0))
	texture.region = Rect2(Vector2(LANDMARK_FRAME_SIZE.x * frame, 0.0), LANDMARK_FRAME_SIZE)
	return texture
