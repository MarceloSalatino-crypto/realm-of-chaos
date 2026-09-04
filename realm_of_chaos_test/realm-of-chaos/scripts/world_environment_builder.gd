extends RefCounted

const ArenaHazardScript = preload("res://scripts/arena_hazard.gd")
const MapOverlayScript = preload("res://scripts/map_overlay.gd")
const MapLandmarkScript = preload("res://scripts/map_landmark.gd")
const MapVisualBatcherScript = preload("res://scripts/map_visual_batcher.gd")
const ForestTerrainComposerScript = preload("res://scripts/forest_terrain_composer.gd")
const ForestCollisionComposerScript = preload("res://scripts/forest_collision_composer.gd")

const FLOOR_DECAL_VARIATIONS_PER_KIND := 12
const SMALL_DECORATION_COUNT := 1200
const TREE_VISUAL_SCALE_MULTIPLIER := 1.25
const STONE_VISUAL_SCALE_MULTIPLIER := 2.4
const PHYSICAL_OBSTACLE_COUNT := 36
const PHYSICAL_TREE_COUNT := 26
const OBSTACLE_MIN_SPACING := 180.0
const OBSTACLE_SPAWN_CLEARANCE := 105.0
const OBSTACLE_GRID_CELL_SIZE := 256.0
const WORLD_PLAYABLE_LIMIT := 5550.0
const BOSS_ARENA_WORLD_MARGIN := 8.0
const BOSS_ARENA_PLAYER_MARGIN := 34.0
const BOSS_ARENA_SAMPLE_STEP := 72.0
const BOSS_ARENA_MIN_FREE_RATIO := 0.94
const BOSS_ARENA_MIN_CONNECTED_FREE_RATIO := 0.985
const BOSS_ARENA_BOUNDARY_SAMPLES := 64
const BOSS_ARENA_DYNAMIC_ANGLE_COUNT := 16
const FOREST_BOSS_ARENA_FALLBACKS := [
	Vector2.ZERO,
	Vector2(2640.0, -2800.0),
	Vector2(-2860.0, 2960.0),
]

const SMALL_DECORATION_SOURCES := [
	"bush_01", "bush_02", "mushroom_03", "leaf_litter",
	"broken_branches", "twig_scatter", "gravel_scatter",
]
const FOREST_SMALL_DECORATION_SOURCES := [
	"leaf_litter", "leaf_litter", "broken_branches", "broken_branches",
	"twig_scatter", "twig_scatter", "gravel_scatter", "gravel_scatter",
	"bush_01", "bush_02", "mushroom_03",
]
const FOREST_ROUTE_DECORATION_SOURCES := [
	"leaf_litter", "leaf_litter", "leaf_litter", "broken_branches",
	"broken_branches", "twig_scatter", "twig_scatter", "twig_scatter",
	"gravel_scatter", "gravel_scatter", "bush_01", "bush_02",
	"grass_tuft_01", "grass_tuft_01", "grass_tuft_02", "grass_tuft_02",
	"flower_01", "flower_02", "flower_03",
]
const FOREST_TREE_SETTLEMENT_SOURCES := [
	"leaf_litter", "leaf_litter", "leaf_litter", "leaf_litter",
	"broken_branches", "broken_branches", "twig_scatter", "twig_scatter",
	"bush_01", "bush_02", "mushroom_03", "grass_tuft_01",
	"grass_tuft_01", "grass_tuft_02", "grass_tuft_02",
	"flower_01", "flower_02", "flower_03",
]
const FOREST_STONE_SETTLEMENT_SOURCES := [
	"gravel_scatter", "gravel_scatter", "gravel_scatter", "gravel_scatter",
	"twig_scatter", "twig_scatter", "leaf_litter", "leaf_litter",
	"broken_branches", "bush_01", "grass_tuft_01", "grass_tuft_02", "flower_03",
]
const FOREST_DENSE_DECORATION_SOURCES := [
	"leaf_litter", "leaf_litter", "leaf_litter", "broken_branches",
	"broken_branches", "twig_scatter", "twig_scatter", "bush_01", "bush_02",
	"mushroom_03", "grass_tuft_01", "grass_tuft_01", "grass_tuft_02",
	"grass_tuft_02", "flower_01", "flower_02", "flower_03",
]
const FOREST_BACKGROUND_DECORATION_SOURCES := [
	"leaf_litter", "twig_scatter", "gravel_scatter", "bush_01", "bush_02",
	"grass_tuft_01", "grass_tuft_02",
]

