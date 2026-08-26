extends RefCounted

const ArenaHazardScript = preload("res://scripts/arena_hazard.gd")
const MapOverlayScript = preload("res://scripts/map_overlay.gd")
const MapLandmarkScript = preload("res://scripts/map_landmark.gd")
const MapVisualBatcherScript = preload("res://scripts/map_visual_batcher.gd")

const FLOOR_DECAL_VARIATIONS_PER_KIND := 12
const SMALL_DECORATION_COUNT := 1200
const TOTAL_DECORATION_COUNT := SMALL_DECORATION_COUNT + FLOOR_DECAL_VARIATIONS_PER_KIND * 3
const TREE_VISUAL_SCALE_MULTIPLIER := 1.25
const STONE_VISUAL_SCALE_MULTIPLIER := 2.0
const PHYSICAL_OBSTACLE_COUNT := 36
const PHYSICAL_TREE_COUNT := 26
const OBSTACLE_MIN_SPACING := 180.0
const OBSTACLE_SPAWN_CLEARANCE := 105.0
const OBSTACLE_GRID_CELL_SIZE := 256.0

const SMALL_DECORATION_SOURCES := [
	"bush_01", "bush_02", "mushroom_03", "leaf_litter",
	"broken_branches", "twig_scatter", "gravel_scatter",
]

var world
var visual_batcher
var obstacle_grid: Dictionary = {}


func _init(owner_world) -> void:
	world = owner_world


func create_runtime_nodes() -> void:
	visual_batcher = MapVisualBatcherScript.new(world.decorations)
	world.hazards = Node2D.new()
	world.hazards.name = "ArenaHazards"
	world.add_child(world.hazards)
	world.landmarks = Node2D.new()
	world.landmarks.name = "Landmarks"
	world.add_child(world.landmarks)
	world.obstacles = Node2D.new()
	world.obstacles.name = "PhysicalObstacles"
	world.add_child(world.obstacles)
	world.map_overlay = MapOverlayScript.new()
	world.map_overlay.name = "MapOverlay"
	world.add_child(world.map_overlay)


func apply_biome() -> void:
	world.ground.texture = load(str(world.biome.ground))
	world.ground.modulate = world.biome.ground_modulate


func _biome_tint() -> Color:
	if str(world.biome.id) == "frozen":
		return Color("9ec7df")
	if str(world.biome.id) == "cathedral":
		return Color("9e82bb")
	return Color("b3c7bd")


func generate_environment() -> void:
	visual_batcher.reset()
	obstacle_grid.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 864210 + world.run_cycle * 913
	generate_map_layout(rng)
	var biome_tint := _biome_tint()
	for _index in range(SMALL_DECORATION_COUNT):
		var atlas_key: String = SMALL_DECORATION_SOURCES[rng.randi_range(0, SMALL_DECORATION_SOURCES.size() - 1)]
		var decoration_position := find_visual_decoration_position(rng, 5400.0)
		var scale_value := rng.randf_range(0.65, 1.15)
		visual_batcher.add_visual(
			atlas_key, decoration_position, Vector2.ONE * scale_value,
			0.0, rng.randf() < 0.5, Color(biome_tint, rng.randf_range(0.34, 0.58)),
			-4, "decoration"
		)
	generate_floor_decals()
	generate_obstacles(rng)
	generate_hazards(rng)
	visual_batcher.flush()


func generate_floor_decals() -> void:
	var decal_rng := RandomNumberGenerator.new()
	decal_rng.seed = 272401 + world.run_cycle * 1013
	var kind_names := ["Crater", "RitualScar", "BattleRemains"]
	var decal_kinds := ["crater", "ritual", "battle"]
	var kind_alpha := [0.42, 0.38, 0.44]
	var scale_steps := [0.90, 1.0, 1.10]
	for kind_index in range(kind_names.size()):
		for variant_index in range(FLOOR_DECAL_VARIATIONS_PER_KIND):
			var atlas_key: String = visual_batcher.floor_decal_key(
				str(world.biome.id), decal_kinds[kind_index]
			)
			var position := find_visual_decoration_position(decal_rng, 5350.0)
			var rotation := float(variant_index % 4) * PI * 0.5
			var flip_h := (variant_index + kind_index) % 2 == 1
			var scale_index := floori(float(variant_index) / 4.0)
			visual_batcher.add_visual(
				atlas_key, position,
				Vector2.ONE * float(scale_steps[scale_index]), rotation, flip_h,
				Color(1.0, 1.0, 1.0, float(kind_alpha[kind_index])), -6,
				"floor_" + str(kind_names[kind_index]).to_snake_case()
			)


