extends SceneTree

const CampaignCatalogScript = preload("res://scripts/campaign_catalog.gd")
const MapEncounterCatalogScript = preload("res://scripts/map_encounter_catalog.gd")

const EXPECTED_SMALL_DECORATIONS := 1200
const EXPECTED_FLOOR_DECALS := 36
const EXPECTED_OBSTACLES := 36
const EXPECTED_FOREST_GROVE_LOBES := 55
const EXPECTED_VISUAL_INSTANCES := EXPECTED_SMALL_DECORATIONS + EXPECTED_FLOOR_DECALS + EXPECTED_OBSTACLES
const EXPECTED_CHUNK_SIZE := 1536.0

const SMALL_DECORATION_FILES := {
	"bush_01.png": true,
	"bush_02.png": true,
	"Mushroom_03.png": true,
	"Flowers_01.png": true,
	"Flowers_02.png": true,
	"Flowers_03.png": true,
	"Grass_transition_01.png": true,
	"Grass_transition_02.png": true,
	"leaf_litter.png": true,
	"broken_branches.png": true,
	"twig_scatter.png": true,
	"gravel_scatter.png": true,
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("WORLD ENVIRONMENT BUILDER: " + message)


func _clear_generated_environment(world: Node) -> void:
	world.environment_builder.visual_batcher.reset()
	for container in [world.obstacles, world.hazards, world.landmarks]:
		for child in container.get_children():
			child.queue_free()
	await process_frame


func _vector_fingerprint(value: Vector2) -> String:
	return "%.3f,%.3f" % [value.x, value.y]


func _environment_fingerprint(world: Node) -> String:
	var parts: Array[String] = []
	for position in world.landmark_positions:
		parts.append("L:" + _vector_fingerprint(position))
	var visuals: Array[Dictionary] = world.environment_builder.visual_batcher.visual_instances
	for index in range(4):
		var visual: Dictionary = visuals[index]
		parts.append(
			"D:%s:%.3f:%d:%s"
			% [
				_vector_fingerprint(Vector2(visual.position)),
				Vector2(visual.scale).x,
				1 if bool(visual.flip_h) else 0,
				str(visual.source_path).get_file(),
			]
		)
	for index in range(3):
		var obstacle: StaticBody2D = world.obstacles.get_child(index)
		var obstacle_visual: Dictionary = visuals[EXPECTED_SMALL_DECORATIONS + EXPECTED_FLOOR_DECALS + index]
		parts.append(
			"O:%s:%.3f:%s"
			% [
				_vector_fingerprint(obstacle.position),
				Vector2(obstacle_visual.scale).x,
				str(obstacle_visual.atlas_key),
			]
		)
	for index in range(mini(3, world.hazards.get_child_count())):
		var hazard = world.hazards.get_child(index)
		parts.append("H:%s:%.3f:%d" % [_vector_fingerprint(hazard.position), float(hazard.radius), int(hazard.seed)])
	if world.hazards.get_child_count() == 0:
		parts.append("H:none")
	return "|".join(parts)


func _validate_batches(world: Node, cycle: int) -> void:
	var batcher = world.environment_builder.visual_batcher
	_check(batcher.visual_instances.size() == EXPECTED_VISUAL_INSTANCES, "ciclo %d nao registrou 1.272 visuais" % cycle)
	_check(batcher.chunk_count() > 0 and batcher.chunk_count() <= 64, "ciclo %d criou quantidade invalida de chunks" % cycle)
	_check(batcher.batch_count() == world.decorations.get_child_count(), "container de decoracao divergiu dos lotes")
	_check(batcher.batch_count() < 200, "ciclo %d criou lotes demais para 1.272 visuais" % cycle)
	_check(batcher.atlas_regions.size() == 25, "atlas unificado nao possui as 25 fontes esperadas")
	for source in batcher.atlas_regions.values():
		_check(
			not str(source.path).contains("map_floor_decals_v1"),
			"atlas legado de decalques voltou a ser usado"
		)
	var expected_prefix := "frozen" if cycle == 1 else ("cathedral" if cycle == 2 else "forest")
	for decal_kind in ["crater", "ritual", "battle"]:
		var expected_key := "%s_floor_%s" % [expected_prefix, decal_kind]
		_check(batcher.atlas_regions.has(expected_key), "atlas perdeu variante do bioma: " + expected_key)
	var rendered_instances := 0
	for child in world.decorations.get_children():
		_check(child is MultiMeshInstance2D, "decoracao ainda criou no que nao e MultiMeshInstance2D")
		if not child is MultiMeshInstance2D:
			continue
		var instance := child as MultiMeshInstance2D
		_check(instance.name.begins_with("DecorationChunk_"), "lote perdeu identificacao de chunk")
		_check(instance.multimesh.use_colors and instance.multimesh.use_custom_data, "lote perdeu cor ou UV por instancia")
		_check(instance.texture == batcher.atlas_texture, "lote nao usa o atlas compartilhado")
		rendered_instances += instance.multimesh.visible_instance_count
	_check(rendered_instances == EXPECTED_VISUAL_INSTANCES, "MultiMesh nao desenha todas as instancias registradas")


func _validate_visual_records(world: Node, expected_tint: Color, cycle: int) -> void:
	var visuals: Array[Dictionary] = world.environment_builder.visual_batcher.visual_instances
	var small_count := 0
	var floor_count := 0
	var tree_count := 0
	var stone_count := 0
	var initial_area_count := 0
	var corridor_count := 0
	var forest_flower_count := 0
	var forest_low_vegetation_count := 0
	var forest_context_counts := {
		"route": 0,
		"settlement": 0,
		"dense": 0,
		"background": 0,
	}
	for visual in visuals:
		var source_kind := str(visual.source_kind)
		var position := Vector2(visual.position)
		if source_kind.begins_with("decoration"):
			small_count += 1
			var is_forest := cycle % 3 == 0
			var file_name := str(visual.source_path).get_file()
			_check(SMALL_DECORATION_FILES.has(file_name), "decoracao atravessavel usa fonte solida: " + file_name)
			var minimum_scale := 0.65
			var maximum_scale := 1.15
			var minimum_alpha := 0.34
			var maximum_alpha := 0.58
			if is_forest:
				if file_name.begins_with("Flowers_"):
					forest_flower_count += 1
				elif file_name.begins_with("Grass_transition_"):
					forest_low_vegetation_count += 1
				var context := source_kind.trim_prefix("decoration_")
				var category := "settlement" if context.begins_with("settlement_") else context
				forest_context_counts[category] = int(forest_context_counts.get(category, 0)) + 1
				if category == "route":
					minimum_scale = 0.50
					maximum_scale = 0.88
					minimum_alpha = 0.19
					maximum_alpha = 0.36
				elif category == "settlement":
					if context == "settlement_stone":
						minimum_scale = 0.56
						maximum_scale = 0.96
						minimum_alpha = 0.28
						maximum_alpha = 0.48
					else:
						minimum_scale = 0.50
						maximum_scale = 0.94
						minimum_alpha = 0.22
						maximum_alpha = 0.44
				elif category == "dense":
					minimum_scale = 0.52
					maximum_scale = 0.90
					minimum_alpha = 0.20
					maximum_alpha = 0.40
				else:
					minimum_scale = 0.42
					maximum_scale = 0.72
					minimum_alpha = 0.10
					maximum_alpha = 0.20
			var is_flora := file_name.begins_with("Flowers_") or file_name.begins_with("Grass_transition_")
			if not is_flora:
				_check(Vector2(visual.scale).x >= minimum_scale and Vector2(visual.scale).x <= maximum_scale, "escala da decoracao saiu do intervalo")
				_check(Color(visual.color).a >= minimum_alpha and Color(visual.color).a <= maximum_alpha, "alpha da decoracao saiu do intervalo")
			var detail_color := Color(visual.color)
			if is_forest:
				if not is_flora:
					_check(
						detail_color.r >= 0.40 and detail_color.r <= 0.56
						and detail_color.g >= 0.45 and detail_color.g <= 0.60
						and detail_color.b >= 0.43 and detail_color.b <= 0.58,
						"detalhe do Bosque saiu da paleta integrada"
					)
			else:
				_check(Color(detail_color.r, detail_color.g, detail_color.b).is_equal_approx(expected_tint), "tint da decoracao incorreto")
			if position.length() < 430.0:
				initial_area_count += 1
			for landmark_position in world.landmark_positions:
				if world._point_segment_distance(position, Vector2.ZERO, landmark_position) < 165.0:
					corridor_count += 1
					break
		elif source_kind.begins_with("floor_"):
			floor_count += 1
			var expected_prefix := "frozen" if cycle == 1 else ("cathedral" if cycle == 2 else "forest")
			_check(str(visual.atlas_key).begins_with(expected_prefix + "_floor_"), "decalque recebeu variante de outro bioma")
			_check(Color(visual.color).r == 1.0 and Color(visual.color).g == 1.0 and Color(visual.color).b == 1.0, "paleta do decalque ainda recebe tint generico")
		elif source_kind == "obstacle_tree":
			tree_count += 1
			if cycle % 3 == 0:
				_check(is_zero_approx(Color(visual.color).a), "visual antigo de arvore vazou sob a composicao integrada do Bosque")
		elif source_kind == "obstacle_stone":
			stone_count += 1
	_check(small_count == EXPECTED_SMALL_DECORATIONS, "ciclo %d nao criou 1.200 decoracoes baixas" % cycle)
	_check(floor_count == EXPECTED_FLOOR_DECALS, "ciclo %d nao criou 36 decalques" % cycle)
	_check(tree_count == 26 and stone_count == 10, "visuais fisicos nao ficaram em 26 arvores + 10 pedras")
	if cycle % 3 == 0:
		_check(int(forest_context_counts.route) == 480, "Bosque perdeu os 40% de detalhes das bordas dos caminhos")
		_check(int(forest_context_counts.settlement) == 420, "Bosque perdeu os 35% de assentamentos ambientais")
		_check(int(forest_context_counts.dense) == 180, "Bosque perdeu os 15% de conexão da região densa")
		_check(int(forest_context_counts.background) == 120, "Bosque perdeu os 10% de variação ambiental leve")
		_check(forest_flower_count >= 60 and forest_flower_count <= 160, "flores discretas não formaram agrupamentos naturais")
		_check(forest_low_vegetation_count >= 120, "grama e musgo baixos continuam ausentes do chão")
	_check(initial_area_count > 0, "decoracoes visuais continuam excluidas da area inicial")
	_check(corridor_count > 0, "decoracoes visuais continuam excluidas dos corredores")


func _validate_obstacles(world: Node, expected_tint: Color, cycle: int) -> void:
	var is_forest := cycle % 3 == 0
	var expected_body_count := EXPECTED_OBSTACLES + (EXPECTED_FOREST_GROVE_LOBES if is_forest else 0)
	_check(world.obstacles.get_child_count() == expected_body_count, "ciclo %d criou população física incorreta" % cycle)
	_check(not world.environment_builder.obstacle_grid.is_empty(), "grade espacial de obstaculos ficou vazia")
	var obstacle_positions: Array[Vector2] = []
	var original_count := 0
	var lobe_count := 0
	for obstacle in world.obstacles.get_children():
		_check(obstacle is StaticBody2D and obstacle.collision_layer == 1 and obstacle.collision_mask == 1, "corpo de obstaculo mudou")
		_check(obstacle.is_in_group("physical_obstacles"), "obstaculo perdeu o grupo central")
		_check(world.environment_builder.obstacles_near(obstacle.global_position, 1.0).has(obstacle), "grade nao encontra obstaculo na propria celula")
		var kind := str(obstacle.get_meta("environment_obstacle_kind", ""))
		if not kind.is_empty():
			original_count += 1
			obstacle_positions.append(obstacle.position)
			var shapes: Array[Node] = obstacle.find_children("*", "CollisionShape2D", true, false)
			if is_forest and kind == "tree":
				_check(shapes.is_empty(), "âncora antiga de árvore manteve colisor duplicado no Bosque")
			else:
				_check(shapes.size() == 1 and shapes[0].shape is CircleShape2D, "obstáculo original perdeu o círculo da base")
				if shapes.size() == 1 and shapes[0].shape is CircleShape2D:
					var base_scale: float = float(shapes[0].shape.radius) / 18.0
					_check(base_scale >= 0.82 and base_scale <= 1.18, "raio de colisao saiu do intervalo")
					_check(is_equal_approx(shapes[0].position.y, 7.0), "offset do colisor mudou")
		elif obstacle.is_in_group("forest_collision_lobes"):
			lobe_count += 1
			var lobe_shapes: Array[Node] = obstacle.find_children("*", "CollisionShape2D", true, false)
			_check(lobe_shapes.size() == 1 and lobe_shapes[0].shape is CapsuleShape2D, "massa florestal não usa cápsula simples")
		else:
			_check(false, "corpo físico sem identidade entrou no mapa")
	_check(original_count == EXPECTED_OBSTACLES, "as 36 âncoras determinísticas mudaram")
	_check(lobe_count == (EXPECTED_FOREST_GROVE_LOBES if is_forest else 0), "quantidade de massas florestais incorreta")
	for first_index in range(obstacle_positions.size()):
		for second_index in range(first_index + 1, obstacle_positions.size()):
			_check(obstacle_positions[first_index].distance_to(obstacle_positions[second_index]) >= 179.99, "obstaculos violaram espacamento minimo")
	var obstacle_visual: Dictionary = world.environment_builder.visual_batcher.visual_instances[EXPECTED_SMALL_DECORATIONS + EXPECTED_FLOOR_DECALS]
	var obstacle_color := Color(obstacle_visual.color)
	_check(
		Color(obstacle_color.r, obstacle_color.g, obstacle_color.b).is_equal_approx(expected_tint),
		"tint tematico do obstaculo mudou"
	)
	_check(
		is_equal_approx(obstacle_color.a, 0.90) or (cycle % 3 == 0 and is_zero_approx(obstacle_color.a)),
		"obstaculo perdeu alpha normal ou substituição visual do bosque"
	)


func _validate_cycle(world: Node, cycle: int) -> String:
	var biome: Dictionary = GameDefs.biome_data(cycle)
	var expected_hazard := "ice" if str(biome.id) == "frozen" else ("void" if str(biome.id) == "cathedral" else "")
	var expected_hazard_count := 0 if str(biome.id) == "forest" else 18
	var expected_tint := Color("9ec7df") if str(biome.id) == "frozen" else (Color("9e82bb") if str(biome.id) == "cathedral" else Color("81978e"))
	_check(world.hazards.get_child_count() == expected_hazard_count, "ciclo %d criou quantidade incorreta de perigos" % cycle)
	_check(world.landmarks.get_child_count() == 4 and world.landmark_positions.size() == 4, "ciclo %d nao criou quatro landmarks" % cycle)
	_check(str(world.ground.texture.resource_path) == str(biome.ground), "textura do solo incorreta")
	_check(world.ground.modulate.is_equal_approx(Color(biome.ground_modulate)), "modulacao do solo incorreta")
	var terrain_summary: Dictionary = world.environment_builder.terrain_composer.summary()
	var collision_summary: Dictionary = world.environment_builder.forest_collision_composer.summary()
	if str(biome.id) == "forest":
		_check(is_instance_valid(world.ground.material), "Bosque perdeu o material contínuo de terreno")
		_check(bool(terrain_summary.active), "compositor do Bosque não ficou ativo")
		_check(str(terrain_summary.representation) == "continuous_material_mask", "terreno voltou a usar decalques de trilha")
		_check(int(terrain_summary.route_count) == 5, "rede orgânica não criou cinco trajetos")
		var route_states: Dictionary = terrain_summary.route_state_counts
		_check(int(route_states.visible) > 0, "rede não possui trechos de barro exposto")
		_check(int(route_states.overgrown) > 0, "rede não possui trechos parcialmente tomados")
		_check(int(route_states.faded) > 0, "rede não possui trechos quase desaparecidos")
		_check(int(terrain_summary.apron_count) == 40, "transições não cobrem 4 landmarks e 36 obstáculos")
		_check(int(terrain_summary.dense_bridge_count) == 2, "região densa perdeu as duas conexões de terreno")
		_check(int(terrain_summary.grove_count) == 26, "Bosque não integrou as 26 árvores físicas à composição")
		_check(int(terrain_summary.dense_grove_count) == 3, "Bosque não preservou três âncoras realmente densas")
		_check(int(terrain_summary.settlement_anchor_count) == 40, "árvores, pedras e landmarks não receberam assentamentos")
		_check(bool(terrain_summary.layout_finalized), "detalhes não usam a rede final de caminhos")
		_check(int(terrain_summary.layout_revision) == int(terrain_summary.detail_layout_revision), "rede dos detalhes divergiu da rede renderizada")
		_check(int(terrain_summary.semantic_region_count) == 5, "composição não cobre cinco regiões semânticas")
		_check(bool(collision_summary.active), "perfis físicos visuais do Bosque não foram aplicados")
		_check(int(collision_summary.grove_lobes) == EXPECTED_FOREST_GROVE_LOBES, "massas sólidas do Bosque não cobrem os troncos e raízes")
		_check(int(collision_summary.landmark_shapes) == 17, "landmarks não receberam colisões completas específicas")
	else:
		_check(world.ground.material == null, "material do Bosque vazou para outro bioma")
		_check(not bool(collision_summary.active), "perfil físico do Bosque vazou para outro bioma")
	_check(str(world.map_overlay.biome_id) == str(biome.id), "overlay recebeu bioma incorreto")
	_validate_batches(world, cycle)
	_validate_visual_records(world, expected_tint, cycle)
	_validate_obstacles(world, expected_tint, cycle)
	for hazard in world.hazards.get_children():
		_check(str(hazard.hazard_kind) == expected_hazard, "tipo de perigo incorreto no ciclo %d" % cycle)
		_check(hazard.radius >= 82.0 and hazard.radius <= 138.0, "raio de perigo saiu do intervalo")
		_check(hazard.get_node_or_null("VisibleOnScreenNotifier2D") != null, "perigo perdeu o notifier")
	return _environment_fingerprint(world)


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	var initial_node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var initial_batch_count: int = world.environment_builder.visual_batcher.batch_count()

	for method in [
		"_apply_biome", "_generate_environment", "_generate_map_layout",
		"_find_free_map_position", "_point_segment_distance", "_generate_obstacles",
		"_generate_hazards", "_spawn_position_is_clear", "get_environment_effect",
		"spawn_enemy_near"
	]:
		_check(world.has_method(method), "API ambiental ausente: " + method)
	_check(world.get_node_or_null("PhysicalObstacles") == world.obstacles, "container de obstaculos mudou")
	_check(world.get_node_or_null("MapOverlay") == world.map_overlay, "overlay deixou de ser filho do World")
	_check(is_equal_approx(world._point_segment_distance(Vector2(5.0, 4.0), Vector2.ZERO, Vector2(10.0, 0.0)), 4.0), "distancia ao segmento mudou")

	var fingerprints: Dictionary = {}
	var map_ids: Array[String] = ["profaned_forest", "frozen_ruins", "void_cathedral"]
	for cycle in range(3):
		await _clear_generated_environment(world)
		world.campaign_map = CampaignCatalogScript.map_data(map_ids[cycle])
		world.encounter_profile = MapEncounterCatalogScript.profile(str(world.campaign_map.encounter_profile_id))
		world.run_cycle = cycle
		world.map_seed_offset = cycle
		world.biome = GameDefs.biome_data(cycle)
		world._apply_biome()
		world._generate_environment()
		await process_frame
		fingerprints[cycle] = _validate_cycle(world, cycle)

	await _clear_generated_environment(world)
	world.run_cycle = 1
	world.map_seed_offset = 1
	world.biome = GameDefs.biome_data(1)
	world._apply_biome()
	world._generate_environment()
	await process_frame
	_check(_environment_fingerprint(world) == str(fingerprints[1]), "geracao deixou de ser deterministica")

	var temporary_obstacle := StaticBody2D.new()
	temporary_obstacle.global_position = Vector2.ZERO
	world.obstacles.add_child(temporary_obstacle)
	world.environment_builder.rebuild_obstacle_grid()
	_check(not world._spawn_position_is_clear(Vector2.ZERO), "spawn ignorou obstaculo dentro de 105px")
	temporary_obstacle.global_position = Vector2(106.0, 0.0)
	world.environment_builder.rebuild_obstacle_grid()
	_check(world._spawn_position_is_clear(Vector2.ZERO), "spawn bloqueou obstaculo fora de 105px")
	temporary_obstacle.queue_free()
	await process_frame
	world.environment_builder.rebuild_obstacle_grid()

	var clear_spawn: Vector2 = world.environment_builder.find_clear_spawn_position(Vector2.ZERO, 610.0, 760.0)
	_check(is_finite(clear_spawn.x) and world._spawn_position_is_clear(clear_spawn), "busca de spawn nao retornou posicao valida")
	var impossible_spawn: Vector2 = world.environment_builder.find_clear_spawn_position(Vector2(7000.0, 7000.0), 10.0, 20.0, 0)
	_check(not is_finite(impossible_spawn.x), "fallback inseguro ainda retorna posicao invalida")

	var first_hazard = world.hazards.get_child(0)
	var hazard_effect: Dictionary = world.get_environment_effect(first_hazard.global_position)
	_check(not str(hazard_effect.name).is_empty(), "efeito do perigo nao foi encontrado")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print(
			"WORLD ENVIRONMENT BUILDER OK: 1.200 decoracoes em %d lotes; cena inicial com %d nos; colisores, grade e spawn seguro validados"
			% [initial_batch_count, initial_node_count]
		)
	quit(0 if failures.is_empty() else 1)