var world
var visual_batcher
var terrain_composer
var forest_collision_composer
var obstacle_grid: Dictionary = {}
var deferred_obstacle_visuals: Array[Dictionary] = []


func _init(owner_world) -> void:
	world = owner_world


func create_runtime_nodes() -> void:
	visual_batcher = MapVisualBatcherScript.new(world.decorations)
	terrain_composer = ForestTerrainComposerScript.new(world)
	forest_collision_composer = ForestCollisionComposerScript.new(world)
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
	forest_collision_composer.clear()
	terrain_composer.clear()
	world.ground.texture = load(str(world.biome.ground))
	world.ground.modulate = world.biome.ground_modulate


func _biome_tint() -> Color:
	if str(world.biome.id) == "frozen":
		return Color("9ec7df")
	if str(world.biome.id) == "cathedral":
		return Color("9e82bb")
	return Color("81978e")


func generate_environment() -> void:
	visual_batcher.reset()
	obstacle_grid.clear()
	deferred_obstacle_visuals.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 864210 + world.map_seed_offset * 913
	generate_map_layout(rng)
	# Os corpos fisicos existem antes da composicao, mas seus visuais continuam
	# registrados depois das decoracoes para preservar a ordem publica do lote.
	generate_obstacles(rng, true)
	terrain_composer.prepare_layout()
	var biome_tint := _biome_tint()
	for _index in range(SMALL_DECORATION_COUNT):
		var is_forest := str(world.biome.id) == "forest"
		var placement: Dictionary = (
			terrain_composer.sample_visual_placement(rng, 5400.0)
			if is_forest else {
				"position": Vector2(rng.randf_range(-5400.0, 5400.0), rng.randf_range(-5400.0, 5400.0)),
				"context": "background",
			}
		)
		var context := str(placement.context)
		var sources: Array = _forest_sources_for_context(context) if is_forest else SMALL_DECORATION_SOURCES
		var atlas_key: String = sources[rng.randi_range(0, sources.size() - 1)]
		var decoration_position := Vector2(placement.position)
		var scale_value := (
			rng.randf_range(float(placement.scale_min), float(placement.scale_max))
			if is_forest else rng.randf_range(0.65, 1.15)
		)
		var alpha := (
			rng.randf_range(float(placement.alpha_min), float(placement.alpha_max))
			if is_forest else rng.randf_range(0.34, 0.58)
		)
		var detail_tint := Color(placement.tint) if is_forest else biome_tint
		if is_forest:
			var visual_profile := _forest_visual_profile(
				atlas_key, context, scale_value, alpha, detail_tint
			)
			scale_value = float(visual_profile.scale)
			alpha = float(visual_profile.alpha)
			detail_tint = Color(visual_profile.tint)
		visual_batcher.add_visual(
			atlas_key, decoration_position, Vector2.ONE * scale_value,
			0.0, rng.randf() < 0.5, Color(detail_tint, alpha),
			-4, "decoration_" + context if is_forest else "decoration"
		)
	generate_floor_decals()
	_flush_deferred_obstacle_visuals()
	terrain_composer.rebuild()
	forest_collision_composer.apply_forest_profiles(terrain_composer.grove_visual_layout())
	rebuild_obstacle_grid()
	generate_hazards(rng)
	visual_batcher.flush()


func _forest_sources_for_context(context: String) -> Array:
	if context == "route":
		return FOREST_ROUTE_DECORATION_SOURCES
	if context == "dense":
		return FOREST_DENSE_DECORATION_SOURCES
	if context == "background":
		return FOREST_BACKGROUND_DECORATION_SOURCES
	if context.contains("stone") or context.contains("obelisk") or context.contains("portal"):
		return FOREST_STONE_SETTLEMENT_SOURCES
	if context.contains("tree") or context.contains("altar"):
		return FOREST_TREE_SETTLEMENT_SOURCES
	return FOREST_SMALL_DECORATION_SOURCES


