extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const ABYSSAL_BALLISTA_SCRIPT = preload("res://scripts/abyssal_ballista_volley.gd")
const SHADOW_DANCE_SCRIPT = preload("res://scripts/shadow_dance_sequence.gd")
const ETERNAL_STORM_SCRIPT = preload("res://scripts/eternal_storm.gd")
const LEGION_FOCUS_SCRIPT = preload("res://scripts/legion_focus.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(30.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("EVOLUTION WEAKREF LIFECYCLE: teste excedeu 30 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("EVOLUTION WEAKREF LIFECYCLE: " + message)


func _new_world() -> Node:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO
	return world


func _spawn_target(world: Node, position: Vector2) -> Node:
	var enemy = world.spawn_enemy("prowler", false, 1.0)
	_check(is_instance_valid(enemy), "não foi possível criar alvo")
	if not is_instance_valid(enemy):
		return null
	enemy.global_position = position
	enemy.hp = 10_000.0
	enemy.max_hp = enemy.hp
	enemy.velocity = Vector2.ZERO
	enemy.knockback_velocity = Vector2.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _effect_by_script(world: Node, script: Script) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == script and not effect.is_queued_for_deletion():
			return effect
	return null


func _prepare_single_weapon(player: Node, weapon_id: String) -> void:
	for id in player.WEAPON_IDS:
		player.weapon_levels[id] = 0
		player.evolved_weapons[id] = false
	player.weapon_levels[weapon_id] = 6
	player.evolved_weapons[weapon_id] = true
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.projectile_bonus = 0


func _test_ballista_owner_freed() -> void:
	var world = await _new_world()
	_prepare_single_weapon(world.player, "chaos_bolt")
	_spawn_target(world, Vector2(600.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._fire_chaos_bolt()
	var volley := _effect_by_script(world, ABYSSAL_BALLISTA_SCRIPT)
	_check(is_instance_valid(volley), "Balista não iniciou")
	if is_instance_valid(volley):
		volley.set_process(false)
	world.player.queue_free()
	await process_frame
	if is_instance_valid(volley):
		volley._process(0.21)
	await process_frame
	_check(not is_instance_valid(volley), "Balista sobreviveu ao Player inválido")
	_check(world.projectiles.get_child_count() == 0, "Balista liberou projéteis depois que o Player foi removido")
	_check(world.player_projectile_batch_renderer._entries.is_empty(), "Balista deixou IDs no batch")
	world.queue_free()
	await process_frame


func _test_shadow_owner_freed() -> void:
	var world = await _new_world()
	_prepare_single_weapon(world.player, "shadow_blades")
	_spawn_target(world, Vector2(300.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._fire_shadow_blades(6)
	var sequence := _effect_by_script(world, SHADOW_DANCE_SCRIPT)
	_check(is_instance_valid(sequence), "Dança não iniciou")
	if not is_instance_valid(sequence):
		world.queue_free()
		await process_frame
		return
	sequence.set_process(false)
	var released_before := int(sequence.visual_signature().released_projectile_count)
	for projectile in world.projectiles.get_children():
		projectile.set_physics_process(false)
	world.player.queue_free()
	await process_frame
	sequence._process(0.31)
	var signature: Dictionary = sequence.visual_signature()
	_check(int(signature.released_projectile_count) == released_before, "Dança liberou novas ondas com Player inválido")
	_check(int(signature.cancelled_wave_count) == 3, "Dança não cancelou com segurança as três ondas pendentes")
	for projectile in world.projectiles.get_children():
		projectile.queue_free()
	await process_frame
	_check(world.player_projectile_batch_renderer._entries.is_empty(), "Dança deixou IDs órfãos no batch")
	world.queue_free()
	await process_frame


func _test_storm_target_freed() -> void:
	var world = await _new_world()
	var target := _spawn_target(world, Vector2(180.0, 0.0))
	var untouched := _spawn_target(world, Vector2(-240.0, 0.0))
	var untouched_hp := float(untouched.hp)
	var target_entries: Array[Dictionary] = [{
		"target": target,
		"critical": false,
		"total_damage": 100.0,
	}]
	var storm = world.spawn_eternal_storm(Vector2.ZERO, target_entries)
	_check(is_instance_valid(storm), "Tempestade não iniciou")
	if is_instance_valid(storm):
		storm.set_process(false)
	target.queue_free()
	await process_frame
	if is_instance_valid(storm):
		storm._process(0.17)
		_check(int(storm.visual_signature().echo_stage_count) == 1, "Tempestade não concluiu o callback com alvo inválido")
		storm._process(0.50)
	await process_frame
	_check(not is_instance_valid(storm), "Tempestade não foi removida com segurança")
	_check(float(untouched.hp) == untouched_hp, "Tempestade redirecionou dano inesperado para outro alvo")
	world.queue_free()
	await process_frame


func _test_legion_owner_and_target_freed() -> void:
	var world = await _new_world()
	var target := _spawn_target(world, Vector2(210.0, 0.0))
	var entries: Array[Dictionary] = []
	for _index in range(8):
		entries.append({"damage": 40.0, "critical": false})
	var focus = world.spawn_legion_focus(world.player, target, entries)
	_check(is_instance_valid(focus), "Legião não iniciou")
	if is_instance_valid(focus):
		focus.set_process(false)
	world.player.queue_free()
	target.queue_free()
	await process_frame
	if is_instance_valid(focus):
		focus._process(0.51)
		var signature: Dictionary = focus.visual_signature()
		_check(int(signature.hit_count) == 0, "Legião causou dano com Player/alvo inválidos")
		_check(int(signature.cancelled_wave_count) == 2, "Legião não cancelou as duas ondas com segurança")
		focus._process(0.30)
	await process_frame
	_check(not is_instance_valid(focus), "Legião não foi removida com segurança")
	_check(world.player_projectile_batch_renderer._entries.is_empty(), "Legião deixou IDs no batch")
	world.queue_free()
	await process_frame


func _run() -> void:
	await _test_ballista_owner_freed()
	await _test_shadow_owner_freed()
	await _test_storm_target_freed()
	await _test_legion_owner_and_target_freed()
	if failures.is_empty():
		print("EVOLUTION WEAKREF LIFECYCLE OK: Balista, Dança, Tempestade e Legião liberaram Player/alvo/World sem callback inválido")
		quit(0)
	else:
		quit(1)