func generate_map_layout(rng: RandomNumberGenerator) -> void:
	world.landmark_positions.clear()
	var rotation := float(world.run_cycle) * 0.31
	var base_positions: Array[Vector2] = [
		Vector2(1280.0, -920.0), Vector2(-1760.0, -1080.0),
		Vector2(1580.0, 1710.0), Vector2(-2200.0, 1470.0)
	]
	for base_position in base_positions:
		var jitter := Vector2(rng.randf_range(-130.0, 130.0), rng.randf_range(-130.0, 130.0))
		world.landmark_positions.append(base_position.rotated(rotation) + jitter)
	world.map_overlay.configure(str(world.biome.id), world.landmark_positions, 44321 + world.run_cycle * 701)
	var kinds: Array[String] = ["altar", "obelisk", "tree", "portal"]
	for index in range(kinds.size()):
		var landmark = MapLandmarkScript.new()
		landmark.configure(world, kinds[index], world.landmark_positions[index], index)
		world.landmarks.add_child(landmark)


func find_free_map_position(rng: RandomNumberGenerator, maximum: float) -> Vector2:
	var candidate := Vector2.ZERO
	for _attempt in range(28):
		candidate = Vector2(rng.randf_range(-maximum, maximum), rng.randf_range(-maximum, maximum))
		if candidate.length() < 430.0:
			continue
		var blocked := false
		for landmark_position in world.landmark_positions:
			if candidate.distance_to(landmark_position) < 315.0 or point_segment_distance(candidate, Vector2.ZERO, landmark_position) < 165.0:
				blocked = true
				break
		if not blocked:
			return candidate
	var start_angle := rng.randf() * TAU
	for radius in range(430, ceili(maximum), 128):
		for angle_index in range(64):
			candidate = Vector2.RIGHT.rotated(start_angle + TAU * float(angle_index) / 64.0) * float(radius)
			var blocked := false
			for landmark_position in world.landmark_positions:
				if candidate.distance_to(landmark_position) < 315.0 or point_segment_distance(candidate, Vector2.ZERO, landmark_position) < 165.0:
					blocked = true
					break
			if not blocked:
				return candidate
	push_error("Nao foi possivel encontrar uma posicao livre no mapa")
	return Vector2.INF


func find_visual_decoration_position(rng: RandomNumberGenerator, maximum: float) -> Vector2:
	# Elementos sem colisao podem preencher a area inicial e os corredores dos santuarios.
	return Vector2(rng.randf_range(-maximum, maximum), rng.randf_range(-maximum, maximum))


func point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func generate_obstacles(rng: RandomNumberGenerator) -> void:
	for index in range(PHYSICAL_OBSTACLE_COUNT):
		var is_stone := index >= PHYSICAL_TREE_COUNT
		var body := StaticBody2D.new()
		body.position = find_free_obstacle_position(rng, 5150.0)
		if not is_finite(body.position.x) or not is_finite(body.position.y):
			body.free()
			continue
		body.z_index = -3
		body.collision_layer = 1
		body.collision_mask = 1
		body.add_to_group("physical_obstacles")
		var obstacle_scale := rng.randf_range(0.82, 1.18)
		var visual_multiplier := STONE_VISUAL_SCALE_MULTIPLIER if is_stone else TREE_VISUAL_SCALE_MULTIPLIER
		var collision := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 18.0 * obstacle_scale
		collision.position.y = 7.0
		collision.shape = circle
		body.add_child(collision)
		world.obstacles.add_child(body)
		_register_obstacle(body)
		var atlas_key := "stone_03" if is_stone else "tree_%d" % (index % 3 + 1)
		visual_batcher.add_visual(
			atlas_key, body.position, Vector2.ONE * obstacle_scale * visual_multiplier,
			0.0, false, Color(_biome_tint(), 0.90), -3,
			"obstacle_stone" if is_stone else "obstacle_tree"
		)


func find_free_obstacle_position(rng: RandomNumberGenerator, maximum: float) -> Vector2:
	var candidate := Vector2.ZERO
	for _attempt in range(64):
		candidate = find_free_map_position(rng, maximum)
		if obstacle_position_has_clearance(candidate):
			return candidate
	var grid_step := ceili(OBSTACLE_MIN_SPACING)
	var grid_limit := floori(maximum / float(grid_step))
	for grid_y in range(-grid_limit, grid_limit + 1):
		for grid_x in range(-grid_limit, grid_limit + 1):
			candidate = Vector2(float(grid_x * grid_step), float(grid_y * grid_step))
			if candidate.length() < 430.0:
				continue
			var blocked_by_layout := false
			for landmark_position in world.landmark_positions:
				if candidate.distance_to(landmark_position) < 315.0 or point_segment_distance(candidate, Vector2.ZERO, landmark_position) < 165.0:
					blocked_by_layout = true
					break
			if not blocked_by_layout and obstacle_position_has_clearance(candidate):
				return candidate
	push_error("Nao foi possivel posicionar um obstaculo com o espacamento minimo configurado")
	return Vector2.INF


