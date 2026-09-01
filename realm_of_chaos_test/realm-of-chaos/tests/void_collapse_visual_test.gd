extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const CAPTURE_SIZE := Vector2i(1280, 720)
const ENEMY_COUNT := 60

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("VOID COLLAPSE VISUAL: " + message)


func _prepare_world(world) -> void:
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.spawn_timer = 9999.0
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO
	world.camera.position_smoothing_enabled = false
	world.camera.global_position = Vector2.ZERO
	world.hud.stage_banner.hide()
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame
	for index in range(ENEMY_COUNT):
		var enemy = world.spawn_enemy("prowler" if index % 3 else "brute", false, 2.0)
		var ring: float = [100.0, 210.0, 330.0, 425.0, 515.0][index % 5]
		enemy.global_position = Vector2.RIGHT.rotated(TAU * float(index) / float(ENEMY_COUNT)) * ring
		enemy.hp = 100_000.0
		enemy.max_hp = enemy.hp
		enemy.velocity = Vector2.ZERO
		enemy.set_process(false)
		enemy.set_physics_process(false)
	world._rebuild_spatial_grid()


func _prepare_nova(world, evolved: bool) -> void:
	for weapon_id in world.player.WEAPON_IDS:
		world.player.weapon_levels[weapon_id] = 0
		world.player.evolved_weapons[weapon_id] = false
	world.player.weapon_levels.chaos_nova = 6
	world.player.evolved_weapons.chaos_nova = evolved
	world.player.crit_chance = -1.0
	world.player.last_direction = Vector2.RIGHT
	world.player.nova_timer = 0.0


func _clear_effects(world) -> void:
	for effect in world.effects.get_children():
		effect.queue_free()
	await process_frame


func _capture(world, file_name: String) -> void:
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
		print("VOID COLLAPSE SCREENSHOT: " + ProjectSettings.globalize_path(path))


func _run() -> void:
	root.content_scale_size = CAPTURE_SIZE
	var campaign_manager = root.get_node_or_null("CampaignManager")
	if is_instance_valid(campaign_manager):
		campaign_manager.select_map_in_memory("profaned_forest", true)
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await _prepare_world(world)

	_prepare_nova(world, false)
	world.player._cast_nova(6)
	await _capture(world, "void_collapse_base_nova.png")

	await _clear_effects(world)
	_prepare_nova(world, true)
	world.player._cast_nova(6)
	var collapse = world.effects.get_node_or_null("VoidCollapse")
	_check(is_instance_valid(collapse), "Colapso não existe para captura")
	if is_instance_valid(collapse):
		collapse.set_process(false)
		collapse._process(0.10)
		await _capture(world, "void_collapse_formation.png")
		collapse._process(0.28)
		await _capture(world, "void_collapse_attraction.png")
		collapse._process(0.31)
		await _capture(world, "void_collapse_implosion.png")

	current_scene = null
	await _clear_effects(world)
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame
	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("VOID COLLAPSE VISUAL OK: base, formação, atração e implosão capturadas no world.tscn real")
	quit(0 if failures.is_empty() else 1)
