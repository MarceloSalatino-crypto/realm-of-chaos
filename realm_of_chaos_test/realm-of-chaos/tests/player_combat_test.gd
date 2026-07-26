extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const EXPECTED_WEAPON_FINGERPRINT := "chaos_bolt:p2:d0.00:t0.500:r1.0:f1.0|shadow_blades:p6:d0.00:t1.360:r1.0:f1.0|soul_orbit:p0:d17.00:t0.100:r1.0:f0.0|chaos_nova:p0:d52.00:t4.760:r1.0:f1.0|blood_scythe:p0:d40.00:t1.250:r1.0:f0.0|forbidden_grimoire:p0:d50.50:t2.530:r1.0:f0.0|rune_hammer:p0:d65.00:t2.910:r1.0:f0.0|storm_relic:p0:d27.00:t1.420:r1.0:f0.0|swarm_idol:p3:d0.00:t2.220:r1.0:f0.0"

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	push_error("PLAYER COMBAT: teste excedeu 20 segundos")
	quit(2)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PLAYER COMBAT: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.5f, obtido %.5f)" % [message, expected, actual])


func _reset_combat(player) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels["chaos_bolt"] = 1
	player.equipped_weapon_id = "chaos_bolt"
	player.damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.critical_multiplier = 2.0
	player.projectile_bonus = 0
	player.life_steal = 0.0
	player.boss_damage_multiplier = 1.0
	player.dodge_chance = 0.0
	player.armor = 0.0
	player.temporary_armor = 0.0
	player.temporary_damage_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.temporary_crit_bonus = 0.0
	player.max_hp = 125.0
	player.hp = 125.0
	player.disabled = false
	player.death_started = false
	player.invulnerability = 0.0
	player.character_guard_time = 0.0
	player.revive_charges = 0
	player.last_direction = Vector2.RIGHT
	player.attack_direction = Vector2.RIGHT
	player.attack_facing_x = 1.0
	player.attack_facing_time = 0.0
	player.pending_attack_facing_x = 0.0
	player.attack_recoil = 0.0
	player.attack_flash = 0.0
	player.hurt_recoil = 0.0
	player.dash_cooldown = 0.0
	player.dash_duration = 0.0
	player.dash_direction = Vector2.RIGHT
	player.character_id = "eclipse_hunter"
	player.bolt_timer = 0.15
	player.blades_timer = 1.0
	player.nova_timer = 4.0
	player.orbit_tick = 0.0
	player.orbit_angle = 0.0
	player.orbit_hit_times.clear()
	player.scythe_timer = 0.8
	player.grimoire_timer = 1.6
	player.hammer_timer = 1.4
	player.storm_timer = 0.9
	player.swarm_timer = 1.2
	player.sprite.flip_h = false


func _prepare_target(world, player, target, offset: Vector2) -> void:
	target.dead = false
	target.hp = 1000000.0
	target.max_hp = 1000000.0
	target.global_position = player.global_position + offset
	target.knockback_velocity = Vector2.ZERO
	world._rebuild_spatial_grid()


func _weapon_timer(player, weapon_id: String) -> float:
	match weapon_id:
		"chaos_bolt":
			return player.bolt_timer
		"shadow_blades":
			return player.blades_timer
		"soul_orbit":
			return player.orbit_tick
		"chaos_nova":
			return player.nova_timer
		"blood_scythe":
			return player.scythe_timer
		"forbidden_grimoire":
			return player.grimoire_timer
		"rune_hammer":
			return player.hammer_timer
		"storm_relic":
			return player.storm_timer
		"swarm_idol":
			return player.swarm_timer
	return -1.0