func obstacle_position_has_clearance(candidate: Vector2) -> bool:
	for obstacle in obstacles_near(candidate, OBSTACLE_MIN_SPACING):
		if obstacle.position.distance_squared_to(candidate) < OBSTACLE_MIN_SPACING * OBSTACLE_MIN_SPACING:
			return false
	return true


func rebuild_obstacle_grid() -> void:
	obstacle_grid.clear()
	if not is_instance_valid(world.obstacles):
		return
	for obstacle in world.obstacles.get_children():
		if is_instance_valid(obstacle):
			_register_obstacle(obstacle)


func obstacles_near(position: Vector2, radius: float) -> Array:
	var results: Array = []
	var seen: Dictionary = {}
	var minimum_cell := _obstacle_grid_cell(position - Vector2.ONE * radius)
	var maximum_cell := _obstacle_grid_cell(position + Vector2.ONE * radius)
	for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
		for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
			var cell := Vector2i(cell_x, cell_y)
			for obstacle in obstacle_grid.get(cell, []):
				if not is_instance_valid(obstacle):
					continue
				var obstacle_id: int = obstacle.get_instance_id()
				if seen.has(obstacle_id):
					continue
				seen[obstacle_id] = true
				results.append(obstacle)
	return results


func _register_obstacle(obstacle: Node2D) -> void:
	var cell := _obstacle_grid_cell(obstacle.global_position)
	var bucket: Array = obstacle_grid.get(cell, [])
	bucket.append(obstacle)
	obstacle_grid[cell] = bucket


func _obstacle_grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / OBSTACLE_GRID_CELL_SIZE),
		floori(position.y / OBSTACLE_GRID_CELL_SIZE)
	)


func generate_hazards(rng: RandomNumberGenerator) -> void:
	var hazard_kind := "roots"
	if str(world.biome.id) == "frozen":
		hazard_kind = "ice"
	elif str(world.biome.id) == "cathedral":
		hazard_kind = "void"
	for _index in range(18):
		var hazard_position := find_free_map_position(rng, 5000.0)
		if not is_finite(hazard_position.x) or not is_finite(hazard_position.y):
			continue
		var hazard = ArenaHazardScript.new()
		world.hazards.add_child(hazard)
		hazard.setup(hazard_kind, hazard_position, rng.randf_range(82.0, 138.0), rng.randi())


func is_spawn_position_clear(position: Vector2) -> bool:
	for obstacle in obstacles_near(position, OBSTACLE_SPAWN_CLEARANCE):
		if obstacle.global_position.distance_squared_to(position) < OBSTACLE_SPAWN_CLEARANCE * OBSTACLE_SPAWN_CLEARANCE:
			return false
	if is_instance_valid(world.landmarks):
		for landmark in world.landmarks.get_children():
			if is_instance_valid(landmark) and landmark.global_position.distance_squared_to(position) < 145.0 * 145.0:
				return false
	return true


func find_clear_spawn_position(
	origin: Vector2, minimum: float, maximum: float, random_attempts := 12,
	preferred_angle := NAN
) -> Vector2:
	var minimum_radius := minf(minimum, maximum)
	var maximum_radius := maxf(minimum, maximum)
	if is_finite(preferred_angle):
		var preferred_candidate := (
			origin + Vector2.RIGHT.rotated(preferred_angle) * randf_range(minimum_radius, maximum_radius)
		)
		if _spawn_candidate_is_valid(preferred_candidate):
			return preferred_candidate
	for _attempt in range(random_attempts):
		var angle := randf() * TAU
		var candidate := origin + Vector2.RIGHT.rotated(angle) * randf_range(minimum_radius, maximum_radius)
		if _spawn_candidate_is_valid(candidate):
			return candidate
	var start_angle := randf() * TAU
	var radius_steps := [minimum_radius, (minimum_radius + maximum_radius) * 0.5, maximum_radius]
	for radius in radius_steps:
		for angle_index in range(64):
			var candidate := origin + Vector2.RIGHT.rotated(start_angle + TAU * float(angle_index) / 64.0) * float(radius)
			if _spawn_candidate_is_valid(candidate):
				return candidate
	return Vector2.INF


func _spawn_candidate_is_valid(candidate: Vector2) -> bool:
	if not is_finite(candidate.x) or not is_finite(candidate.y):
		return false
	if absf(candidate.x) > 5420.0 or absf(candidate.y) > 5420.0:
		return false
	return is_spawn_position_clear(candidate)


func get_environment_effect(position: Vector2) -> Dictionary:
	for hazard in world.get_tree().get_nodes_in_group("arena_hazards"):
		if is_instance_valid(hazard) and hazard.contains_point(position):
			return hazard.effect_data()
	return {"speed": 1.0, "traction": 1.0, "damage": 0.0, "name": ""}
