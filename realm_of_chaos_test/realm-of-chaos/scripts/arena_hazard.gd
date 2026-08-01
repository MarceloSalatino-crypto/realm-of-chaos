class_name ArenaHazard
extends Node2D

const ICE_REDRAW_INTERVAL := 1.0 / 14.0
const VOID_REDRAW_INTERVAL := 1.0 / 20.0

var hazard_kind := "roots"
var radius := 105.0
var animation_time := 0.0
var seed := 1
var visual_on_screen := false
var redraw_interval := ICE_REDRAW_INTERVAL
var redraw_timer := 0.0
var screen_notifier: VisibleOnScreenNotifier2D


func setup(kind: String, hazard_position: Vector2, hazard_radius: float, visual_seed: int) -> void:
	hazard_kind = kind
	global_position = hazard_position
	radius = hazard_radius
	seed = visual_seed
	add_to_group("arena_hazards")
	z_index = -2
	screen_notifier = VisibleOnScreenNotifier2D.new()
	screen_notifier.name = "VisibleOnScreenNotifier2D"
	screen_notifier.rect = Rect2(
		Vector2.ONE * -(radius + 8.0),
		Vector2.ONE * (radius + 8.0) * 2.0
	)
	screen_notifier.show_rect = false
	add_child(screen_notifier)
	screen_notifier.screen_entered.connect(_on_screen_entered)
	screen_notifier.screen_exited.connect(_on_screen_exited)
	redraw_interval = VOID_REDRAW_INTERVAL if hazard_kind == "void" else ICE_REDRAW_INTERVAL
	redraw_timer = redraw_interval * (0.25 + _visual_phase() * 0.75)
	set_process(hazard_kind != "roots")


func _process(delta: float) -> void:
	animation_time += delta
	if not visual_on_screen:
		return
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer += redraw_interval
		queue_redraw()


func _visual_phase() -> float:
	return float(posmod(seed, 997)) / 997.0


func _on_screen_entered() -> void:
	visual_on_screen = true
	queue_redraw()
	redraw_timer = redraw_interval * (0.25 + _visual_phase() * 0.75)


func _on_screen_exited() -> void:
	visual_on_screen = false


func contains_point(point: Vector2) -> bool:
	return global_position.distance_squared_to(point) <= radius * radius


func effect_data() -> Dictionary:
	match hazard_kind:
		"ice":
			return {"speed": 1.08, "traction": 0.34, "damage": 0.0, "name": "GELO INSTÁVEL"}
		"void":
			return {"speed": 0.82, "traction": 0.82, "damage": 9.0, "name": "FENDA DO VAZIO"}
		_:
			return {"speed": 0.68, "traction": 0.72, "damage": 0.0, "name": "RAÍZES PROFANADAS"}


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	return points + PackedVector2Array([points[0]])


