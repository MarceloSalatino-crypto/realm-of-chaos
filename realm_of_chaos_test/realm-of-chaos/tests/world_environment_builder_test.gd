extends SceneTree

const GameDefs = preload("res://scripts/game_defs.gd")
const EXPECTED_FINGERPRINTS := {
	0:
		"L:1187.443,-972.001|L:-1745.951,-972.446|L:1528.383,1771.532|L:-2181.463,1517.789"
		+ "|D:-3948.120,-4676.428:0.994:0:Tree_2.png|D:26.582,-2484.364:0.653:0:bush_02.png|D:-2880.378,673.646:0.798:0:Tree_1.png|D:-3850.635,5188.012:0.905:1:Tree_2.png"
		+ "|O:2364.454,-764.659:1.155:Tree_1.png|O:-4264.422,4622.450:1.146:Tree_2.png|O:-3477.472,3049.021:1.151:Tree_3.png"
		+ "|H:2462.970,2333.371:111.538:2074339079|H:-3972.994,-3381.158:87.745:1746810272|H:-2991.708,-2881.173:87.907:764075067",
	1:
		"L:1417.601,-572.423|L:-1457.641,-1591.946|L:881.662,2094.958|L:-2526.310,711.987"
		+ "|D:895.022,1119.379:0.784:1:little stone_03.png|D:3021.972,3816.530:0.851:1:Mushroom_03.png|D:-3722.988,1838.722:1.008:0:bush_02.png|D:4123.750,-4380.529:0.970:1:bush_01.png"
		+ "|O:715.368,-484.476:1.128:Tree_1.png|O:3418.682,-525.018:1.019:Tree_2.png|O:3716.484,-3967.489:1.156:Tree_3.png"
		+ "|H:1519.975,-3523.890:102.104:3915425591|H:-2562.769,4502.639:85.756:1659196520|H:-4426.203,-4988.647:132.338:1577371512",
	2:
		"L:1670.836,121.164|L:-824.965,-1899.021|L:215.485,2244.829|L:-2741.238,-166.495"
		+ "|D:-4642.380,-4275.922:1.111:0:Tree_3.png|D:1952.251,-3365.961:0.755:0:little stone_03.png|D:3359.965,-3689.631:0.917:0:bush_01.png|D:1705.562,-3300.300:0.984:1:Mushroom_03.png"
		+ "|O:2768.512,2515.911:1.061:Tree_1.png|O:3731.604,-2970.013:0.953:Tree_2.png|O:-2043.751,-1564.846:0.833:Tree_3.png"
		+ "|H:-866.459,2804.220:111.802:1716292391|H:-719.687,3640.600:112.625:366975169|H:2534.791,2152.621:107.070:1882875190",
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WORLD ENVIRONMENT BUILDER: " + message)


func _clear_generated_environment(world: Node) -> void:
	for container in [world.decorations, world.obstacles, world.hazards, world.landmarks]:
		for child in container.get_children():
			child.queue_free()
	await process_frame


func _vector_fingerprint(value: Vector2) -> String:
	return "%.3f,%.3f" % [value.x, value.y]


func _environment_fingerprint(world: Node) -> String:
	var parts: Array[String] = []
	for position in world.landmark_positions:
		parts.append("L:" + _vector_fingerprint(position))
	for index in range(4):
		var decoration: Sprite2D = world.decorations.get_child(index)
		parts.append(
			"D:%s:%.3f:%d:%s"
			% [
				_vector_fingerprint(decoration.position),
				decoration.scale.x,
				1 if decoration.flip_h else 0,
				str(decoration.texture.resource_path).get_file(),
			]
		)
	for index in range(3):
		var obstacle: StaticBody2D = world.obstacles.get_child(index)
		var obstacle_sprite: Sprite2D = obstacle.get_child(0)
		parts.append(
			"O:%s:%.3f:%s"
			% [
				_vector_fingerprint(obstacle.position),
				obstacle_sprite.scale.x,
				str(obstacle_sprite.texture.resource_path).get_file(),
			]
		)
	for index in range(3):
		var hazard = world.hazards.get_child(index)
		parts.append(
			"H:%s:%.3f:%d"
			% [_vector_fingerprint(hazard.position), float(hazard.radius), int(hazard.seed)]
		)
	return "|".join(parts)


func _validate_cycle(world: Node, cycle: int) -> void:
	var biome: Dictionary = GameDefs.biome_data(cycle)
	var expected_hazard := "ice" if str(biome.id) == "frozen" else ("void" if str(biome.id) == "cathedral" else "roots")
	var expected_tint := Color("9ec7df") if str(biome.id) == "frozen" else (Color("9e82bb") if str(biome.id) == "cathedral" else Color("b3c7bd"))
	var expected_boundary := (
		Color(0.46, 0.78, 0.91, 0.26) if str(biome.id) == "frozen"
		else (
			Color(0.63, 0.25, 0.82, 0.26) if str(biome.id) == "cathedral"
			else Color(0.26, 0.49, 0.39, 0.24)
		)
	)
	_check(world.decorations.get_child_count() == 310, "ciclo %d nao criou 310 decoracoes" % cycle)
	_check(world.obstacles.get_child_count() == 24, "ciclo %d nao criou 24 obstaculos" % cycle)
	_check(world.hazards.get_child_count() == 18, "ciclo %d nao criou 18 perigos" % cycle)
	_check(world.landmarks.get_child_count() == 4 and world.landmark_positions.size() == 4, "ciclo %d nao criou quatro landmarks" % cycle)
	_check(str(world.ground.texture.resource_path) == str(biome.ground), "textura do solo incorreta no ciclo %d" % cycle)
	_check(world.ground.modulate.is_equal_approx(Color(biome.ground_modulate)), "modulacao do solo incorreta no ciclo %d" % cycle)
	_check(str(world.map_overlay.biome_id) == str(biome.id), "overlay recebeu bioma incorreto no ciclo %d" % cycle)
	_check(world.map_overlay.landmark_positions == world.landmark_positions, "overlay recebeu landmarks diferentes no ciclo %d" % cycle)
	_check(int(world.map_overlay.layout_seed) == 44321 + cycle * 701, "seed do overlay incorreta no ciclo %d" % cycle)
	_check(world.map_overlay.boundary_color().is_equal_approx(expected_boundary), "borda temática incorreta no ciclo %d" % cycle)

	var kinds := ["altar", "obelisk", "tree", "portal"]
	for index in range(4):
		var landmark = world.landmarks.get_child(index)
		_check(str(landmark.landmark_kind) == kinds[index], "ordem dos landmarks mudou no ciclo %d" % cycle)
		_check(landmark.global_position.is_equal_approx(world.landmark_positions[index]), "posicao do landmark %d mudou no ciclo %d" % [index, cycle])

	for decoration in world.decorations.get_children():
		_check(decoration.z_index == -4, "z-index de decoracao mudou")
		_check(decoration.scale.x >= 0.65 and decoration.scale.x <= 1.15, "escala de decoracao saiu do intervalo")
		_check(decoration.modulate.a >= 0.36 and decoration.modulate.a <= 0.72, "alpha de decoracao saiu do intervalo")
		_check(Color(decoration.modulate.r, decoration.modulate.g, decoration.modulate.b).is_equal_approx(expected_tint), "tint de decoracao incorreto")

	for obstacle in world.obstacles.get_children():
		_check(obstacle is StaticBody2D and obstacle.collision_layer == 1 and obstacle.collision_mask == 1, "corpo de obstaculo mudou")
		_check(obstacle.get_child_count() == 2 and obstacle.get_child(1) is CollisionShape2D, "estrutura de obstaculo mudou")
		var sprite: Sprite2D = obstacle.get_child(0)
		var collision: CollisionShape2D = obstacle.get_child(1)
		_check(sprite.modulate.is_equal_approx(Color(expected_tint, 0.90)), "tint tematico do obstaculo incorreto no ciclo %d" % cycle)
		_check(collision.shape is CircleShape2D and is_equal_approx(collision.shape.radius, 18.0 * sprite.scale.x), "raio de colisao do obstaculo mudou")
		_check(is_equal_approx(collision.position.y, 7.0), "offset da colisao do obstaculo mudou")

	for hazard in world.hazards.get_children():
		_check(str(hazard.hazard_kind) == expected_hazard, "tipo de perigo incorreto no ciclo %d" % cycle)
		_check(hazard.radius >= 82.0 and hazard.radius <= 138.0, "raio de perigo saiu do intervalo")
		_check(hazard.is_in_group("arena_hazards"), "perigo perdeu seu grupo")
		_check(hazard.get_node_or_null("VisibleOnScreenNotifier2D") != null, "perigo perdeu o notifier visual")

	var fingerprint := _environment_fingerprint(world)
	print("ENVIRONMENT FINGERPRINT %d: %s" % [cycle, fingerprint])
	if EXPECTED_FINGERPRINTS.has(cycle):
		_check(fingerprint == str(EXPECTED_FINGERPRINTS[cycle]), "sequencia deterministica mudou no ciclo %d" % cycle)


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)

	for method in [
		"_apply_biome", "_generate_environment", "_generate_map_layout",
		"_find_free_map_position", "_point_segment_distance", "_generate_obstacles",
		"_generate_hazards", "_spawn_position_is_clear", "get_environment_effect"
	]:
		_check(world.has_method(method), "API ambiental ausente: " + method)
	_check(world.get_node_or_null("ArenaHazards") == world.hazards, "container de perigos mudou")
	_check(world.get_node_or_null("Landmarks") == world.landmarks, "container de landmarks mudou")
	_check(world.get_node_or_null("PhysicalObstacles") == world.obstacles, "container de obstaculos mudou")
	_check(world.get_node_or_null("MapOverlay") == world.map_overlay, "overlay deixou de ser filho do World")
	_check(world.rewards.get_index() < world.hazards.get_index() and world.hazards.get_index() < world.landmarks.get_index(), "ordem inicial dos containers mudou")
	_check(world.landmarks.get_index() < world.obstacles.get_index() and world.obstacles.get_index() < world.map_overlay.get_index(), "ordem final dos containers mudou")

	_check(is_equal_approx(world._point_segment_distance(Vector2(5.0, 4.0), Vector2.ZERO, Vector2(10.0, 0.0)), 4.0), "distancia perpendicular ao segmento mudou")
	_check(is_equal_approx(world._point_segment_distance(Vector2(15.0, 0.0), Vector2.ZERO, Vector2(10.0, 0.0)), 5.0), "clamp na ponta do segmento mudou")
	_check(is_equal_approx(world._point_segment_distance(Vector2(3.0, 4.0), Vector2.ZERO, Vector2.ZERO), 5.0), "segmento degenerado mudou")

	for cycle in range(3):
		await _clear_generated_environment(world)
		world.run_cycle = cycle
		world.biome = GameDefs.biome_data(cycle)
		world._apply_biome()
		world._generate_environment()
		await process_frame
		_validate_cycle(world, cycle)

	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 77123
	var first_free_position: Vector2 = world._find_free_map_position(first_rng, 5400.0)
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 77123
	var second_free_position: Vector2 = world._find_free_map_position(second_rng, 5400.0)
	_check(first_free_position.is_equal_approx(second_free_position), "busca de posicao livre deixou de ser deterministica")
	_check(first_free_position.length() >= 430.0, "busca de posicao livre entrou na area central")

	var temporary_obstacle := Node2D.new()
	world.obstacles.add_child(temporary_obstacle)
	temporary_obstacle.global_position = Vector2.ZERO
	_check(not world._spawn_position_is_clear(Vector2.ZERO), "spawn ignorou obstaculo dentro de 105px")
	temporary_obstacle.global_position = Vector2(106.0, 0.0)
	_check(world._spawn_position_is_clear(Vector2.ZERO), "spawn bloqueou obstaculo fora de 105px")
	temporary_obstacle.queue_free()
	await process_frame

	var temporary_landmark := Node2D.new()
	world.landmarks.add_child(temporary_landmark)
	temporary_landmark.global_position = Vector2.ZERO
	_check(not world._spawn_position_is_clear(Vector2.ZERO), "spawn ignorou landmark dentro de 145px")
	temporary_landmark.global_position = Vector2(146.0, 0.0)
	_check(world._spawn_position_is_clear(Vector2.ZERO), "spawn bloqueou landmark fora de 145px")
	temporary_landmark.queue_free()
	await process_frame

	var first_hazard = world.hazards.get_child(0)
	var hazard_effect: Dictionary = world.get_environment_effect(first_hazard.global_position)
	_check(str(hazard_effect.name) == "FENDA DO VAZIO" and is_equal_approx(float(hazard_effect.damage), 9.0), "efeito do perigo cathedral mudou")
	var neutral_effect: Dictionary = world.get_environment_effect(Vector2.ZERO)
	_check(is_equal_approx(float(neutral_effect.speed), 1.0) and str(neutral_effect.name).is_empty(), "efeito ambiental neutro mudou")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("WORLD ENVIRONMENT BUILDER OK: biomas, layout, decoracoes, obstaculos, perigos e consultas validados")
	quit(0 if failures.is_empty() else 1)
