extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const EFFECT_SCRIPT := preload("res://scripts/effect.gd")

const ENEMY_TYPES := [
	"prowler", "bat", "mage", "brute", "ember", "bomber",
	"necromancer", "archer", "assassin", "swarm", "guardian",
]
const COMBAT_ENEMIES := 64
const MEASURED_FRAMES := 90
const MAX_AVERAGE_MS := 14.0
const MAX_P95_MS := 22.0

var failures: Array[String] = []
var capture_directory := ""


func _initialize() -> void:
	capture_directory = OS.get_environment("ROC_FOREST_MAIN_CAPTURE_DIR")
	if not capture_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_directory)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FOREST TERRAIN INTEGRATION: " + message)


func _focus(world: Node, world_position: Vector2) -> void:
	world.player.global_position = world_position
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()


func _capture(world: Node, capture_name: String, suppress_level_up := false) -> void:
	for _frame in range(6):
		if suppress_level_up:
			world.hud.hide_level_up()
			paused = false
		await process_frame
	RenderingServer.force_draw(false, 0.0)
	var screenshot := world.get_viewport().get_texture().get_image()
	_check(not screenshot.is_empty(), "captura vazia: " + capture_name)
	if screenshot.is_empty():
		return
	var output_path := "user://forest_main_%s.png" % capture_name
	if not capture_directory.is_empty():
		output_path = capture_directory.path_join("forest_main_%s.png" % capture_name)
	_check(screenshot.save_png(output_path) == OK, "não foi possível salvar " + output_path)
	print("FOREST MAIN CAPTURE: " + ProjectSettings.globalize_path(output_path))


func _densest_obstacle_center(world: Node) -> Vector2:
	var best_center := Vector2(1450.0, 0.0)
	var best_count := -1
	for candidate in world.obstacles.get_children():
		var nearby: Array = world.environment_builder.obstacles_near(candidate.position, 720.0)
		var count := 0
		var center := Vector2.ZERO
		for obstacle in nearby:
			if obstacle.position.distance_to(candidate.position) <= 720.0:
				count += 1
				center += obstacle.position
		if count > best_count:
			best_count = count
			best_center = center / float(maxi(count, 1))
	return best_center


func _spawn_combat_scene(world: Node) -> void:
	for index in range(COMBAT_ENEMIES):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], index % 17 == 0, 3.0)
		_check(is_instance_valid(enemy), "inimigo real não foi criado no índice %d" % index)
		if not is_instance_valid(enemy):
			continue
		var angle := TAU * float(index) / float(COMBAT_ENEMIES)
		var ring := 285.0 + float(index % 5) * 54.0
		enemy.global_position = Vector2.RIGHT.rotated(angle) * ring
		enemy.set_physics_process(false)
	for index in range(30):
		var angle := TAU * float(index) / 30.0
		var projectile = BULLET_SCENE.instantiate()
		projectile.global_position = Vector2.RIGHT.rotated(angle) * (105.0 + float(index % 4) * 22.0)
		projectile.setup(Vector2.RIGHT.rotated(angle + PI * 0.5), 0.0, 28.0, 999, 8.0, Color("a96cff"))
		projectile.lifetime = 8.0
		world.add_player_projectile(projectile)
	for index in range(18):
		var angle := TAU * float(index) / 18.0
		var projectile = world.spawn_enemy_projectile(
			Vector2.RIGHT.rotated(angle) * (225.0 + float(index % 3) * 25.0),
			Vector2.RIGHT.rotated(angle + PI * 0.5), 0.0, 26.0,
			Color("ff496d"), 8.0, index % 3 == 0
		)
		if is_instance_valid(projectile):
			projectile.lifetime = 8.0
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		world._spawn_pickup(
			1 + index % 3,
			Vector2.RIGHT.rotated(angle) * (175.0 + float(index % 3) * 24.0), "xp"
		)
	for index in range(18):
		var effect = EFFECT_SCRIPT.new()
		world.effects.add_child(effect)
		var angle := TAU * float(index) / 18.0
		effect.setup(
			Vector2.RIGHT.rotated(angle) * (130.0 + float(index % 4) * 58.0),
			Color("8f62cc").lerp(Color("cf496d"), float(index % 4) / 3.0),
			38.0 + float(index % 3) * 9.0, 4.0, index % 3 == 0, 0
		)


func _regenerate_as_forest(world: Node) -> void:
	world.environment_builder.visual_batcher.reset()
	for container in [world.obstacles, world.hazards, world.landmarks]:
		for child in container.get_children():
			child.queue_free()
	await process_frame
	world.run_cycle = 0
	world.map_seed_offset = 0
	world.biome = GameDefs.biome_data(0)
	world._apply_biome()
	world._generate_environment()
	await process_frame


