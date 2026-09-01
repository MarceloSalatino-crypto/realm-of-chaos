extends SceneTree

const LAB_SCENE := preload("res://scenes/biome_vertical_slice_lab.tscn")
const BossArenaScript := preload("res://scripts/boss_arena.gd")
const WORLD_LIMIT := 5550.0
const WORLD_MARGIN := 8.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("BOSS ARENA SAFETY: " + message)


func _arena_inside_world(center: Vector2, radius: float) -> bool:
	return (
		absf(center.x) + radius + WORLD_MARGIN <= WORLD_LIMIT
		and absf(center.y) + radius + WORLD_MARGIN <= WORLD_LIMIT
	)


func _arena_intersects_hazard(world: Node, center: Vector2, radius: float) -> bool:
	var usable_radius := radius - 34.0
	for hazard in world.get_tree().get_nodes_in_group("arena_hazards"):
		if not is_instance_valid(hazard) or not world.is_ancestor_of(hazard):
			continue
		if hazard.global_position.distance_to(center) <= usable_radius + float(hazard.radius):
			return true
	return false


func _check_placement(
	world: Node, placement: Dictionary, radius: float,
	boss_radius: float, context: String
) -> void:
	_check(not placement.is_empty(), context + " não encontrou arena")
	if placement.is_empty():
		return
	var center := Vector2(placement.center)
	var boss_position := Vector2(placement.boss_position)
	_check(_arena_inside_world(center, radius), context + " ficou fora do mundo")
	_check(
		world.environment_builder.is_boss_arena_center_valid(center, radius),
		context + " retornou centro reprovado pelo próprio validador"
	)
	_check(
		world.environment_builder.is_boss_spawn_position_valid(
			boss_position, center, radius, boss_radius
		),
		context + " retornou boss sobre sólido, hazard ou limite"
	)
	_check(not _arena_intersects_hazard(world, center, radius), context + " contém hazard")


func _clear_active_boss(world: Node) -> void:
	if is_instance_valid(world.active_boss_arena):
		world.active_boss_arena.free()
	world.active_boss_arena = null
	if is_instance_valid(world.active_boss):
		world.active_boss.free()
	world.active_boss = null


