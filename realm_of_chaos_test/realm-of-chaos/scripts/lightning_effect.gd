class_name LightningEffect
extends Node2D

var points: PackedVector2Array = PackedVector2Array()
var color := Color("6eeaff")
var lifetime := 0.24
var duration := 0.24
var animation_time := 0.0
var visual_quality := 2
var redraw_interval := 0.0
var redraw_timer := 0.0


func setup(chain_points: PackedVector2Array, chain_color := Color("6eeaff"), effect_duration := 0.24, quality := 2) -> void:
	points = chain_points
	color = chain_color
	lifetime = effect_duration
	duration = effect_duration
	visual_quality = clampi(quality, 0, 2)
	redraw_interval = 0.0 if visual_quality == 2 else (1.0 / 30.0 if visual_quality == 1 else 1.0 / 20.0)
	redraw_timer = 0.0
	z_index = 19
	queue_redraw()


func _process(delta: float) -> void:
	animation_time += delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer += redraw_interval
		queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var alpha := clampf(lifetime / duration, 0.0, 1.0)
	var jagged_steps := 5 if visual_quality == 2 else (4 if visual_quality == 1 else 3)
	for index in range(points.size() - 1):
		var jagged := _build_jagged_segment(points[index], points[index + 1], index, jagged_steps)
		draw_polyline(jagged, Color(color, alpha * 0.22), 9.0, true)
		draw_polyline(jagged, Color(color, alpha), 3.0, true)
		draw_polyline(jagged, Color(0.92, 1.0, 1.0, alpha), 1.0, true)


func _build_jagged_segment(start: Vector2, finish: Vector2, segment_index: int, jagged_steps: int) -> PackedVector2Array:
	var segment := finish - start
	var perpendicular := segment.normalized().rotated(PI * 0.5)
	var jagged := PackedVector2Array([start])
	for step in range(1, jagged_steps + 1):
		var amount := float(step) / float(jagged_steps + 1)
		var offset := sin(animation_time * 68.0 + segment_index * 4.1 + step * 7.7) * 11.0
		jagged.append(start.lerp(finish, amount) + perpendicular * offset)
	jagged.append(finish)
	return jagged
