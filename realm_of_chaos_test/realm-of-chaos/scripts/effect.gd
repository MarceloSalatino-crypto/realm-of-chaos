extends Node2D

var effect_color := Color.WHITE
var max_radius := 80.0
var duration := 0.35
var age := 0.0
var filled := false
var visual_quality := 2
var redraw_interval := 0.0
var redraw_timer := 0.0


func setup(world_position: Vector2, color: Color, radius: float, life: float = 0.35, fill := false, quality := 2) -> void:
	global_position = world_position
	effect_color = color
	max_radius = radius
	duration = life
	filled = fill
	visual_quality = clampi(quality, 0, 2)
	redraw_interval = 0.0 if visual_quality == 2 else (1.0 / 30.0 if visual_quality == 1 else 1.0 / 20.0)
	redraw_timer = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer += redraw_interval
		queue_redraw()


func _draw() -> void:
	var progress := clampf(age / duration, 0.0, 1.0)
	var color := effect_color
	color.a *= 1.0 - progress
	var radius := lerpf(max_radius * 0.15, max_radius, progress)
	if filled:
		draw_circle(Vector2.ZERO, radius, Color(color, color.a * 0.18))
	var outer_segments := 64 if visual_quality == 2 else (36 if visual_quality == 1 else 20)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, outer_segments, color, 4.0)
	if visual_quality > 0:
		var inner_segments := 48 if visual_quality == 2 else 24
		draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, inner_segments, Color(color, color.a * 0.45), 2.0)
