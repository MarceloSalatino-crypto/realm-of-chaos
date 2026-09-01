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
	push_error("CATACLYSM HAMMER VISUAL: " + message)


func _prepare_world(world) -> void:
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.spawn_timer = 9999.0
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO
	world.camera.position_smoothing_enabled = false
	world.camera.global_position = Vector2(115.0, 0.0)
	world.hud.stage_banner.hide()
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame
	for index in range(ENEMY_COUNT):
		var enemy_type := "brute" if index % 5 == 0 else ("guardian" if index % 11 == 0 else "prowler")
		var enemy = world.spawn_enemy(enemy_type, index % 17 == 0, 2.0)
		var ring: float = [105.0, 205.0, 310.0, 420.0, 520.0][index % 5]
		var angle := TAU * float(index) / float(ENEMY_COUNT)
		enemy.global_position = Vector2(215.0, 0.0) + Vector2.RIGHT.rotated(angle) * ring
		enemy.hp = 100_000.0
		enemy.max_hp = enemy.hp
		enemy.velocity = Vector2.ZERO
		enemy.set_process(false)
		enemy.set_physics_process(false)
	world._rebuild_spatial_grid()


func _prepare_hammer(world, evolved: bool) -> void:
	for weapon_id in world.player.WEAPON_IDS:
		world.player.weapon_levels[weapon_id] = 0
		world.player.evolved_weapons[weapon_id] = false
	world.player.weapon_levels.rune_hammer = 6
	world.player.evolved_weapons.rune_hammer = evolved
	world.player.crit_chance = -1.0
	world.player.last_direction = Vector2.RIGHT
	world.player.hammer_timer = 0.0


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
		print("CATACLYSM HAMMER SCREENSHOT: " + ProjectSettings.globalize_path(path))


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

	_prepare_hammer(world, false)
	world.player._slam_rune_hammer(6)
	await _capture(world, "cataclysm_hammer_base.png")

	await _clear_effects(world)
	_prepare_hammer(world, true)
	world.player._slam_rune_hammer(6)
	var rupture = world.effects.get_node_or_null("CataclysmRupture")
	_check(is_instance_valid(rupture), "ruptura não existe para captura")
	if is_instance_valid(rupture):
		rupture.set_process(false)
		await _capture(world, "cataclysm_hammer_evolved_start.png")
		rupture._process(0.085)
		await _capture(world, "cataclysm_hammer_impact.png")
		rupture._process(0.125)
		await _capture(world, "cataclysm_hammer_rupture.png")
		rupture._process(0.10)
		await _capture(world, "cataclysm_hammer_horde.png")

	current_scene = null
	await _clear_effects(world)
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame
	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("CATACLYSM HAMMER VISUAL OK: base, início, impacto, ruptura e horda capturados no world.tscn real")
	quit(0 if failures.is_empty() else 1)