func _measure_frames(frame_count: int) -> Dictionary:
	var frame_times: Array[float] = []
	var total_started := Time.get_ticks_usec()
	for _frame in range(frame_count):
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	var total_ms := float(Time.get_ticks_usec() - total_started) / 1000.0
	frame_times.sort()
	var p95_index := mini(frame_times.size() - 1, ceili(float(frame_times.size()) * 0.95) - 1)
	return {"average_ms": total_ms / float(frame_count), "p95_ms": frame_times[p95_index]}


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true
	world.player.set_physics_process(false)
	world.camera.position_smoothing_enabled = false
	world.hud.visible = false
	await _regenerate_as_forest(world)

	var terrain_summary: Dictionary = world.environment_builder.terrain_composer.summary()
	_check(str(world.biome.id) == "forest", "world.tscn não iniciou no Bosque Profanado")
	_check(bool(terrain_summary.active), "material contínuo não está ativo no mapa principal")
	_check(str(terrain_summary.representation) == "continuous_material_mask", "trilhas ainda dependem de sprites")
	_check(int(terrain_summary.route_count) == 5, "rede de trajetos incompleta")
	var route_states: Dictionary = terrain_summary.route_state_counts
	_check(int(route_states.visible) > 0, "caminhos não possuem trechos visíveis")
	_check(int(route_states.overgrown) > 0, "caminhos não possuem trechos parcialmente tomados")
	_check(int(route_states.faded) > 0, "caminhos não possuem trechos quase desaparecidos")
	_check(bool(terrain_summary.layout_finalized), "detalhes não usam a rede final de caminhos")
	_check(int(terrain_summary.layout_revision) == int(terrain_summary.detail_layout_revision), "rede visual e distribuição divergem")
	_check(int(terrain_summary.apron_count) == 40, "transições ao redor dos objetos incompletas")
	_check(int(terrain_summary.dense_bridge_count) == 2, "massa de terreno da região densa ficou desconectada")
	_check(world.obstacles.get_child_count() == 91, "as 36 âncoras e 55 massas florestais não foram preservadas")
	_check(world.landmarks.get_child_count() == 4, "quantidade funcional de landmarks mudou")

	var composer = world.environment_builder.terrain_composer
	print("FOREST ART LAYOUT: " + str(composer.art_layout()))
	_check(int(terrain_summary.grove_count) == 26, "composição não integrou as 26 árvores físicas")
	_check(int(terrain_summary.dense_grove_count) == 3, "Bosque não preservou três âncoras realmente densas")
	_check(int(terrain_summary.settlement_anchor_count) == 40, "árvores, pedras e landmarks perderam assentamentos próprios")
	_check(int(terrain_summary.semantic_region_count) == 5, "mapa visual não cobre as cinco regiões semânticas")
	var flower_count := 0
	var low_vegetation_count := 0
	for visual in world.environment_builder.visual_batcher.visual_instances:
		var file_name := str(visual.source_path).get_file()
		if file_name.begins_with("Flowers_"):
			flower_count += 1
		elif file_name.begins_with("Grass_transition_"):
			low_vegetation_count += 1
	_check(flower_count >= 60, "câmera real não recebeu os agrupamentos raros de flores")
	_check(low_vegetation_count >= 120, "câmera real não recebeu vegetação baixa integrada")
	_focus(world, composer.capture_point("OPEN_ARENA"))
	await _capture(world, "open_arena")
	_focus(world, composer.capture_point("NATURAL_CORRIDOR"))
	await _capture(world, "natural_corridor")
	_focus(world, composer.capture_point("DENSE_REGION"))
	await _capture(world, "dense_region")
	_focus(world, composer.capture_point("LANDMARK_REGION"))
	await _capture(world, "landmark_transition")

	# Capturas diagnósticas adicionais verificam os assentamentos que não
	# aparecem necessariamente nas cinco situações principais.
	var settlements: Array = composer.art_layout().settlement_anchors
	for diagnostic_kind in ["tree", "stone", "landmark_obelisk", "landmark_tree"]:
		for settlement in settlements:
			if str(settlement.kind) != diagnostic_kind:
				continue
			var diagnostic_position := Vector2(settlement.position)
			if diagnostic_kind == "tree" or diagnostic_kind == "stone":
				diagnostic_position += Vector2(0.0, 175.0)
			_focus(world, diagnostic_position)
			await _capture(world, diagnostic_kind)
			break

	_focus(world, composer.capture_point("OPEN_ARENA"))
	world.hud.visible = true
	world.hud.stage_banner.hide()
	world.time_survived = world.RUN_DURATION
	_spawn_combat_scene(world)
	for _frame in range(24):
		await process_frame
	await _capture(world, "combat", true)
	var metrics := await _measure_frames(MEASURED_FRAMES)
	var average_ms := float(metrics.average_ms)
	var p95_ms := float(metrics.p95_ms)
	_check(
		average_ms <= MAX_AVERAGE_MS and p95_ms <= MAX_P95_MS,
		"integração excedeu o gate: média %.2f ms, p95 %.2f ms" % [average_ms, p95_ms]
	)
	print(
		"FOREST MAIN PERFORMANCE: mapa real, %d inimigos; terreno %.2f ms para gerar; média %.2f ms, p95 %.2f ms"
		% [COMBAT_ENEMIES, float(terrain_summary.build_time_ms), average_ms, p95_ms]
	)

	world.queue_free()
	for _frame in range(8):
		await process_frame
	world = null
	if failures.is_empty():
		print("FOREST TERRAIN INTEGRATION OK: terreno contínuo validado no world.tscn real")
	quit(0 if failures.is_empty() else 1)