func _weapon_fingerprint(world, player, target) -> String:
	var levels := {
		"chaos_bolt": 4, "shadow_blades": 4, "soul_orbit": 3,
		"chaos_nova": 3, "blood_scythe": 3, "forbidden_grimoire": 3,
		"rune_hammer": 3, "storm_relic": 3, "swarm_idol": 3
	}
	var signatures: Array[String] = []
	for weapon_id in player.WEAPON_IDS:
		_reset_combat(player)
		player.weapon_levels[weapon_id] = int(levels[weapon_id])
		player.equipped_weapon_id = weapon_id
		world.damage_by_source.clear()
		var offset := Vector2(96.0, 0.0) if weapon_id == "soul_orbit" else Vector2(100.0, 0.0)
		_prepare_target(world, player, target, offset)
		var projectiles_before: int = world.projectiles.get_child_count()
		match weapon_id:
			"chaos_bolt":
				player._fire_chaos_bolt()
			"shadow_blades":
				player._fire_shadow_blades(4)
			"soul_orbit":
				player._damage_orbit(3)
			"chaos_nova":
				player._cast_nova(3)
			"blood_scythe":
				player._swing_blood_scythe(3)
			"forbidden_grimoire":
				player._cast_forbidden_grimoire(3)
			"rune_hammer":
				player._slam_rune_hammer(3)
			"storm_relic":
				player._cast_storm_chain(3)
			"swarm_idol":
				player._release_swarm_eyes(3)
		var projectile_delta: int = world.projectiles.get_child_count() - projectiles_before
		var damage: float = float(world.damage_by_source.get(weapon_id, 0.0))
		signatures.append("%s:p%d:d%.2f:t%.3f:r%.1f:f%.1f" % [
			weapon_id, projectile_delta, damage, _weapon_timer(player, weapon_id),
			player.attack_recoil, player.attack_flash
		])
	return "|".join(signatures)


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	var player = world.player
	player.set_process(false)
	player.set_physics_process(false)

	for method_name in [
		&"_start_dash", &"_activate_character_skill", &"_set_primary_attack_facing",
		&"_update_weapons", &"_fire_chaos_bolt", &"_fire_shadow_blades",
		&"_spawn_player_projectile", &"_damage_orbit", &"_cast_nova",
		&"_swing_blood_scythe", &"_cast_forbidden_grimoire",
		&"_slam_rune_hammer", &"_cast_storm_chain", &"_release_swarm_eyes",
		&"_notify_weapon_fired", &"_nearest_enemy", &"_enemies_near",
		&"take_damage", &"heal", &"on_damage_dealt", &"_play_death_animation"
	]:
		_check(player.has_method(method_name), "API pública ausente: %s" % method_name)

	_reset_combat(player)
	player.attack_direction = Vector2.LEFT
	player.attack_facing_x = -1.0
	player.attack_facing_time = 0.17
	player.pending_attack_facing_x = 1.0
	player.attack_recoil = 0.6
	player.attack_flash = 0.4
	_check(player.attack_direction == Vector2.LEFT, "attack_direction deixou de ser publicamente gravável")
	_check(player.attack_facing_x == -1.0 and player.attack_facing_time == 0.17, "estado da trava visual deixou de ser público")
	_check(player.pending_attack_facing_x == 1.0, "direção pendente deixou de ser pública")
	_check(player.attack_recoil == 0.6 and player.attack_flash == 0.4, "feedback visual de combate deixou de ser público")

	var target = world.spawn_enemy("prowler", false, 1.0)
	target.set_process(false)
	target.set_physics_process(false)

	var weapon_fingerprint := _weapon_fingerprint(world, player, target)
	print("PLAYER WEAPON FINGERPRINT: " + weapon_fingerprint)
	if not EXPECTED_WEAPON_FINGERPRINT.is_empty():
		_check(weapon_fingerprint == EXPECTED_WEAPON_FINGERPRINT, "fingerprint das nove armas mudou")

	var extra_a = world.spawn_enemy("prowler", false, 1.0)
	var extra_b = world.spawn_enemy("prowler", false, 1.0)
	for enemy in [extra_a, extra_b]:
		enemy.set_process(false)
		enemy.set_physics_process(false)

	_reset_combat(player)
	player._equip_weapon_visual("chaos_bolt")
	player.weapon_levels.chaos_bolt = 4
	_prepare_target(world, player, target, Vector2(-260.0, -35.0))
	var burst_before: int = world.projectiles.get_child_count()
	player._fire_chaos_bolt()
	_check(world.projectiles.get_child_count() == burst_before + 2, "rajada da Besta nível 4 mudou")
	_check(player.attack_facing_x < 0.0 and player.attack_facing_time > 0.20 and player.sprite.flip_h, "orientação central à esquerda não foi travada")
	var first_burst_direction: Vector2 = world.projectiles.get_child(burst_before).direction
	var second_burst_direction: Vector2 = world.projectiles.get_child(burst_before + 1).direction
	_prepare_target(world, player, target, Vector2(260.0, 35.0))
	_check(world.projectiles.get_child(burst_before).direction == first_burst_direction, "mudança de alvo alterou projétil já disparado")
	_check(world.projectiles.get_child(burst_before + 1).direction == second_burst_direction, "rajada não preservou as direções capturadas")
	player._fire_chaos_bolt()
	_check(player.attack_facing_x < 0.0 and player.pending_attack_facing_x > 0.0 and player.sprite.flip_h, "alvo oposto quebrou a trava atual")
	var flip_changes := 0
	var previous_flip: bool = player.sprite.flip_h
	for _frame in range(18):
		player._animate_character(1.0 / 60.0, Vector2.RIGHT, true, 4.0)
		if player.sprite.flip_h != previous_flip:
			flip_changes += 1
			previous_flip = player.sprite.flip_h
	_check(flip_changes == 1 and player.attack_facing_x > 0.0, "troca pendente produziu tremor visual")
	player.last_direction = Vector2.LEFT
	player._animate_character(player.ATTACK_FACING_HOLD + 0.01, Vector2.LEFT, false, 0.0)
	_check(player.sprite.flip_h and player.attack_facing_time <= 0.0, "sprite não voltou à direção de movimento após a pose")

	_reset_combat(player)
	player._equip_weapon_visual("chaos_bolt")
	player.last_direction = Vector2.LEFT
	player._animate_character(0.0, Vector2.LEFT, false, 0.0)
	player._set_primary_attack_facing(Vector2(0.10, -1.0), "chaos_bolt")
	_check(player.sprite.flip_h and player.attack_facing_time <= 0.0, "zona morta vertical mudou")
	player.weapon_levels.shadow_blades = 3
	_prepare_target(world, player, target, Vector2(-220.0, 0.0))
	player._fire_shadow_blades(3)
	_check(player.attack_facing_time <= 0.0, "arma secundária tomou a orientação da arma principal")

	_reset_combat(player)
	for index in range(3):
		var enemy = [target, extra_a, extra_b][index]
		_prepare_target(world, player, enemy, Vector2(75.0 + index * 35.0, index * 18.0))
	world._rebuild_spatial_grid()
	_check(player._nearest_enemy() == target, "consulta do inimigo mais próximo mudou")
	_check(player._enemies_near(180.0).size() == 3, "consulta de inimigos próximos mudou")

	for enemy in [target, extra_a, extra_b]:
		enemy.hp = 1000000.0
	world.damage_by_source.clear()
	player.character_id = "glacial_oracle"
	player._activate_character_skill(world)
	_check_close(float(world.damage_by_source.get("oracle_skill", 0.0)), 54.0, "Pulso Glacial mudou")
	_check(target.slow_time > 2.4 and target.slow_multiplier == 0.45, "lentidão do Oráculo mudou")

	for enemy in [target, extra_a, extra_b]:
		enemy.hp = 1000000.0
	world.damage_by_source.clear()
	player.character_id = "crimson_knight"
	player.hp = 50.0
	player._activate_character_skill(world)
	_check_close(float(world.damage_by_source.get("knight_skill", 0.0)), 78.0, "Contra-ataque Rubro mudou")
	_check_close(player.character_guard_time, 1.8, "duração da guarda mudou")
	_check_close(player.hp, 56.6, "cura do Contra-ataque mudou")

	for enemy in [target, extra_a, extra_b]:
		enemy.hp = 1000000.0
	world.damage_by_source.clear()
	player.character_id = "void_automaton"
	player._activate_character_skill(world)
	_check_close(float(world.damage_by_source.get("automaton_skill", 0.0)), 45.0, "Sobrecarga Arcana mudou")

	player.character_id = "eclipse_hunter"
	var hunter_projectiles_before: int = world.projectiles.get_child_count()
	player._activate_character_skill(world)
	_check(world.projectiles.get_child_count() == hunter_projectiles_before + 5, "Rajada do Eclipse mudou")

	_reset_combat(player)
	player.character_id = "eclipse_hunter"
	player.last_direction = Vector2.LEFT
	var dash_projectiles_before: int = world.projectiles.get_child_count()
	player._start_dash(Vector2.ZERO, world)
	_check(player.dash_direction == Vector2.LEFT, "fallback direcional do dash mudou")
	_check(player.attack_direction.length_squared() > 0.99, "habilidade do dash perdeu a direção de ataque")
	_check_close(player.dash_duration, 0.18, "duração do dash mudou")
	_check_close(player.dash_cooldown, 3.2, "cooldown do dash mudou")
	_check_close(player.invulnerability, 0.34, "invulnerabilidade do dash mudou")
	_check(world.projectiles.get_child_count() == dash_projectiles_before + 5, "dash do Caçador perdeu a habilidade")

	_reset_combat(player)
	player.weapon_levels.chaos_bolt = 1
	player.bolt_timer = 0.0
	_prepare_target(world, player, target, Vector2(180.0, 0.0))
	var scheduled_before: int = world.projectiles.get_child_count()
	player._update_weapons(0.016)
	_check(world.projectiles.get_child_count() == scheduled_before + 1 and player.bolt_timer > 0.0, "agendador das armas mudou")

	_reset_combat(player)
	player.armor = 5.0
	player.temporary_armor = 2.0
	player.take_damage(20.0, Vector2.RIGHT, false)
	_check_close(player.hp, 112.0, "mitigação de dano normal mudou")
	_check_close(player.invulnerability, 0.58, "janela de invulnerabilidade mudou")
	_check(player.last_direction == Vector2.LEFT and player.hurt_recoil == 1.0, "reação direcional ao dano mudou")
	player.take_damage(20.0, Vector2.RIGHT, false)
	_check_close(player.hp, 112.0, "invulnerabilidade não bloqueou o segundo golpe")
	player.character_guard_time = 1.0
	player.take_damage(20.0, Vector2.ZERO, true)
	_check_close(player.hp, 107.0, "dano ambiental com guarda mudou")
	_check_close(player.invulnerability, 0.20, "invulnerabilidade ambiental mudou")

	_reset_combat(player)
	player.dodge_chance = 1.0
	var hp_before_dodge: float = player.hp
	player.take_damage(40.0)
	_check_close(player.hp, hp_before_dodge, "esquiva garantida deixou passar dano")

	_reset_combat(player)
	player.max_hp = 100.0
	player.hp = 10.0
	player.revive_charges = 1
	player.take_damage(999.0, Vector2.ZERO, true)
	_check_close(player.hp, 55.0, "vida restaurada pela Pluma mudou")
	_check(player.revive_charges == 0 and player.invulnerability == 3.0 and not player.death_started, "estado da ressurreição mudou")

	_reset_combat(player)
	player.max_hp = 100.0
	player.hp = 50.0
	player.heal(20.0, false)
	_check_close(player.hp, 70.0, "cura simples mudou")
	player.heal(100.0, false)
	_check_close(player.hp, 100.0, "limite da cura mudou")
	player.hp = 50.0
	player.life_steal = 0.01
	player.on_damage_dealt(100.0, false)
	_check_close(player.hp, 51.0, "roubo de vida normal mudou")
	player.on_damage_dealt(100.0, true)
	_check_close(player.hp, 52.65, "roubo de vida contra chefe mudou")
	player.on_damage_dealt(10000.0, true)
	_check_close(player.hp, 58.65, "limite do roubo de vida mudou")

	_reset_combat(player)
	player.revive_charges = 0
	player.take_damage(9999.0, Vector2.RIGHT, true)
	_check(player.death_started and player.disabled, "morte definitiva não iniciou a apresentação visual")
	await process_frame
	_check(player.collision_shape.disabled, "morte definitiva não desativou a colisão")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYER COMBAT OK: APIs, nove armas, habilidades, orientação, dano, cura, ressurreição e morte validados")
		quit(0)
	else:
		quit(1)
