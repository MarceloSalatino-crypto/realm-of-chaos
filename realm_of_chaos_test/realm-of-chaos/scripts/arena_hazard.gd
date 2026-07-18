class_name ArenaHazard
extends Node2D

var hazard_kind := "roots"
var radius := 105.0
var animation_time := 0.0
var seed := 1


func setup(kind: String, hazard_position: Vector2, hazard_radius: float, visual_seed: int) -> void:
	hazard_kind = kind
	global_position = hazard_position
	radius = hazard_radius
	seed = visual_seed
	add_to_group("arena_hazards")
	z_index = -2
	queue_redraw()


func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()


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


func _draw() -> void:
	var pulse := (sin(animation_time * 1.8 + seed) + 1.0) * 0.5
	match hazard_kind:
		"ice":
			var points := PackedVector2Array()
			for index in range(12):
				var angle := TAU * index / 12.0
				var edge := radius * (0.88 + sin(seed * 0.31 + index * 2.2) * 0.08)
				points.append(Vector2.RIGHT.rotated(angle) * edge)
			draw_colored_polygon(points, Color(0.30, 0.72, 0.92, 0.10 + pulse * 0.025))
			draw_polyline(points + PackedVector2Array([points[0]]), Color(0.60, 0.91, 1.0, 0.28), 2.0)
			for index in range(6):
				var angle := TAU * index / 6.0 + seed * 0.13
				draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(angle) * radius * 0.72, Color(0.72, 0.95, 1.0, 0.22), 1.5)
		"void":
			draw_circle(Vector2.ZERO, radius, Color(0.20, 0.02, 0.32, 0.15 + pulse * 0.04))
			draw_circle(Vector2.ZERO, radius * 0.56, Color(0.42, 0.05, 0.64, 0.10))
			draw_arc(Vector2.ZERO, radius * (0.82 + pulse * 0.05), animation_time * 0.4, animation_time * 0.4 + PI * 1.55, 48, Color(0.77, 0.26, 1.0, 0.42), 2.5)
			for index in range(5):
				var angle := -animation_time * 0.23 + TAU * index / 5.0
				draw_circle(Vector2.RIGHT.rotated(angle) * radius * 0.58, 3.5, Color(0.90, 0.55, 1.0, 0.55))
		_:
			draw_circle(Vector2.ZERO, radius, Color(0.12, 0.24, 0.10, 0.09))
			for index in range(9):
				var angle := TAU * index / 9.0 + seed * 0.21
				var end := Vector2.RIGHT.rotated(angle) * radius * (0.72 + sin(index * 4.1) * 0.16)
				var bend := end.rotated(sin(seed + index) * 0.22) * 0.48
				draw_polyline(PackedVector2Array([Vector2.ZERO, bend, end]), Color(0.32, 0.45, 0.20, 0.42), 5.0)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.47, 0.61, 0.29, 0.22), 2.0)
