class_name MapOverlay
extends Node2D

var biome_id := "forest"
var landmark_positions: Array[Vector2] = []
var layout_seed := 1


func configure(new_biome_id: String, positions: Array[Vector2], seed_value: int) -> void:
	biome_id = new_biome_id
	landmark_positions = positions
	layout_seed = seed_value
	z_index = -90
	queue_redraw()


func boundary_color() -> Color:
	match biome_id:
		"frozen":
			return Color(0.46, 0.78, 0.91, 0.26)
		"cathedral":
			return Color(0.63, 0.25, 0.82, 0.26)
		_:
			return Color(0.26, 0.49, 0.39, 0.24)


func _draw() -> void:
	var zone_color := Color(0.23, 0.12, 0.30, 0.13)
	if biome_id == "frozen":
		zone_color = Color(0.22, 0.48, 0.60, 0.12)
	elif biome_id == "cathedral":
		zone_color = Color(0.39, 0.12, 0.52, 0.13)

	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	for _index in range(58):
		var patch_position := Vector2(rng.randf_range(-5250.0, 5250.0), rng.randf_range(-5250.0, 5250.0))
		var patch_radius := rng.randf_range(95.0, 310.0)
		var patch := zone_color
		patch.a *= rng.randf_range(0.32, 0.82)
		draw_circle(patch_position, patch_radius, patch)

	draw_rect(Rect2(-5550.0, -5550.0, 11100.0, 11100.0), boundary_color(), false, 12.0)
