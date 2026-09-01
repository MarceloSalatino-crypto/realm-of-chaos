extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const VOLLEY_SCRIPT := preload("res://scripts/abyssal_ballista_volley.gd")
const CAPTURE_SIZE := Vector2i(1280, 720)
const ENEMY_COUNT := 56

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("ABYSSAL BALLISTA VISUAL: " + message)


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
	world.camera.global_position = Vector2(150.0, 0.0)
	world.hud.stage_banner.hide()
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame
	for index in range(ENEMY_COUNT):
		var enemy_type := "guardian" if index % 19 == 0 else ("brute" if index % 8 == 0 else "prowler")
		var enemy = world.spawn_enemy(enemy_type, index % 23 == 0, 2.0)
		_check(is_instance_valid(enemy), "inimigo visual %d não nasceu" % index)
		if not is_instance_valid(enemy):
			continue
		var column := float(index / 7)
		var lane := float(index % 7) - 3.0
		enemy.global_position = Vector2(175.0 + column * 76.0, lane * 55.0 + sin(float(index) * 1.7) * 12.0)
		enemy.hp = 1_000_000.0
		enemy.max_hp = enemy.hp
		enemy.velocity = Vector2.ZERO
		enemy.set_process(false)
		enemy.set_physics_process(false)
	world._rebuild_spatial_grid()


func _prepare_weapon(world: Node, evolved: bool) -> void:
	for weapon_id in world.player.WEAPON_IDS:
		world.player.weapon_levels[weapon_id] = 0
		world.player.evolved_weapons[weapon_id] = false
	world.player.weapon_levels.chaos_bolt = 8
	world.player.evolved_weapons.chaos_bolt = evolved
	world.player.equipped_weapon_id = "chaos_bolt"
	world.player.damage_multiplier = 1.0
	world.player.temporary_damage_multiplier = 1.0
	world.player.cooldown_multiplier = 1.0
	world.player.temporary_cooldown_multiplier = 1.0
	world.player.crit_chance = -1.0
	world.player.projectile_bonus = 0


func _find_volley(world: Node) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == VOLLEY_SCRIPT and not effect.is_queued_for_deletion():
			return effect
	return null


func _freeze_projectiles(world: Node) -> void:
	for projectile in world.projectiles.get_children():
		projectile.set_physics_process(false)


func _clear_weapon_visuals(world: Node) -> void:
	for projectile in world.projectiles.get_children():
		projectile.queue_free()
	for effect in world.effects.get_children():
		effect.queue_free()
	await process_frame


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
		print("ABYSSAL BALLISTA SCREENSHOT: " + ProjectSettings.globalize_path(path))


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
	world.player._fire_chaos_bolt()
	_freeze_projectiles(world)
	_check(world.projectiles.get_child_count() == 3, "captura base não contém três virotes")
	await _capture(world, "abyssal_ballista_01_base.png")

	await _clear_weapon_visuals(world)
	_prepare_weapon(world, true)
	world.player._fire_chaos_bolt()
	var volley := _find_volley(world)
	_check(is_instance_valid(volley), "formação evoluída não existe para captura")
	if is_instance_valid(volley):
		volley.set_process(false)
		volley._process(0.05)
		await _capture(world, "abyssal_ballista_02_pre_volley.png")
		volley._process(0.12)
		await _capture(world, "abyssal_ballista_03_formation.png")
		volley._process(0.04)
		_freeze_projectiles(world)
		_check(world.projectiles.get_child_count() == 5, "disparo principal visual não contém cinco virotes")
		for projectile in world.projectiles.get_children():
			projectile.global_position = world.player.global_position + Vector2(projectile.direction) * 68.0
		await _capture(world, "abyssal_ballista_04_main_shot.png")

		var projectile_index := 0
		for projectile in world.projectiles.get_children():
			var travel := 235.0 + float(projectile_index % 3) * 56.0
			projectile.global_position = world.player.global_position + Vector2(projectile.direction) * travel
			projectile_index += 1
		await _capture(world, "abyssal_ballista_05_piercing_horde.png")

		volley._process(0.18)
		projectile_index = 0
		for projectile in world.projectiles.get_children():
			var travel := 470.0 + float(projectile_index % 2) * 68.0
			projectile.global_position = world.player.global_position + Vector2(projectile.direction) * travel
			projectile_index += 1
		await _capture(world, "abyssal_ballista_06_final_state.png")

	current_scene = null
	await _clear_weapon_visuals(world)
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame
	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("ABYSSAL BALLISTA VISUAL OK: base, pré-salva, formação, disparo, perfuração e estado final capturados")
	quit(0 if failures.is_empty() else 1)
