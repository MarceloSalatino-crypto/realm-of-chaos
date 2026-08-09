extends Node2D

var effect_color := Color.WHITE
var max_radius := 80.0
var duration := 0.35
var age := 0.0
var filled := false
var visual_quality := 2
var redraw_interval := 0.0
var redraw_timer := 0.0
var batch_renderer: Node


func _ready() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if is_instance_valid(world):
		batch_renderer = world.get("effect_batch_renderer")


func setup(world_position: Vector2, color: Color, radius: float, life: float = 0.35, fill := false, quality := 2) -> void:
	global_position = world_position
	effect_color = color
	max_radius = radius
	duration = life
	filled = fill
	visual_quality = clampi(quality, 0, 2)
	redraw_interval = 0.0 if visual_quality == 2 else (1.0 / 30.0 if visual_quality == 1 else 1.0 / 20.0)
	redraw_timer = 0.0
	_refresh_batch_visual()
	_request_canvas_redraw()


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		_unregister_batch_visual()
		queue_free()
		return
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer += redraw_interval
		_refresh_batch_visual()
		_request_canvas_redraw()


func _draw() -> void:
	if _uses_batch_renderer():
		return
	var progress := clampf(age / duration, 0.0, 1.0)
	var color := effect_color
	color.a *= 1.0 - progress
	var radius := lerpf(max_radius * 0.15, max_radius, progress)
	if filled:
		var fill_color := color.darkened(0.55)
		fill_color.a = color.a * 0.22
		draw_colored_polygon(
			_polygon_points(radius * 0.94, 16 if visual_quality == 2 else 10, age * 0.34),
			fill_color
		)
	if visual_quality == 2:
		_draw_segmented_ring(radius, color, 10, 3.2, age * 0.52)
	else:
		_draw_angular_ring(radius, color, 10 if visual_quality == 1 else 8, 3.2, age * 0.52)


func _draw_segmented_ring(
	radius: float, color: Color, segment_count: int,
	width: float, angle_offset: float
) -> void:
	var segment_angle := TAU / float(segment_count)
	var outline := Color(0.055, 0.025, 0.075, color.a * 0.94)
	for index in range(segment_count):
		var start := angle_offset + segment_angle * index
		var finish := start + segment_angle * 0.67
		draw_arc(Vector2.ZERO, radius, start, finish, 5, outline, width + 3.2)
		draw_arc(Vector2.ZERO, radius, start, finish, 5, color, width)


func _draw_angular_ring(
	radius: float, color: Color, point_count: int,
	width: float, angle_offset: float
) -> void:
	var points := _polygon_points(radius, point_count, angle_offset)
	points.append(points[0])
	var outline := Color(0.055, 0.025, 0.075, color.a * 0.94)
	draw_polyline(points, outline, width + 3.2)
	draw_polyline(points, color, width)


func _polygon_points(radius: float, point_count: int, angle_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := angle_offset + TAU * float(index) / float(point_count)
		var edge_scale := 1.0 if index % 2 == 0 else 0.94
		points.append(Vector2.RIGHT.rotated(angle) * radius * edge_scale)
	return points


func _exit_tree() -> void:
	_unregister_batch_visual()


func _request_canvas_redraw() -> void:
	if not _uses_batch_renderer():
		queue_redraw()


func _refresh_batch_visual() -> void:
	if is_instance_valid(batch_renderer):
		batch_renderer.update_effect(self)


func _unregister_batch_visual() -> void:
	if is_instance_valid(batch_renderer):
		batch_renderer.unregister_effect(self)


func _uses_batch_renderer() -> bool:
	return is_instance_valid(batch_renderer) and bool(batch_renderer.get("rendering_enabled"))


func effect_batch_data() -> Dictionary:
	return {
		"color": effect_color,
		"max_radius": max_radius,
		"duration": duration,
		"age": age,
		"filled": filled,
		"quality": visual_quality,
	}
