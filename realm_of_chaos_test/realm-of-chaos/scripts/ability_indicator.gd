extends Control

var fill_progress := 1.0
var ability_color := Color("a874e8")
var is_ready_state := true
var glow_strength := 0.0
var initialized := false
var pulse_tween: Tween

var icon_rect: TextureRect
var key_badge: PanelContainer
var skill_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	queue_redraw()


func _build_content() -> void:
	icon_rect = TextureRect.new()
	icon_rect.name = "AbilityIcon"
	icon_rect.position = Vector2(16.0, 18.0)
	icon_rect.size = Vector2(44.0, 44.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_rect)

	key_badge = PanelContainer.new()
	key_badge.name = "KeyBadge"
	key_badge.position = Vector2(66.0, 7.0)
	key_badge.size = Vector2(88.0, 24.0)
	key_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.035, 0.025, 0.055, 0.94)
	badge_style.border_color = Color(0.48, 0.38, 0.62, 0.92)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(7)
	key_badge.add_theme_stylebox_override("panel", badge_style)
	add_child(key_badge)
	var key_label := Label.new()
	key_label.text = "ESPAÇO / A"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.add_theme_color_override("font_color", Color("ddd1e8"))
	key_badge.add_child(key_label)

	skill_label = Label.new()
	skill_label.name = "SkillName"
	skill_label.position = Vector2(67.0, 34.0)
	skill_label.size = Vector2(102.0, 42.0)
	skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_label.add_theme_font_size_override("font_size", 11)
	skill_label.add_theme_color_override("font_color", Color("d8c7e8"))
	skill_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.04, 0.96))
	skill_label.add_theme_constant_override("outline_size", 3)
	skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skill_label)


func set_state(progress_value: float, texture: Texture2D, ability_name: String, color: Color, allow_pulse := true) -> void:
	var was_ready := is_ready_state
	fill_progress = clampf(progress_value, 0.0, 1.0)
	is_ready_state = fill_progress >= 0.999
	ability_color = color
	icon_rect.texture = texture
	icon_rect.modulate = Color.WHITE if is_ready_state else Color(0.48, 0.48, 0.52, 0.78).lerp(Color.WHITE, fill_progress * 0.42)
	skill_label.text = ability_name
	skill_label.add_theme_color_override("font_color", ability_color.lightened(0.25) if is_ready_state else Color("a99caf"))
	if initialized and is_ready_state and not was_ready and allow_pulse:
		pulse_ready()
	initialized = true
	queue_redraw()


func pulse_ready() -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	scale = Vector2.ONE
	pivot_offset = Vector2(38.0, 40.0)
	glow_strength = 1.0
	pulse_tween = create_tween().set_parallel(true)
	pulse_tween.tween_property(self, "scale", Vector2(1.075, 1.075), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_method(_set_glow_strength, 1.0, 0.0, 0.42)


func _set_glow_strength(value: float) -> void:
	glow_strength = value
	queue_redraw()


func _draw() -> void:
	var center := Vector2(38.0, 40.0)
	var radius := 31.0
	if glow_strength > 0.001:
		draw_circle(center, radius + 9.0 * glow_strength, Color(ability_color, 0.16 * glow_strength))
	draw_circle(center + Vector2(0.0, 3.0), radius + 2.0, Color(0.0, 0.0, 0.0, 0.56))
	draw_circle(center, radius, Color("302d36"))
	if fill_progress > 0.001:
		if is_ready_state:
			draw_circle(center, radius - 2.0, ability_color.darkened(0.22))
		else:
			var points := PackedVector2Array([center])
			var segment_count := maxi(2, ceili(40.0 * fill_progress))
			for index in range(segment_count + 1):
				var angle := -PI * 0.5 + TAU * fill_progress * float(index) / float(segment_count)
				points.append(center + Vector2.RIGHT.rotated(angle) * (radius - 2.0))
			draw_colored_polygon(points, ability_color.darkened(0.32))
	draw_circle(center, 23.0, Color(0.035, 0.025, 0.055, 0.72))
	draw_arc(center, radius, 0.0, TAU, 64, Color("17101f"), 4.0, true)
	var ring_color := ability_color.lightened(0.28) if is_ready_state else Color("756c7d")
	draw_arc(center, radius - 1.0, 0.0, TAU, 64, ring_color, 2.0, true)
	if is_ready_state:
		draw_arc(center, radius + 3.0, 0.0, TAU, 64, Color(ability_color, 0.44 + glow_strength * 0.32), 2.0, true)