func _forest_visual_profile(
	atlas_key: String, context: String, scale_value: float, alpha: float, tint: Color
) -> Dictionary:
	var adjusted_scale := scale_value
	var adjusted_alpha := alpha
	var adjusted_tint := tint
	if atlas_key.begins_with("flower_"):
		adjusted_scale *= 2.20
		adjusted_alpha = clampf(maxf(0.52, alpha * 1.55), 0.52, 0.70)
		if atlas_key == "flower_01":
			adjusted_tint = Color("a5a77d")
		elif atlas_key == "flower_02":
			adjusted_tint = Color("879a80")
		else:
			adjusted_tint = Color("aa8b70")
	elif atlas_key.begins_with("grass_tuft_"):
		adjusted_scale *= 1.28
		adjusted_alpha = clampf(maxf(0.34, alpha * 1.38), 0.34, 0.58)
		adjusted_tint = Color("82947b") if context == "route" else Color("788b78")
	return {"scale": adjusted_scale, "alpha": adjusted_alpha, "tint": adjusted_tint}


func generate_floor_decals() -> void:
	var decal_rng := RandomNumberGenerator.new()
	decal_rng.seed = 272401 + world.map_seed_offset * 1013
	var kind_names := ["Crater", "RitualScar", "BattleRemains"]
	var decal_kinds := ["crater", "ritual", "battle"]
	var kind_alpha := [0.42, 0.38, 0.44]
	var scale_steps := [0.90, 1.0, 1.10]
	if str(world.biome.id) == "forest":
		kind_alpha = [0.10, 0.075, 0.11]
		scale_steps = [0.52, 0.60, 0.68]
	for kind_index in range(kind_names.size()):
		for variant_index in range(FLOOR_DECAL_VARIATIONS_PER_KIND):
			var atlas_key: String = visual_batcher.floor_decal_key(
				str(world.biome.id), decal_kinds[kind_index]
			)
			var position: Vector2 = (
				terrain_composer.sample_floor_decal_position(
					decal_rng, 5350.0, kind_index, variant_index
				)
				if str(world.biome.id) == "forest"
				else find_visual_decoration_position(decal_rng, 5350.0)
			)
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
	var rotation := float(world.map_seed_offset) * 0.31
	var landmark_profile: Dictionary = world.encounter_profile.landmark_profile
	var jitter_amount := float(landmark_profile.get("jitter", 130.0))
	var base_positions: Array = landmark_profile.get("base_positions", [])
	for base_value in base_positions:
		var base_position := Vector2(base_value)
		var jitter := Vector2(rng.randf_range(-jitter_amount, jitter_amount), rng.randf_range(-jitter_amount, jitter_amount))
		world.landmark_positions.append(base_position.rotated(rotation) + jitter)
	world.map_overlay.configure(str(world.biome.id), world.landmark_positions, 44321 + world.map_seed_offset * 701)
	var kinds: Array = landmark_profile.get("kinds", [])
	for index in range(kinds.size()):
		var landmark = MapLandmarkScript.new()
		landmark.configure(world, str(kinds[index]), world.landmark_positions[index], index)
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
	return terrain_composer.sample_visual_position(rng, maximum)


func point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func generate_obstacles(rng: RandomNumberGenerator, defer_visuals := false) -> void:
	if defer_visuals:
		deferred_obstacle_visuals.clear()
	for index in range(PHYSICAL_OBSTACLE_COUNT):
		var is_stone := index >= PHYSICAL_TREE_COUNT
		var body := StaticBody2D.new()
		body.name = "%sObstacle_%02d" % ["Stone" if is_stone else "Tree", index]
		body.position = find_free_obstacle_position(rng, 5150.0)
		if not is_finite(body.position.x) or not is_finite(body.position.y):
			body.free()
			continue
		body.z_index = -3
		body.collision_layer = 1
		body.collision_mask = 1
		body.add_to_group("physical_obstacles")
		var obstacle_scale := rng.randf_range(0.82, 1.18)
		body.set_meta("environment_obstacle_kind", "stone" if is_stone else "tree")
		body.set_meta("environment_obstacle_index", index)
		body.set_meta("environment_obstacle_radius", 18.0 * obstacle_scale)
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
		var visual_record := {
			"atlas_key": atlas_key,
			"position": body.position,
			"scale": Vector2.ONE * obstacle_scale * visual_multiplier,
			"source_kind": "obstacle_stone" if is_stone else "obstacle_tree",
		}
		if defer_visuals:
			deferred_obstacle_visuals.append(visual_record)
		else:
			_add_obstacle_visual(visual_record)


