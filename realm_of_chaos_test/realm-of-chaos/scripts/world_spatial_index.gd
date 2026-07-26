extends RefCounted

var cell_size: float
var spatial_grid: Dictionary = {}


func _init(grid_cell_size: float) -> void:
	cell_size = grid_cell_size


func rebuild(enemy_nodes: Array[Node]) -> void:
	spatial_grid.clear()
	for enemy in enemy_nodes:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var cell := grid_cell(enemy.global_position)
		if not spatial_grid.has(cell):
			spatial_grid[cell] = []
		spatial_grid[cell].append(enemy)


func is_empty() -> bool:
	return spatial_grid.is_empty()


func grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))


func get_enemies_near(position: Vector2, radius: float) -> Array[Node]:
	var result: Array[Node] = []
	var center := grid_cell(position)
	var reach := ceili(radius / cell_size)
	var radius_squared := radius * radius
	for x_offset in range(-reach, reach + 1):
		for y_offset in range(-reach, reach + 1):
			var cell := center + Vector2i(x_offset, y_offset)
			for enemy in spatial_grid.get(cell, []):
				if is_instance_valid(enemy) and not enemy.dead and position.distance_squared_to(enemy.global_position) <= radius_squared:
					result.append(enemy)
	return result


func get_nearest_enemy(position: Vector2, maximum_distance := 1500.0) -> Node2D:
	var nearest: Node2D
	var nearest_distance := maximum_distance * maximum_distance
	for enemy in get_enemies_near(position, maximum_distance):
		var distance := position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest
