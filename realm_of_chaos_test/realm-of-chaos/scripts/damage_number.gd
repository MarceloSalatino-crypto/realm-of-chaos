extends Label


func setup(world_position: Vector2, amount: float, critical := false, healing := false, custom_text := "") -> void:
	global_position = world_position + Vector2(randf_range(-12.0, 12.0), -30.0)
	text = custom_text if not custom_text.is_empty() else ("+%d" % ceili(amount) if healing else ("CRÍTICO  %d" % ceili(amount) if critical else "%d" % ceili(amount)))
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 24 if critical else 18)
	add_theme_color_override("font_color", Color("80eaff") if not custom_text.is_empty() else (Color("ffdf6e") if critical else (Color("65ff9a") if healing else Color("f4eaff"))))
	add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.07, 0.95))
	add_theme_constant_override("outline_size", 5)
	pivot_offset = Vector2(40.0, 16.0)
	scale = Vector2.ONE * (1.32 if critical else 0.88)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", position + Vector2(randf_range(-14.0, 14.0), -62.0), 0.72)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.72).set_delay(0.28)
	tween.chain().tween_callback(queue_free)
