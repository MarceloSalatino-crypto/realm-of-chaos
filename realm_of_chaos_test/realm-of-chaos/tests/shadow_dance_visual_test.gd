extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const SEQUENCE_SCRIPT := preload("res://scripts/shadow_dance_sequence.gd")
const CAPTURE_SIZE := Vector2i(1280, 720)

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("SHADOW DANCE VISUAL: " + message)


func _prepare_world(world: Node) -> void:
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.spawn_timer = 9999.0
	world.time_survived = world.run_duration
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO
	world.camera.position_smoothing_enabled = false
	world.camera.global_position = Vector2(70.0, 0.0)
	world.hud.stage_banner.hide()
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame

	for index in range(48):
		var enemy_type := "assassin" if index % 11 == 0 else ("brute" if index % 7 == 0 else "prowler")
		var enemy = world.spawn_enemy(enemy_type, false, 2.0)
		_check(is_instance_valid(enemy), "inimigo visual %d não nasceu" % index)
		if not is_instance_valid(enemy):
			continue
		var angle := TAU * float(index) / 48.0 + sin(float(index) * 1.3) * 0.09
		var radius := 165.0 + float(index % 6) * 54.0
		enemy.global_position = Vector2.RIGHT.rotated(angle) * radius
		enemy.hp = 1_000_000.0
		enemy.max_hp = enemy.hp
		enemy.velocity = Vector2.ZERO
		enemy.set_process(false)
		enemy.set_physics_process(false)

	var elite = world.spawn_enemy("guardian", true, 2.4)
	_check(is_instance_valid(elite), "elite visual não nasceu")
	if is_instance_valid(elite):
		elite.global_position = Vector2(285.0, -145.0)
		elite.hp = 1_000_000.0
		elite.max_hp = elite.hp
		elite.set_process(false)
		elite.set_physics_process(false)

	var boss = world.spawn_enemy("ossuary_colossus", false, 1.4)
	_check(is_instance_valid(boss), "boss visual não nasceu")
	if is_instance_valid(boss):
		boss.global_position = Vector2(385.0, 92.0)
		boss.hp = 1_000_000.0
		boss.max_hp = boss.hp
		boss.set_process(false)
		boss.set_physics_process(false)
	world._rebuild_spatial_grid()


func _prepare_weapon(world: Node, evolved: bool) -> void:
	for weapon_id in world.player.WEAPON_IDS:
		world.player.weapon_levels[weapon_id] = 0
		world.player.evolved_weapons[weapon_id] = false
	world.player.weapon_levels.shadow_blades = 6
	world.player.evolved_weapons.shadow_blades = evolved
	world.player.equipped_weapon_id = "shadow_blades"
	world.player.damage_multiplier = 1.0
	world.player.temporary_damage_multiplier = 1.0
	world.player.cooldown_multiplier = 1.0
	world.player.temporary_cooldown_multiplier = 1.0
	world.player.crit_chance = -1.0
	world.player.temporary_crit_bonus = 0.0
	world.player.projectile_bonus = 0


func _find_sequence(world: Node) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == SEQUENCE_SCRIPT and not effect.is_queued_for_deletion():
			return effect
	return null


func _clear_weapon_visuals(world: Node) -> void:
	for projectile in world.projectiles.get_children():
		projectile.queue_free()
	for effect in world.effects.get_children():
		effect.queue_free()
	await process_frame


func _freeze_and_place_projectiles(world: Node, outward_distance: float, return_distance: float) -> void:
	for projectile in world.projectiles.get_children():
		projectile.set_physics_process(false)
		var direction := Vector2(projectile.direction)
		if str(projectile.visual_style) == "shadow_return":
			var angle := wrapf(direction.angle(), 0.0, TAU)
			# A primeira contracadência parte 0,07s antes da segunda; preservar
			# esse desnível evita criar artificialmente uma estrela na captura.
			var staggered_distance := return_distance - 57.0 if angle > PI else return_distance
			projectile.global_position = world.player.global_position - direction * staggered_distance
		else:
			projectile.global_position = world.player.global_position + direction * outward_distance


func _capture(world: Node, file_name: String) -> void:
	RenderingServer.force_draw()
	await process_frame
	var image: Image = world.get_viewport().get_texture().get_image()
	_check(not image.is_empty(), "captura %s ficou vazia" % file_name)
	if image.is_empty():
		return
	var path := "user://%s" % file_name
	var error := image.save_png(path)
	_check(error == OK, "não foi possível salvar %s" % file_name)
	if error == OK:
		print("SHADOW DANCE SCREENSHOT: " + ProjectSettings.globalize_path(path))


func _run() -> void:
	root.content_scale_size = CAPTURE_SIZE
	var campaign_manager = root.get_node_or_null("CampaignManager")
	if is_instance_valid(campaign_manager):
		campaign_manager.select_map_in_memory("profaned_forest", true)
	var world := WORLD_SCENE.instantiate()
	world.campaign_map_override_id = "profaned_forest"
	root.add_child(world)
	current_scene = world
	await process_frame
	await _prepare_world(world)

	_prepare_weapon(world, false)
	world.player._fire_shadow_blades(6)
	_freeze_and_place_projectiles(world, 82.0, 0.0)
	_check(world.projectiles.get_child_count() == 8, "captura base não contém oito lâminas")
	await _capture(world, "shadow_dance_01_base.png")

	await _clear_weapon_visuals(world)
	_prepare_weapon(world, true)
	world.player._fire_shadow_blades(6)
	var sequence := _find_sequence(world)
	_check(is_instance_valid(sequence), "sequência evoluída não existe para captura")
	if is_instance_valid(sequence):
		sequence.set_process(false)
		_freeze_and_place_projectiles(world, 56.0, 0.0)
		await _capture(world, "shadow_dance_02_evolved_opening.png")

		sequence._process(0.12)
		_freeze_and_place_projectiles(world, 132.0, 0.0)
		await _capture(world, "shadow_dance_03_outbound_sequence.png")

		sequence._process(0.09)
		_freeze_and_place_projectiles(world, 205.0, 166.0)
		_check(world.projectiles.get_child_count() == 12, "primeiro retorno visual não contém 12 ataques acumulados")
		await _capture(world, "shadow_dance_04_shadow_return.png")

		sequence._process(0.08)
		_freeze_and_place_projectiles(world, 270.0, 72.0)
		_check(world.projectiles.get_child_count() == 16, "segundo retorno visual não completou 16 ataques")
		await _capture(world, "shadow_dance_05_convergence.png")

		sequence._process(0.23)
		_freeze_and_place_projectiles(world, 335.0, -28.0)
		await _capture(world, "shadow_dance_06_finalization.png")

		world.camera.global_position = Vector2(175.0, 0.0)
		await _capture(world, "shadow_dance_07_horde.png")

		world.camera.global_position = Vector2(250.0, -65.0)
		await _capture(world, "shadow_dance_08_elite.png")

		world.camera.global_position = Vector2(315.0, 45.0)
		await _capture(world, "shadow_dance_09_boss.png")

		sequence._process(0.16)
		await process_frame
		world.camera.global_position = Vector2(70.0, 0.0)
		await _capture(world, "shadow_dance_10_final_state.png")

	current_scene = null
	await _clear_weapon_visuals(world)
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame
	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SHADOW DANCE VISUAL OK: base, saída, retorno, convergência, finalização, horda, elite e boss capturados")
	quit(0 if failures.is_empty() else 1)
