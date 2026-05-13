extends Node2D

func _draw() -> void:
	var grid_size := 128
	var limit := 5000

	for x in range(-limit, limit + grid_size, grid_size):
		draw_line(Vector2(x, -limit), Vector2(x, limit), Color(0.18, 0.25, 0.18), 2.0)

	for y in range(-limit, limit + grid_size, grid_size):
		draw_line(Vector2(-limit, y), Vector2(limit, y), Color(0.18, 0.25, 0.18), 2.0)