func _add_obstacle_visual(visual_record: Dictionary) -> void:
	visual_batcher.add_visual(
		str(visual_record.atlas_key), Vector2(visual_record.position), Vector2(visual_record.scale),
		0.0, false, Color(_biome_tint(), 0.90), -3, str(visual_record.source_kind)
	)


func _flush_deferred_obstacle_visuals() -> void:
	for visual_record in deferred_obstacle_visuals:
		_add_obstacle_visual(visual_record)
	deferred_obstacle_visuals.clear()


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
	var profile: Dictionary = world.encounter_profile.hazard_profile
	var hazard_kind: String = world.encounter_profile.hazard_kind_for_biome(str(world.biome.id))
	var hazard_count := int(profile.get("count", 18))
	if hazard_count <= 0 or hazard_kind.is_empty():
		return
	var radius_min := float(profile.get("radius_min", 82.0))
	var radius_max := float(profile.get("radius_max", 138.0))
	for _index in range(hazard_count):
		var hazard_position := find_free_map_position(rng, 5000.0)
		if not is_finite(hazard_position.x) or not is_finite(hazard_position.y):
			continue
		var hazard = ArenaHazardScript.new()
		world.hazards.add_child(hazard)
		hazard.setup(hazard_kind, hazard_position, rng.randf_range(radius_min, radius_max), rng.randi())


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


func supports_safe_boss_arena_placement() -> bool:
	return str(world.biome.id) == "forest" and is_instance_valid(terrain_composer)


func forest_boss_arena_fallback_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for fallback in FOREST_BOSS_ARENA_FALLBACKS:
		centers.append(Vector2(fallback))
	return centers


func find_safe_boss_arena_placement(
	origin: Vector2, arena_radius: float, boss_radius: float
) -> Dictionary:
	if not supports_safe_boss_arena_placement():
		return {}
	for candidate in _dynamic_boss_arena_centers(origin, arena_radius):
		var placement := _validated_boss_arena_placement(
			candidate, origin, arena_radius, boss_radius, false
		)
		if not placement.is_empty():
			return placement
	var fallbacks := forest_boss_arena_fallback_centers()
	if is_finite(origin.x) and is_finite(origin.y):
		fallbacks.sort_custom(func(left: Vector2, right: Vector2) -> bool:
			return left.distance_squared_to(origin) < right.distance_squared_to(origin)
		)
	for fallback in fallbacks:
		var placement := _validated_boss_arena_placement(
			fallback, Vector2.INF, arena_radius, boss_radius, true
		)
		if not placement.is_empty():
			return placement
	return {}


func _dynamic_boss_arena_centers(origin: Vector2, arena_radius: float) -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	if not is_finite(origin.x) or not is_finite(origin.y):
		return candidates
	candidates.append(origin)
	var maximum_shift := maxf(0.0, arena_radius - BOSS_ARENA_PLAYER_MARGIN - BOSS_ARENA_WORLD_MARGIN)
	var radii: Array[float] = []
	var radius := 96.0
	while radius < maximum_shift:
		radii.append(radius)
		radius += 96.0
	if radii.is_empty() or not is_equal_approx(radii[-1], maximum_shift):
		radii.append(maximum_shift)
	for ring_radius in radii:
		for angle_index in range(BOSS_ARENA_DYNAMIC_ANGLE_COUNT):
			var angle := TAU * float(angle_index) / float(BOSS_ARENA_DYNAMIC_ANGLE_COUNT)
			candidates.append(origin + Vector2.RIGHT.rotated(angle) * ring_radius)
	return candidates


func _validated_boss_arena_placement(
	center: Vector2, player_origin: Vector2, arena_radius: float,
	boss_radius: float, used_fallback: bool
) -> Dictionary:
	if not is_boss_arena_center_valid(center, arena_radius, player_origin):
		return {}
	var boss_position := find_safe_boss_spawn_position(center, arena_radius, boss_radius)
	if not is_finite(boss_position.x) or not is_finite(boss_position.y):
		return {}
	return {
		"center": center,
		"boss_position": boss_position,
		"used_fallback": used_fallback,
		"reposition_player": used_fallback,
	}