func _angular_ring(point_count: int, ring_radius: float, phase: float, inset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := phase + TAU * float(index) / float(point_count)
		var point_radius := ring_radius - inset if index % 2 == 0 else ring_radius
		points.append(Vector2.RIGHT.rotated(angle) * point_radius)
	return points


func _draw_segmented_ring(ring_radius: float, rotation: float, color: Color, width: float, segment_count: int, coverage: float) -> void:
	var segment_angle := TAU / float(segment_count)
	for index in range(segment_count):
		var start := rotation + segment_angle * float(index)
		var finish := start + segment_angle * coverage
		draw_arc(Vector2.ZERO, ring_radius, start, finish, 6, Color(0.025, 0.012, 0.04, 0.88), width + 3.0)
		draw_arc(Vector2.ZERO, ring_radius, start, finish, 6, color, width)


func _draw_void_shard(position: Vector2, angle: float) -> void:
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.rotated(PI * 0.5)
	var outline := PackedVector2Array([
		position + forward * 7.0,
		position + side * 5.0,
		position - forward * 7.0,
		position - side * 5.0,
	])
	var inside := PackedVector2Array([
		position + forward * 4.5,
		position + side * 2.5,
		position - forward * 4.5,
		position - side * 2.5,
	])
	draw_colored_polygon(outline, Color(0.025, 0.012, 0.04, 0.92))
	draw_colored_polygon(inside, Color(0.86, 0.38, 1.0, 0.72))


func _use_reduced_detail() -> bool:
	var scene: Node = get_tree().current_scene
	if not is_instance_valid(scene):
		return false
	var enemies: Node = scene.get_node_or_null("Enemies")
	var effects: Node = scene.get_node_or_null("Effects")
	var enemy_projectiles: Node = scene.get_node_or_null("EnemyProjectiles")
	if not is_instance_valid(enemies) or not is_instance_valid(effects) or not is_instance_valid(enemy_projectiles):
		return false
	return (
		enemies.get_child_count() >= scene.ENEMY_HIGH_VISUAL_LOAD
		or effects.get_child_count() >= scene.EFFECT_HIGH_LOAD
		or enemy_projectiles.get_child_count() >= 96
	)


func _draw() -> void:
	var pulse := (sin(animation_time * 1.8 + seed) + 1.0) * 0.5
	var reduced_detail := _use_reduced_detail()
	match hazard_kind:
		"ice":
			var points := PackedVector2Array()
			for index in range(12):
				var angle := TAU * index / 12.0
				var edge := radius * (0.88 + sin(seed * 0.31 + index * 2.2) * 0.08)
				points.append(Vector2.RIGHT.rotated(angle) * edge)
			draw_colored_polygon(points, Color(0.22, 0.63, 0.82, 0.09 + pulse * 0.02))
			draw_polyline(_closed(points), Color(0.025, 0.05, 0.08, 0.84), 5.0)
			draw_polyline(_closed(points), Color(0.60, 0.91, 1.0, 0.48), 2.0)
			var crack_count := 4 if reduced_detail else 6
			for index in range(crack_count):
				var angle := TAU * index / float(crack_count) + seed * 0.13
				var crack_end := Vector2.RIGHT.rotated(angle) * radius * 0.72
				draw_line(Vector2.ZERO, crack_end, Color(0.025, 0.05, 0.08, 0.78), 4.0)
				draw_line(Vector2.ZERO, crack_end, Color(0.72, 0.95, 1.0, 0.42), 1.5)
		"void":
			var outer_points := _angular_ring(14, radius, animation_time * 0.04, radius * 0.08)
			var inner_points := _angular_ring(10, radius * 0.56, -animation_time * 0.08, radius * 0.06)
			draw_colored_polygon(outer_points, Color(0.16, 0.015, 0.26, 0.16 + pulse * 0.025))
			draw_polyline(_closed(outer_points), Color(0.025, 0.012, 0.04, 0.90), 5.0)
			draw_polyline(_closed(outer_points), Color(0.63, 0.18, 0.86, 0.48), 2.0)
			draw_colored_polygon(inner_points, Color(0.38, 0.035, 0.58, 0.11))
			draw_polyline(_closed(inner_points), Color(0.025, 0.012, 0.04, 0.78), 4.0)
			_draw_segmented_ring(radius * (0.82 + pulse * 0.05), animation_time * 0.4, Color(0.77, 0.26, 1.0, 0.62), 2.5, 5 if reduced_detail else 8, 0.62)
			var shard_count := 3 if reduced_detail else 5
			for index in range(shard_count):
				var angle := -animation_time * 0.23 + TAU * index / float(shard_count)
				_draw_void_shard(Vector2.RIGHT.rotated(angle) * radius * 0.66, angle + PI * 0.5)
		_:
			draw_circle(Vector2.ZERO, radius, Color(0.08, 0.18, 0.065, 0.07))
			var root_count := 6 if reduced_detail else 9
			for index in range(root_count):
				var angle := TAU * index / float(root_count) + seed * 0.21
				var end := Vector2.RIGHT.rotated(angle) * radius * (0.72 + sin(index * 4.1) * 0.16)
				var bend := end.rotated(sin(seed + index) * 0.22) * 0.48
				var root_points := PackedVector2Array([Vector2.ZERO, bend, end])
				draw_polyline(root_points, Color(0.025, 0.045, 0.02, 0.86), 8.0)
				draw_polyline(root_points, Color(0.34, 0.48, 0.20, 0.62), 4.0)
			_draw_segmented_ring(radius, seed * 0.03, Color(0.47, 0.61, 0.29, 0.40), 2.0, 8 if reduced_detail else 12, 0.58)
