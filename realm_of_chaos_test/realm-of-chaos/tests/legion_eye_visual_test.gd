extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const HOMING_EYE_SCRIPT = preload("res://scripts/homing_eye.gd")
const LEGION_FOCUS_SCRIPT = preload("res://scripts/legion_focus.gd")
const CAPTURE_SIZE := Vector2i(1280, 720)
const ENEMY_COUNT := 56

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("LEGION EYE VISUAL: " + message)


func _prepare_world(world) -> void:
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.spawn_timer = 9999.0
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO
	world.camera.position_smoothing_enabled = false
	world.camera.global_position = Vector2(80.0, 0.0)
	world.hud.stage_banner.hide()
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame
	for index in range(ENEMY_COUNT - 2):
		var enemy_type := "guardian" if index % 17 == 0 else ("brute" if index % 7 == 0 else "prowler")
		var enemy = world.spawn_enemy(enemy_type, index % 19 == 0, 2.0)
		var ring: float = [140.0, 245.0, 365.0, 495.0][index % 4]
		var angle := TAU * float(index * 13 % ENEMY_COUNT) / float(ENEMY_COUNT)
		enemy.global_position = Vector2.RIGHT.rotated(angle) * ring
		_freeze_enemy(enemy)
	var elite = world.spawn_enemy("guardian", true, 2.0)
	elite.global_position = Vector2(185.0, 120.0)
	_freeze_enemy(elite)
	var boss = world.spawn_enemy("ossuary_colossus", false, 2.0)
	boss.global_position = Vector2(280.0, -25.0)
	_freeze_enemy(boss)
	world._rebuild_spatial_grid()


func _freeze_enemy(enemy: Node) -> void:
	enemy.hp = 1_000_000.0
	enemy.max_hp = enemy.hp
	enemy.velocity = Vector2.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)


func _prepare_swarm(world, evolved: bool) -> void:
	for weapon_id in world.player.WEAPON_IDS:
		world.player.weapon_levels[weapon_id] = 0
		world.player.evolved_weapons[weapon_id] = false
	world.player.weapon_levels.swarm_idol = 6
	world.player.evolved_weapons.swarm_idol = evolved
	world.player.damage_multiplier = 1.0
	world.player.temporary_damage_multiplier = 1.0
	world.player.cooldown_multiplier = 1.0
	world.player.temporary_cooldown_multiplier = 1.0
	world.player.crit_chance = -1.0
	world.player.swarm_timer = 0.0
	world.player.combat.legion_cast_count = 0


func _freeze_homing_eyes(world) -> int:
	var count := 0
	for projectile in world.projectiles.get_children():
		if projectile.get_script() == HOMING_EYE_SCRIPT:
			projectile.set_physics_process(false)
			count += 1
	return count


func _find_focus(world) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == LEGION_FOCUS_SCRIPT and not effect.is_queued_for_deletion():
			return effect
	return null


func _clear_weapon_visuals(world) -> void:
	for projectile in world.projectiles.get_children():
		projectile.queue_free()
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
		print("LEGION EYE SCREENSHOT: " + ProjectSettings.globalize_path(path))


func _run() -> void:
	root.content_scale_size = CAPTURE_SIZE
	var campaign_manager = root.get_node_or_null("CampaignManager")
	if is_instance_valid(campaign_manager):
		campaign_manager.select_map_in_memory("profaned_forest", true)
	var world = WORLD_SCENE.instantiate()
	world.campaign_map_override_id = "profaned_forest"
	root.add_child(world)
	current_scene = world
	await process_frame
	await _prepare_world(world)

	_prepare_swarm(world, false)
	world.player._release_swarm_eyes(6)
	_check(_freeze_homing_eyes(world) == 5, "captura base não contém cinco olhos")
	await _capture(world, "legion_eye_01_swarm_idol_base.png")

	await _clear_weapon_visuals(world)
	_prepare_swarm(world, true)
	world.player._release_swarm_eyes(6)
	_check(_freeze_homing_eyes(world) == 8, "estado normal evoluído não contém oito olhos")
	await _capture(world, "legion_eye_02_evolved_normal.png")

	await _clear_weapon_visuals(world)
	_prepare_swarm(world, true)
	world.player.combat.legion_cast_count = 2
	world.player._release_swarm_eyes(6)
	var focus = _find_focus(world)
	_check(is_instance_valid(focus), "foco coordenado não existe para captura")
	if is_instance_valid(focus):
		focus.set_process(false)
		focus._process(0.11)
		await _capture(world, "legion_eye_03_priority_mark.png")
		focus._process(0.16)
		await _capture(world, "legion_eye_04_convergence.png")
		focus._process(0.07)
		await _capture(world, "legion_eye_05_coordinated_strike.png")
		focus._process(0.34)
		await _capture(world, "legion_eye_06_redistribution.png")

	await _clear_weapon_visuals(world)
	for index in range(world.MAX_EFFECTS):
		var angle := TAU * float(index) / float(world.MAX_EFFECTS)
		var radius := 120.0 + float(index % 7) * 52.0
		world.spawn_effect(
			Vector2.RIGHT.rotated(angle) * radius,
			Color("8f4fc4").lerp(Color("cf405f"), float(index % 5) / 4.0),
			24.0 + float(index % 3) * 5.0, 3.0, index % 4 == 0
		)
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "cenário gráfico não preencheu 120 efeitos")
	_prepare_swarm(world, true)
	world.player.combat.legion_cast_count = 2
	world.player._release_swarm_eyes(6)
	var saturated_focus = _find_focus(world)
	_check(is_instance_valid(saturated_focus), "foco crítico sumiu no cenário gráfico saturado")
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "foco gráfico ultrapassou o teto de efeitos")
	if is_instance_valid(saturated_focus):
		saturated_focus.set_process(false)
		saturated_focus._process(0.34)
		await _capture(world, "legion_eye_07_saturated_focus.png")

	current_scene = null
	await _clear_weapon_visuals(world)
	for enemy in world.enemies.get_children():
		enemy.queue_free()
	await process_frame
	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("LEGION EYE VISUAL OK: base, estado normal, marca, convergência, ataque, redistribuição e saturação capturados no world.tscn real")
	quit(0 if failures.is_empty() else 1)