func _run() -> void:
	var lab = LAB_SCENE.instantiate()
	root.add_child(lab)
	await process_frame
	await lab.load_slice("forest_production")
	var world = lab.current_world
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true
	world.player.set_physics_process(false)
	await physics_frame

	var builder = world.environment_builder
	var composer = builder.terrain_composer
	var normal_radius := BossArenaScript.radius_for(false)
	var final_radius := BossArenaScript.radius_for(true)
	var normal_boss_radius := float(GameDefs.enemy_data("ossuary_colossus").radius)
	var final_boss_radius := float(GameDefs.enemy_data("chaos_sovereign").radius)

	# OPEN_ARENA: o ponto artístico aprovado deve continuar sendo um fallback real.
	var open_arena := Vector2(composer.capture_point("OPEN_ARENA"))
	_check(builder.is_boss_arena_center_valid(open_arena, normal_radius, open_arena), "OPEN_ARENA normal deixou de ser válida")
	_check(builder.is_boss_arena_center_valid(open_arena, final_radius, open_arena), "OPEN_ARENA final deixou de ser válida")
	_check_placement(
		world, builder.find_safe_boss_arena_placement(open_arena, normal_radius, normal_boss_radius),
		normal_radius, normal_boss_radius, "OPEN_ARENA"
	)

	# Região densa: o centro comprometido deve ser recusado e substituído.
	var dense_center := Vector2(composer.capture_point("DENSE_REGION"))
	_check(not builder.is_boss_arena_center_valid(dense_center, normal_radius, dense_center), "DENSE_REGION ainda aceita o centro comprometido")
	var dense_placement: Dictionary = builder.find_safe_boss_arena_placement(
		dense_center, normal_radius, normal_boss_radius
	)
	_check_placement(world, dense_placement, normal_radius, normal_boss_radius, "DENSE_REGION")
	if not dense_placement.is_empty():
		_check(Vector2(dense_placement.center).distance_to(dense_center) > 1.0, "DENSE_REGION não deslocou a arena")

	# Os quatro landmarks precisam provocar busca de outro centro.
	for landmark in world.landmarks.get_children():
		var approach: Vector2 = Vector2(landmark.global_position) + Vector2(0.0, 92.0)
		var context := "LANDMARK_%s" % str(landmark.landmark_kind).to_upper()
		_check(not builder.is_boss_arena_center_valid(approach, normal_radius, approach), context + " ainda aceita arena sobre a estrutura")
		var placement: Dictionary = builder.find_safe_boss_arena_placement(
			approach, normal_radius, normal_boss_radius
		)
		_check_placement(world, placement, normal_radius, normal_boss_radius, context)

	_check(world.hazards.get_child_count() == 0, "Boss Arena do Bosque ainda encontrou Raízes Profanadas")

	# Quatro lados e quatro cantos, para arenas normal e final.
	var edge_origins: Array[Vector2] = [
		Vector2(5500.0, 0.0), Vector2(-5500.0, 0.0),
		Vector2(0.0, 5500.0), Vector2(0.0, -5500.0),
		Vector2(5500.0, 5500.0), Vector2(-5500.0, 5500.0),
		Vector2(5500.0, -5500.0), Vector2(-5500.0, -5500.0),
	]
	for edge_index in range(edge_origins.size()):
		for final_boss in [false, true]:
			var radius := final_radius if final_boss else normal_radius
			var boss_radius := final_boss_radius if final_boss else normal_boss_radius
			var placement: Dictionary = builder.find_safe_boss_arena_placement(
				edge_origins[edge_index], radius, boss_radius
			)
			_check_placement(
				world, placement, radius, boss_radius,
				"EDGE_%d_%s" % [edge_index, "FINAL" if final_boss else "NORMAL"]
			)

	# Múltiplos ângulos próximos da massa densa nunca podem aceitar sobreposição.
	if not dense_placement.is_empty():
		var safe_dense_center := Vector2(dense_placement.center)
		for attempt in range(256):
			seed(880000 + attempt)
			var boss_position: Vector2 = builder.find_safe_boss_spawn_position(
				safe_dense_center, normal_radius, normal_boss_radius
			)
			_check(
				builder.is_boss_spawn_position_valid(
					boss_position, safe_dense_center, normal_radius, normal_boss_radius
				),
				"tentativa %d aceitou boss sobre sólido" % attempt
			)

	# A correção de borda usa a geometria real, mesmo num centro antigo problemático.
	var old_problem_center := Vector2(2278.4, 2180.2)
	var boundary_arena = BossArenaScript.new()
	boundary_arena.configure(
		world, null, old_problem_center, "ossuary_colossus", true, true
	)
	world.add_child(boundary_arena)
	for angle_index in range(128):
		var direction := Vector2.RIGHT.rotated(TAU * float(angle_index) / 128.0)
		world.player.global_position = old_problem_center + direction * (final_radius + 80.0)
		world.player.velocity = direction * 120.0
		boundary_arena._process(0.0)
		_check(
			world.player.global_position.distance_to(old_problem_center) <= final_radius - 34.0 + 0.1,
			"borda não confinou o jogador no ângulo %d" % angle_index
		)
		_check(
			builder._player_shape_fits_at(world.player.global_position),
			"borda colocou o jogador dentro de sólido no ângulo %d" % angle_index
		)
		_check(
			not builder._position_intersects_hazard(world.player.global_position, 0.0),
			"borda colocou o jogador dentro de hazard no ângulo %d" % angle_index
		)
	boundary_arena.free()

	# Fallback forçado e todos os pontos deliberados precisam ser válidos.
	var forced_fallback: Dictionary = builder.find_safe_boss_arena_placement(
		Vector2.INF, final_radius, final_boss_radius
	)
	_check_placement(world, forced_fallback, final_radius, final_boss_radius, "FORCED_FALLBACK")
	_check(bool(forced_fallback.get("used_fallback", false)), "falha dinâmica não marcou o uso de fallback")
	for fallback_index in range(builder.forest_boss_arena_fallback_centers().size()):
		var fallback: Vector2 = builder.forest_boss_arena_fallback_centers()[fallback_index]
		_check(
			builder.is_boss_arena_center_valid(fallback, final_radius),
			"fallback deliberado %d não é válido para o boss final" % fallback_index
		)

	# Integração real: spawn seguro e confinamento do boss.
	world.player.global_position = Vector2(5500.0, 0.0)
	var boss = world._spawn_scheduled_boss(GameDefs.boss_schedule()[0], 0)
	_check(is_instance_valid(boss), "fluxo real não criou boss perto do limite")
	if is_instance_valid(boss):
		boss.set_physics_process(false)
		var arena = world.active_boss_arena
		_check(is_instance_valid(arena) and arena.safe_environment_confinement, "arena real não ativou confinamento seguro")
		_check(_arena_inside_world(arena.global_position, arena.radius), "arena real ficou cortada pelo mundo")
		_check(
			builder.is_boss_spawn_position_valid(
				boss.global_position, arena.global_position, arena.radius, float(boss.hit_radius)
			),
			"boss real nasceu em posição inválida"
		)
		var escape_direction := Vector2(1.0, 0.35).normalized()
		boss.global_position = arena.global_position + escape_direction * (arena.radius + 120.0)
		boss.velocity = escape_direction * 180.0
		arena._process(0.0)
		_check(
			boss.global_position.distance_to(arena.global_position) <= (
				arena.radius - maxf(float(boss.hit_radius), 34.0) - 12.0 + 0.1
			),
			"boss continuou fora da arena"
		)
		_check(builder._body_shape_fits_at(boss, boss.global_position), "confinamento colocou boss dentro de sólido")
	_clear_active_boss(world)

	lab.queue_free()
	for _frame in range(4):
		await process_frame
	if failures.is_empty():
		print("BOSS ARENA SAFETY OK: busca dinâmica, landmarks, hazards, limites, boss, borda e fallback validados")
	quit(0 if failures.is_empty() else 1)
