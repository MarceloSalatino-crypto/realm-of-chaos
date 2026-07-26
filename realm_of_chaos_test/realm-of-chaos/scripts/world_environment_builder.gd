extends RefCounted

const ArenaHazardScript = preload("res://scripts/arena_hazard.gd")
const MapOverlayScript = preload("res://scripts/map_overlay.gd")
const MapLandmarkScript = preload("res://scripts/map_landmark.gd")

var world


func _init(owner_world) -> void:
	world = owner_world


func create_runtime_nodes() -> void:
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


func generate_environment() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 864210 + world.run_cycle * 913
	generate_map_layout(rng)
	var texture_paths := [
		"res://assets/environment/Tree/Tree_1.png", "res://assets/environment/Tree/Tree_2.png",
		"res://assets/environment/Tree/Tree_3.png", "res://assets/environment/props/bush/bush_01.png",
		"res://assets/environment/props/bush/bush_02.png", "res://assets/environment/props/Mushroom/Mushroom_03.png",
		"res://assets/environment/props/little stone/little stone_03.png"
	]
	var textures: Array[Texture2D] = []
	for path in texture_paths:
		textures.append(load(path))
	var biome_tint := Color("9ec7df") if str(world.biome.id) == "frozen" else (Color("9e82bb") if str(world.biome.id) == "cathedral" else Color("b3c7bd"))
	for _index in range(310):
		var sprite := Sprite2D.new()
		sprite.texture = textures[rng.randi_range(0, textures.size() - 1)]
		var decoration_position := find_free_map_position(rng, 5400.0)
		sprite.position = decoration_position
		var scale_value := rng.randf_range(0.65, 1.15)
		sprite.scale = Vector2.ONE * scale_value
		sprite.flip_h = rng.randf() < 0.5
		sprite.modulate = Color(biome_tint, rng.randf_range(0.36, 0.72))
		sprite.z_index = -4
		world.decorations.add_child(sprite)
	generate_obstacles(rng)
	generate_hazards(rng)


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
	return candidate


func point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func generate_obstacles(rng: RandomNumberGenerator) -> void:
	var obstacle_textures: Array[Texture2D] = [
		load("res://assets/environment/Tree/Tree_1.png"),
		load("res://assets/environment/Tree/Tree_2.png"),
		load("res://assets/environment/Tree/Tree_3.png"),
		load("res://assets/environment/props/little stone/little stone_03.png")
	]
	for index in range(24):
		var body := StaticBody2D.new()
		body.position = find_free_map_position(rng, 5150.0)
		body.z_index = -3
		body.collision_layer = 1
		body.collision_mask = 1
		var obstacle_sprite := Sprite2D.new()
		obstacle_sprite.texture = obstacle_textures[index % obstacle_textures.size()]
		var obstacle_scale := rng.randf_range(0.82, 1.18)
		obstacle_sprite.scale = Vector2.ONE * obstacle_scale
		obstacle_sprite.modulate = Color(0.76, 0.82, 0.86, 0.90)
		body.add_child(obstacle_sprite)
		var collision := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 18.0 * obstacle_scale
		collision.position.y = 7.0
		collision.shape = circle
		body.add_child(collision)
		world.obstacles.add_child(body)


func generate_hazards(rng: RandomNumberGenerator) -> void:
	var hazard_kind := "roots"
	if str(world.biome.id) == "frozen":
		hazard_kind = "ice"
	elif str(world.biome.id) == "cathedral":
		hazard_kind = "void"
	for _index in range(18):
		var hazard_position := find_free_map_position(rng, 5000.0)
		var hazard = ArenaHazardScript.new()
		world.hazards.add_child(hazard)
		hazard.setup(hazard_kind, hazard_position, rng.randf_range(82.0, 138.0), rng.randi())


func is_spawn_position_clear(position: Vector2) -> bool:
	if is_instance_valid(world.obstacles):
		for obstacle in world.obstacles.get_children():
			if is_instance_valid(obstacle) and obstacle.global_position.distance_squared_to(position) < 105.0 * 105.0:
				return false
	if is_instance_valid(world.landmarks):
		for landmark in world.landmarks.get_children():
			if is_instance_valid(landmark) and landmark.global_position.distance_squared_to(position) < 145.0 * 145.0:
				return false
	return true


func get_environment_effect(position: Vector2) -> Dictionary:
	for hazard in world.get_tree().get_nodes_in_group("arena_hazards"):
		if is_instance_valid(hazard) and hazard.contains_point(position):
			return hazard.effect_data()
	return {"speed": 1.0, "traction": 1.0, "damage": 0.0, "name": ""}