func is_boss_arena_center_valid(
	center: Vector2, arena_radius: float, player_origin := Vector2.INF
) -> bool:
	if not is_finite(center.x) or not is_finite(center.y) or arena_radius <= 0.0:
		return false
	var required_extent := arena_radius + BOSS_ARENA_WORLD_MARGIN
	if absf(center.x) + required_extent > WORLD_PLAYABLE_LIMIT:
		return false
	if absf(center.y) + required_extent > WORLD_PLAYABLE_LIMIT:
		return false
	var usable_radius := arena_radius - BOSS_ARENA_PLAYER_MARGIN
	if usable_radius <= 0.0:
		return false
	if is_finite(player_origin.x) and is_finite(player_origin.y):
		if player_origin.distance_to(center) > usable_radius - BOSS_ARENA_WORLD_MARGIN:
			return false
		if not _player_shape_fits_at(player_origin):
			return false
	if not _player_shape_fits_at(center):
		return false
	if _arena_intersects_hazard(center, usable_radius):
		return false
	# Landmarks are large authored structures: even the visible outer ring must not
	# cut through their solid geometry. Other environmental solids are evaluated
	# against the playable radius and navigation budget below.
	if _arena_intersects_landmark(center, arena_radius + BOSS_ARENA_WORLD_MARGIN):
		return false
	if not _boss_arena_boundary_is_clear(center, usable_radius):
		return false
	var navigation := _boss_arena_navigation_summary(center, usable_radius)
	return (
		float(navigation.free_ratio) >= BOSS_ARENA_MIN_FREE_RATIO
		and float(navigation.connected_free_ratio) >= BOSS_ARENA_MIN_CONNECTED_FREE_RATIO
	)


func _arena_intersects_hazard(center: Vector2, usable_radius: float) -> bool:
	for hazard in world.get_tree().get_nodes_in_group("arena_hazards"):
		if not is_instance_valid(hazard) or not world.is_ancestor_of(hazard):
			continue
		if hazard.global_position.distance_to(center) <= usable_radius + float(hazard.radius):
			return true
	return false


func _arena_intersects_landmark(center: Vector2, usable_radius: float) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = usable_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [world.player.get_rid()]
	for hit in world.get_world_2d().direct_space_state.intersect_shape(query, 512):
		var collider = hit.collider
		if is_instance_valid(collider) and collider.is_in_group("map_landmarks"):
			return true
	return false


func _boss_arena_boundary_is_clear(center: Vector2, usable_radius: float) -> bool:
	for sample_index in range(BOSS_ARENA_BOUNDARY_SAMPLES):
		var angle := TAU * float(sample_index) / float(BOSS_ARENA_BOUNDARY_SAMPLES)
		if not _player_shape_fits_at(center + Vector2.RIGHT.rotated(angle) * usable_radius):
			return false
	return true


func _boss_arena_navigation_summary(center: Vector2, usable_radius: float) -> Dictionary:
	var grid_radius := floori(usable_radius / BOSS_ARENA_SAMPLE_STEP)
	var free_cells: Dictionary = {}
	var total_samples := 0
	for grid_y in range(-grid_radius, grid_radius + 1):
		for grid_x in range(-grid_radius, grid_radius + 1):
			var key := Vector2i(grid_x, grid_y)
			var offset := Vector2(key) * BOSS_ARENA_SAMPLE_STEP
			if offset.length() > usable_radius:
				continue
			total_samples += 1
			if _player_shape_fits_at(center + offset):
				free_cells[key] = true
	if total_samples <= 0 or not free_cells.has(Vector2i.ZERO):
		return {"free_ratio": 0.0, "connected_free_ratio": 0.0}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var visited: Dictionary = {Vector2i.ZERO: true}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = current + direction
			if free_cells.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return {
		"free_ratio": float(free_cells.size()) / float(total_samples),
		"connected_free_ratio": float(visited.size()) / maxf(float(free_cells.size()), 1.0),
	}


