class_name LightningEffect
extends Node2D

var points: PackedVector2Array = PackedVector2Array()
var color := Color("6eeaff")
var lifetime := 0.24
var duration := 0.24
var animation_time := 0.0


func setup(chain_points: PackedVector2Array, chain_color := Color("6eeaff"), effect_duration := 0.24) -> void:
	points = chain_points
	color = chain_color
	lifetime = effect_duration
	duration = effect_duration
	z_index = 19
	queue_redraw()


func _process(delta: float) -> void:
	animation_time += delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var alpha := clampf(lifetime / duration, 0.0, 1.0)
	for index in range(points.size() - 1):
		var start := points[index]
		var finish := points[index + 1]
		var segment := finish - start
		var perpendicular := segment.normalized().rotated(PI * 0.5)
		var jagged := PackedVector2Array([start])
		for step in range(1, 6):
			var amount := float(step) / 6.0
			var offset := sin(animation_time * 68.0 + index * 4.1 + step * 7.7) * 11.0
			jagged.append(start.lerp(finish, amount) + perpendicular * offset)
		jagged.append(finish)
		draw_polyline(jagged, Color(color, alpha * 0.22), 9.0, true)
		draw_polyline(jagged, Color(color, alpha), 3.0, true)
		draw_polyline(jagged, Color(0.92, 1.0, 1.0, alpha), 1.0, true)
