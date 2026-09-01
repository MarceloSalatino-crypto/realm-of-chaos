extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const RELEASE_SCRIPT := preload("res://scripts/spirit_devourer_release.gd")
const CAPTURE_SIZE := Vector2i(1280, 720)

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("SOUL DEVOURER VISUAL: " + message)


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
	world.camera.global_position = Vector2(60.0, 0.0)
	world.hud.stage_banner.hide()
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame


func _prepare_weapon(world: Node, evolved: bool) -> void:
	for weapon_id in world.player.WEAPON_IDS:
		world.player.weapon_levels[weapon_id] = 0
		world.player.evolved_weapons[weapon_id] = false
	world.player.weapon_levels.soul_orbit = 6
	world.player.evolved_weapons.soul_orbit = evolved
	world.player.equipped_weapon_id = "soul_orbit"
	world.player.orbit_angle = 0.24
	world.player.orbit_hit_times.clear()
	world.player.combat.reset_soul_devourer_state()
	world.player.queue_redraw()


func _spawn_horde(world: Node, count: int) -> Array[Node]:
	var targets: Array[Node] = []
	for index in range(count):
		var kind := "guardian" if index % 17 == 0 else ("brute" if index % 7 == 0 else "prowler")
		var enemy = world.spawn_enemy(kind, index % 23 == 0, 2.0)
		_check(is_instance_valid(enemy), "inimigo visual %d não nasceu" % index)
		if not is_instance_valid(enemy):
			continue
		var ring := float(index / 12)
		var angle := TAU * float(index % 12) / 12.0 + ring * 0.23
		var radius := 150.0 + ring * 52.0
		enemy.global_position = world.player.global_position + Vector2.RIGHT.rotated(angle) * radius
		enemy.hp = 1_000_000.0
		enemy.max_hp = enemy.hp
		enemy.velocity = Vector2.ZERO
		enemy.set_process(false)
		enemy.set_physics_process(false)
		targets.append(enemy)
	world._rebuild_spatial_grid()
	return targets


func _clear_enemies(world: Node) -> void:
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame


func _find_release(world: Node) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == RELEASE_SCRIPT and not effect.is_queued_for_deletion():
			return effect
	return null


func _capture(world: Node, file_name: String) -> void:
	world.player.queue_redraw()
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
		print("SOUL DEVOURER SCREENSHOT: " + ProjectSettings.globalize_path(path))


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
	_spawn_horde(world, 24)
	await _capture(world, "soul_devourer_01_base.png")

	_prepare_weapon(world, true)
	await _capture(world, "soul_devourer_02_evolved_orbit.png")

	world.player.combat.soul_essence_charges = 4
	world.player.combat.soul_essence_damage = 48.1
	await _capture(world, "soul_devourer_03_accumulation.png")

	world.player.combat.soul_essence_charges = 6
	world.player.combat.soul_essence_damage = 72.15
	_check(world.player.combat.release_soul_essence(170.0), "liberação visual não foi criada")
	var release := _find_release(world)
	_check(is_instance_valid(release), "efeito de liberação não foi encontrado")
	if is_instance_valid(release):
		release.set_process(false)
		release._process(0.14)
	await _capture(world, "soul_devourer_04_release.png")

	await _clear_enemies(world)
	_spawn_horde(world, 90)
	world.player.combat.soul_devourer_release_cooldown = 0.0
	world.player.combat.soul_essence_charges = 6
	world.player.combat.soul_essence_damage = 72.15
	_check(world.player.combat.release_soul_essence(170.0), "liberação na horda não foi criada")
	var horde_release := _find_release(world)
	if is_instance_valid(horde_release):
		horde_release.set_process(false)
		horde_release._process(0.19)
	await _capture(world, "soul_devourer_05_horde.png")

	if is_instance_valid(horde_release):
		horde_release._process(0.19)
	world.player.combat.soul_devourer_release_visual_time = 0.08
	await _capture(world, "soul_devourer_06_final_state.png")

	current_scene = null
	for effect in world.effects.get_children():
		effect.queue_free()
	await _clear_enemies(world)
	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SOUL DEVOURER VISUAL OK: base, evolução, acúmulo, liberação, horda e estado final capturados")
	quit(0 if failures.is_empty() else 1)
