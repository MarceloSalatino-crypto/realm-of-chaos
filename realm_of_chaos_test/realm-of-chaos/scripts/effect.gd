extends Node2D

var effect_color := Color.WHITE
var max_radius := 80.0
var duration := 0.35
var age := 0.0
var filled := false


func setup(world_position: Vector2, color: Color, radius: float, life: float = 0.35, fill := false) -> void:
	global_position = world_position
	effect_color = color
	max_radius = radius
	duration = life
	filled = fill
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(age / duration, 0.0, 1.0)
	var color := effect_color
	color.a *= 1.0 - progress
	var radius := lerpf(max_radius * 0.15, max_radius, progress)
	if filled:
		draw_circle(Vector2.ZERO, radius, Color(color, color.a * 0.18))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, 4.0)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 48, Color(color, color.a * 0.45), 2.0)