func find_safe_boss_spawn_position(
	arena_center: Vector2, arena_radius: float, boss_radius: float
) -> Vector2:
	var usable_radius := arena_radius - BOSS_ARENA_PLAYER_MARGIN
	var maximum_spawn_radius := minf(
		610.0, usable_radius - boss_radius - BOSS_ARENA_WORLD_MARGIN
	)
	var minimum_spawn_radius := minf(520.0, maximum_spawn_radius)
	if maximum_spawn_radius <= boss_radius:
		return Vector2.INF
	var start_angle := randf() * TAU
	var spawn_radii: Array[float] = [
		(minimum_spawn_radius + maximum_spawn_radius) * 0.5,
		minimum_spawn_radius,
		maximum_spawn_radius,
	]
	for spawn_radius in spawn_radii:
		for angle_index in range(64):
			var angle := start_angle + TAU * float(angle_index) / 64.0
			var candidate := arena_center + Vector2.RIGHT.rotated(angle) * spawn_radius
			if is_boss_spawn_position_valid(candidate, arena_center, arena_radius, boss_radius):
				return candidate
	return Vector2.INF


func is_boss_spawn_position_valid(
	position: Vector2, arena_center: Vector2, arena_radius: float, boss_radius: float
) -> bool:
	if not is_finite(position.x) or not is_finite(position.y) or boss_radius <= 0.0:
		return false
	var usable_radius := arena_radius - BOSS_ARENA_PLAYER_MARGIN
	if position.distance_to(arena_center) + boss_radius + BOSS_ARENA_WORLD_MARGIN > usable_radius:
		return false
	if absf(position.x) + boss_radius + BOSS_ARENA_WORLD_MARGIN > WORLD_PLAYABLE_LIMIT:
		return false
	if absf(position.y) + boss_radius + BOSS_ARENA_WORLD_MARGIN > WORLD_PLAYABLE_LIMIT:
		return false
	if _position_intersects_hazard(position, boss_radius):
		return false
	var circle := CircleShape2D.new()
	circle.radius = boss_radius
	return _shape_fits_at(circle, position + Vector2(0.0, 4.0), [])


func find_safe_arena_confinement_position(
	arena_center: Vector2, intended_position: Vector2,
	radial_limit: float, body: CharacterBody2D
) -> Vector2:
	if not is_instance_valid(body) or radial_limit <= 0.0:
		return Vector2.INF
	var direction := (intended_position - arena_center).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var angular_offsets := [0.0, 0.07, -0.07, 0.14, -0.14, 0.24, -0.24, 0.36, -0.36]
	var inward_steps := [0.0, 12.0, 24.0, 40.0, 64.0, 96.0, 144.0, 192.0]
	for inward in inward_steps:
		var candidate_radius := maxf(0.0, radial_limit - float(inward))
		for angle_offset in angular_offsets:
			var candidate := arena_center + direction.rotated(float(angle_offset)) * candidate_radius
			if _body_shape_fits_at(body, candidate) and (
				body != world.player or not _position_intersects_hazard(candidate, 0.0)
			):
				return candidate
	if _body_shape_fits_at(body, arena_center) and (
		body != world.player or not _position_intersects_hazard(arena_center, 0.0)
	):
		return arena_center
	return Vector2.INF


func _position_intersects_hazard(position: Vector2, padding: float) -> bool:
	for hazard in world.get_tree().get_nodes_in_group("arena_hazards"):
		if not is_instance_valid(hazard) or not world.is_ancestor_of(hazard):
			continue
		var combined_radius := float(hazard.radius) + padding
		if hazard.global_position.distance_squared_to(position) <= combined_radius * combined_radius:
			return true
	return false


func _player_shape_fits_at(position: Vector2) -> bool:
	return _body_shape_fits_at(world.player, position)


func _body_shape_fits_at(body: CharacterBody2D, position: Vector2) -> bool:
	if not is_instance_valid(body):
		return false
	var collision_shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not is_instance_valid(collision_shape) or collision_shape.shape == null:
		return false
	var local_offset := collision_shape.position.rotated(body.global_rotation)
	return _shape_fits_at(
		collision_shape.shape, position + local_offset, [body.get_rid()], body.global_rotation + collision_shape.rotation
	)


func _shape_fits_at(
	shape: Shape2D, position: Vector2, excluded_rids: Array[RID], rotation := 0.0
) -> bool:
	if absf(position.x) > WORLD_PLAYABLE_LIMIT or absf(position.y) > WORLD_PLAYABLE_LIMIT:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(rotation, position)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = excluded_rids
	return world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


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
