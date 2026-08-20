extends RefCounted

const HomingEyeScript = preload("res://scripts/homing_eye.gd")

var player


func _init(owner_player) -> void:
	player = owner_player


func start_dash(input_direction: Vector2, world: Node) -> void:
	player.dash_direction = input_direction.normalized() if input_direction.length_squared() > 0.01 else player.last_direction
	player.dash_duration = 0.18
	player.dash_cooldown = player.DASH_COOLDOWN_DURATION
	player.invulnerability = maxf(player.invulnerability, 0.34)
	player.attack_direction = player.dash_direction
	if world and world.has_method("on_player_dash"):
		world.on_player_dash(player.dash_direction)
	activate_character_skill(world)


func activate_character_skill(world: Node) -> void:
	if not world:
		return
	player.attack_recoil = 1.0
	match player.character_id:
		"glacial_oracle":
			for enemy in enemies_near(245.0):
				if not is_instance_valid(enemy):
					continue
				enemy.take_damage(
					18.0 * player.effective_damage_multiplier(),
					(enemy.global_position - player.global_position).normalized() * 24.0,
					false, "oracle_skill"
				)
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.45, 2.5)
			world.spawn_effect(player.global_position, Color("70dcff"), 245.0, 0.48, true)
		"crimson_knight":
			var hits := 0
			for enemy in enemies_near(175.0):
				if not is_instance_valid(enemy):
					continue
				enemy.take_damage(
					26.0 * player.effective_damage_multiplier(),
					(enemy.global_position - player.global_position).normalized() * 55.0,
					false, "knight_skill"
				)
				hits += 1
			player.character_guard_time = 1.8
			heal(minf(18.0, hits * 2.2), false)
			world.spawn_weapon_flash(
				player.global_position + player.dash_direction * 34.0, 0,
				player.dash_direction.angle() - 0.65, 0.34, 0.28, Color("ff6b72")
			)
		"void_automaton":
			var candidates: Array[Node] = enemies_near(520.0)
			candidates.sort_custom(func(a, b): return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position))
			var points := PackedVector2Array([player.global_position])
			for enemy in candidates.slice(0, mini(7, candidates.size())):
				if is_instance_valid(enemy):
					enemy.take_damage(15.0 * player.effective_damage_multiplier(), Vector2.ZERO, false, "automaton_skill")
					points.append(enemy.global_position)
			world.spawn_lightning(points, Color("b873ff"))
		_:
			var base_direction: Vector2 = player.dash_direction
			var target := nearest_enemy()
			if target:
				base_direction = (target.global_position - player.global_position).normalized()
			for index in range(5):
				var offset := float(index) - 2.0
				spawn_player_projectile(
					base_direction.rotated(offset * 0.14),
					19.0 * player.effective_damage_multiplier(), 830.0, 2, 7.0,
					Color("f0d2ff"), "hunter_skill", true
				)


func set_primary_attack_facing(direction: Vector2, weapon_id: String) -> void:
	player._set_primary_attack_facing(direction, weapon_id)


func update_weapons(delta: float) -> void:
	var bolt_level: int = player.weapon_levels.chaos_bolt
	if bolt_level > 0:
		player.bolt_timer -= delta
		if player.bolt_timer <= 0.0:
			fire_chaos_bolt()

	var blade_level: int = player.weapon_levels.shadow_blades
	if blade_level > 0:
		player.blades_timer -= delta
		if player.blades_timer <= 0.0:
			fire_shadow_blades(blade_level)

	var orbit_level: int = player.weapon_levels.soul_orbit
	if orbit_level > 0:
		player.orbit_angle += delta * (1.8 + orbit_level * 0.16)
		player.orbit_tick -= delta
		if player.orbit_tick <= 0.0:
			damage_orbit(orbit_level)
		player.queue_redraw()

	var nova_level: int = player.weapon_levels.chaos_nova
	if nova_level > 0:
		player.nova_timer -= delta
		if player.nova_timer <= 0.0:
			cast_nova(nova_level)

	var scythe_level: int = player.weapon_levels.blood_scythe
	if scythe_level > 0:
		player.scythe_timer -= delta
		if player.scythe_timer <= 0.0:
			swing_blood_scythe(scythe_level)

	var grimoire_level: int = player.weapon_levels.forbidden_grimoire
	if grimoire_level > 0:
		player.grimoire_timer -= delta
		if player.grimoire_timer <= 0.0:
			cast_forbidden_grimoire(grimoire_level)

	var hammer_level: int = player.weapon_levels.rune_hammer
	if hammer_level > 0:
		player.hammer_timer -= delta
		if player.hammer_timer <= 0.0:
			slam_rune_hammer(hammer_level)

	var storm_level: int = player.weapon_levels.storm_relic
	if storm_level > 0:
		player.storm_timer -= delta
		if player.storm_timer <= 0.0:
			cast_storm_chain(storm_level)

	var swarm_level: int = player.weapon_levels.swarm_idol
	if swarm_level > 0:
		player.swarm_timer -= delta
		if player.swarm_timer <= 0.0:
			release_swarm_eyes(swarm_level)


func fire_chaos_bolt() -> void:
	var target := nearest_enemy()
	var weapon_level: int = player.weapon_levels.chaos_bolt
	var evolved := bool(player.evolved_weapons.chaos_bolt)
	player.bolt_timer = maxf(
		0.12 if evolved else 0.16,
		(0.48 if evolved else 0.68 - weapon_level * 0.045) * player.effective_cooldown_multiplier()
	)
	if not target:
		return
	notify_weapon_fired("chaos_bolt")
	var count: int = ((3 + int(weapon_level / 4.0)) if evolved else (1 + int((weapon_level - 1) / 3.0))) + int(player.projectile_bonus)
	var base_direction: Vector2 = (target.global_position - player.global_position).normalized()
	set_primary_attack_facing(base_direction, "chaos_bolt")
	for index in range(count):
		var offset := float(index) - float(count - 1) * 0.5
		spawn_player_projectile(
			base_direction.rotated(offset * (0.09 if evolved else 0.12)),
			(14.0 + weapon_level * 4.2) * player.effective_damage_multiplier() * (2.05 if evolved else 1.0),
			760.0 if evolved else 650.0, 8 if evolved else int(weapon_level / 3.0),
			14.0 if evolved else 8.0 + weapon_level * 0.7,
			Color("ffd36b") if evolved else Color("a96cff"), "chaos_bolt"
		)


func fire_shadow_blades(weapon_level: int) -> void:
	var target := nearest_enemy()
	var evolved := bool(player.evolved_weapons.shadow_blades)
	player.blades_timer = maxf(
		0.36 if evolved else 0.45,
		(0.78 if evolved else 2.0 - weapon_level * 0.16) * player.effective_cooldown_multiplier()
	)
	if not target:
		return
	notify_weapon_fired("shadow_blades")
	var count: int = (16 if evolved else 2 + weapon_level) + int(player.projectile_bonus)
	var base_direction: Vector2 = (target.global_position - player.global_position).normalized()
	if not evolved:
		set_primary_attack_facing(base_direction, "shadow_blades")
	for index in range(count):
		var direction := Vector2.RIGHT.rotated(TAU * index / count) if evolved else base_direction.rotated((float(index) - float(count - 1) * 0.5) * 0.13)
		spawn_player_projectile(
			direction,
			(10.0 + weapon_level * 3.0) * player.effective_damage_multiplier() * (1.62 if evolved else 1.0),
			820.0 if evolved else 760.0, 3 if evolved else 1,
			8.0 if evolved else 6.0, Color("df63ff") if evolved else Color("ff557d"),
			"shadow_blades"
		)


func spawn_player_projectile(
	direction: Vector2, amount: float, projectile_speed: float,
	pierce: int, size: float, color: Color, weapon_id := "unknown", force_critical := false
) -> void:
	if not player.bullet_scene:
		return
	player.attack_direction = direction
	player.attack_recoil = 1.0
	player.attack_flash = 1.0
	player.queue_redraw()
	var bullet: Node = player.bullet_scene.instantiate()
	var is_critical: bool = bool(force_critical) or randf() < player.effective_crit_chance()
	if is_critical:
		amount *= player.critical_multiplier
	bullet.global_position = player.global_position + direction * 22.0
	bullet.setup(direction, amount, projectile_speed, pierce, size, color, is_critical, weapon_id)
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if world:
		world.add_player_projectile(bullet)
	else:
		bullet.queue_free()


func damage_orbit(weapon_level: int) -> void:
	player.orbit_tick = 0.10
	var evolved := bool(player.evolved_weapons.soul_orbit)
	var radius := 122.0 + weapon_level * 8.0 if evolved else 72.0 + weapon_level * 8.0
	var blade_count := 6 + int(weapon_level / 2.0) if evolved else 2 + int(weapon_level / 2.0)
	var now := Time.get_ticks_msec()
	var sound_played := false
	for enemy in enemies_near(radius + 60.0):
		if not is_instance_valid(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) > radius + enemy.hit_radius:
			continue
		var enemy_id := enemy.get_instance_id()
		if now - int(player.orbit_hit_times.get(enemy_id, 0)) < 430:
			continue
		for index in range(blade_count):
			var blade_position: Vector2 = player.global_position + Vector2.RIGHT.rotated(player.orbit_angle + TAU * index / blade_count) * radius
			if blade_position.distance_to(enemy.global_position) <= 28.0 + enemy.hit_radius:
				if not sound_played:
					notify_weapon_fired("soul_orbit")
					sound_played = true
				player.orbit_hit_times[enemy_id] = now
				player.attack_recoil = 1.0
				var is_critical: bool = randf() < player.effective_crit_chance()
				var amount: float = (8.0 + weapon_level * 3.0) * player.effective_damage_multiplier() * (1.85 if evolved else 1.0) * (player.critical_multiplier if is_critical else 1.0)
				enemy.take_damage(
					amount,
					(enemy.global_position - player.global_position).normalized() * (18.0 if evolved else 8.0),
					is_critical, "soul_orbit"
				)
				if evolved:
					heal(0.35, false)
				break


func cast_nova(weapon_level: int) -> void:
	var evolved := bool(player.evolved_weapons.chaos_nova)
	var radius := 275.0 + weapon_level * 26.0 if evolved else 155.0 + weapon_level * 24.0
	player.nova_timer = maxf(
		1.35 if evolved else 2.4,
		(3.1 if evolved else 6.2 - weapon_level * 0.48) * player.effective_cooldown_multiplier()
	)
	player.attack_direction = player.last_direction
	player.attack_recoil = 1.0
	player.attack_flash = 1.0
	player.queue_redraw()
	notify_weapon_fired("chaos_nova")
	for enemy in enemies_near(radius + 70.0):
		if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) <= radius + enemy.hit_radius:
			var force: Vector2 = (enemy.global_position - player.global_position).normalized() * (155.0 if evolved else 85.0)
			var is_critical: bool = randf() < player.effective_crit_chance()
			var amount: float = (25.0 + weapon_level * 9.0) * player.effective_damage_multiplier() * (2.1 if evolved else 1.0) * (player.critical_multiplier if is_critical else 1.0)
			enemy.take_damage(amount, force, is_critical, "chaos_nova")
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if world:
		world.spawn_effect(player.global_position, Color("ffd36b") if evolved else Color("bd72ff"), radius, 0.72 if evolved else 0.55, true)
		if evolved:
			world.shake_camera(6.0, 0.24)


func swing_blood_scythe(weapon_level: int) -> void:
	var evolved := bool(player.evolved_weapons.blood_scythe)
	player.scythe_timer = maxf(0.42, (1.55 - weapon_level * 0.10) * player.effective_cooldown_multiplier() * (0.72 if evolved else 1.0))
	var target := nearest_enemy()
	var direction: Vector2 = (target.global_position - player.global_position).normalized() if target else player.last_direction
	var radius := 245.0 if evolved else 145.0 + weapon_level * 10.0
	var hits := 0
	notify_weapon_fired("blood_scythe")
	for enemy in enemies_near(radius + 70.0):
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - player.global_position
		if to_enemy.length() > radius + enemy.hit_radius:
			continue
		if not evolved and direction.dot(to_enemy.normalized()) < 0.08:
			continue
		var critical: bool = randf() < player.effective_crit_chance()
		var amount: float = (22.0 + weapon_level * 6.0) * player.effective_damage_multiplier() * (1.85 if evolved else 1.0) * (player.critical_multiplier if critical else 1.0)
		enemy.take_damage(amount, to_enemy.normalized() * (72.0 if evolved else 38.0), critical, "blood_scythe")
		hits += 1
	if hits > 0:
		heal(minf(10.0 if evolved else 4.0, hits * (0.75 if evolved else 0.32)), false)
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if world:
		world.spawn_weapon_flash(player.global_position + direction * 50.0, 0, direction.angle() - 0.68, 0.42 if evolved else 0.30, 0.34, Color("ff6878"))
	player.attack_recoil = 1.0


func cast_forbidden_grimoire(weapon_level: int) -> void:
	var target := nearest_enemy()
	var evolved := bool(player.evolved_weapons.forbidden_grimoire)
	player.grimoire_timer = maxf(0.80, (3.25 - weapon_level * 0.24) * player.effective_cooldown_multiplier() * (0.72 if evolved else 1.0))
	if not target:
		return
	var center: Vector2 = target.global_position
	var radius := 205.0 if evolved else 92.0 + weapon_level * 11.0
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if not world:
		return
	notify_weapon_fired("forbidden_grimoire")
	for enemy in world.get_enemies_near(center, radius + 65.0):
		if is_instance_valid(enemy) and center.distance_to(enemy.global_position) <= radius + enemy.hit_radius:
			var critical: bool = randf() < player.effective_crit_chance()
			var amount: float = (28.0 + weapon_level * 7.5) * player.effective_damage_multiplier() * (1.82 if evolved else 1.0) * (player.critical_multiplier if critical else 1.0)
			enemy.take_damage(amount, (enemy.global_position - center).normalized() * 34.0, critical, "forbidden_grimoire")
	world.spawn_weapon_flash(center + Vector2(0, -18), 1, 0.0, 0.25 if evolved else 0.19, 0.52, Color("d28cff"))
	world.spawn_effect(center, Color("a34cff"), radius, 0.58, true)
	player.attack_recoil = 1.0


func slam_rune_hammer(weapon_level: int) -> void:
	var target := nearest_enemy()
	var evolved := bool(player.evolved_weapons.rune_hammer)
	player.hammer_timer = maxf(0.92, (3.6 - weapon_level * 0.23) * player.effective_cooldown_multiplier() * (0.74 if evolved else 1.0))
	if not target:
		return
	var direction: Vector2 = (target.global_position - player.global_position).normalized()
	var strike_position: Vector2 = player.global_position + direction * minf(235.0, player.global_position.distance_to(target.global_position))
	var radius := 230.0 if evolved else 105.0 + weapon_level * 12.0
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if not world:
		return
	notify_weapon_fired("rune_hammer")
	for enemy in world.get_enemies_near(strike_position, radius + 65.0):
		if is_instance_valid(enemy) and strike_position.distance_to(enemy.global_position) <= radius + enemy.hit_radius:
			var amount: float = (38.0 + weapon_level * 9.0) * player.effective_damage_multiplier() * (2.0 if evolved else 1.0)
			enemy.take_damage(amount, (enemy.global_position - strike_position).normalized() * (185.0 if evolved else 105.0), false, "rune_hammer")
	world.spawn_weapon_flash(strike_position + Vector2(0, -42), 2, direction.angle() + 0.72, 0.30 if evolved else 0.23, 0.38, Color("ffd56c"))
	world.spawn_effect(strike_position, Color("ffd064"), radius, 0.50, true)
	world.shake_camera(7.0 if evolved else 4.0, 0.20)
	player.attack_recoil = 1.0


func cast_storm_chain(weapon_level: int) -> void:
	var evolved := bool(player.evolved_weapons.storm_relic)
	player.storm_timer = maxf(0.32, (1.75 - weapon_level * 0.11) * player.effective_cooldown_multiplier() * (0.65 if evolved else 1.0))
	var candidates: Array[Node] = enemies_near(720.0)
	if candidates.is_empty():
		return
	notify_weapon_fired("storm_relic")
	candidates.sort_custom(func(a, b): return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position))
	var count := mini(candidates.size(), 11 if evolved else 2 + weapon_level)
	var points := PackedVector2Array([player.global_position])
	for enemy in candidates.slice(0, count):
		if not is_instance_valid(enemy):
			continue
		var critical: bool = randf() < player.effective_crit_chance()
		var amount: float = (15.0 + weapon_level * 4.0) * player.effective_damage_multiplier() * (1.72 if evolved else 1.0) * (player.critical_multiplier if critical else 1.0)
		enemy.take_damage(amount, Vector2.ZERO, critical, "storm_relic")
		points.append(enemy.global_position)
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if world:
		world.spawn_weapon_flash(player.global_position + Vector2(25, -34), 3, -0.35, 0.17, 0.32, Color("7eefff"))
		world.spawn_lightning(points, Color("68eaff") if not evolved else Color("f5e57c"))
	player.attack_recoil = 1.0


func release_swarm_eyes(weapon_level: int) -> void:
	var evolved := bool(player.evolved_weapons.swarm_idol)
	player.swarm_timer = maxf(0.55, (2.7 - weapon_level * 0.16) * player.effective_cooldown_multiplier() * (0.70 if evolved else 1.0))
	var candidates: Array[Node] = enemies_near(900.0)
	if candidates.is_empty():
		return
	var count := 2 + int(weapon_level / 2.0) + (3 if evolved else 0)
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if not world:
		return
	notify_weapon_fired("swarm_idol")
	for index in range(count):
		var target: Node2D = candidates[index % candidates.size()]
		var critical: bool = randf() < player.effective_crit_chance()
		var amount: float = (18.0 + weapon_level * 5.0) * player.effective_damage_multiplier() * (1.68 if evolved else 1.0) * (player.critical_multiplier if critical else 1.0)
		var eye = HomingEyeScript.new()
		eye.setup(player.global_position + Vector2.RIGHT.rotated(TAU * index / count) * 28.0, target, amount, 430.0 if evolved else 350.0, critical)
		world.add_player_projectile(eye)
	world.spawn_weapon_flash(player.global_position + Vector2(-24, -42), 4, 0.0, 0.16, 0.42, Color("d592ff"))
	player.attack_recoil = 1.0


func notify_weapon_fired(weapon_id: String) -> void:
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if world and world.has_method("on_weapon_fired"):
		world.on_weapon_fired(weapon_id)


func nearest_enemy() -> Node2D:
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_nearest_enemy"):
		return world.get_nearest_enemy(player.global_position)
	return null


func enemies_near(radius: float) -> Array[Node]:
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_enemies_near"):
		return world.get_enemies_near(player.global_position, radius)
	var fallback: Array[Node] = []
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and player.global_position.distance_to(enemy.global_position) <= radius:
			fallback.append(enemy)
	return fallback


func take_damage(amount: float, source_direction := Vector2.ZERO, environmental := false) -> void:
	if player.disabled or (player.invulnerability > 0.0 and not environmental):
		return
	if not environmental and randf() < player.dodge_chance:
		var dodge_world: Node = player.get_tree().get_first_node_in_group("world")
		if dodge_world:
			dodge_world.spawn_damage_number(player.global_position, 0.0, false, false, "ESQUIVA")
		return
	var guard_armor: float = 8.0 if player.character_guard_time > 0.0 else 0.0
	var final_damage: float = maxf(1.0, amount - player.armor - player.temporary_armor - guard_armor)
	player.hp = maxf(0.0, player.hp - final_damage)
	player.invulnerability = 0.20 if environmental else 0.58
	player.hurt_recoil = 1.0
	if source_direction.length_squared() > 0.01:
		player.last_direction = -source_direction.normalized()
	var world: Node = player.get_tree().get_first_node_in_group("world")
	if world:
		world.record_player_damage(final_damage)
		world.on_player_damaged()
	if player.hp <= 0.0:
		if player.revive_charges > 0:
			player.revive_charges -= 1
			player.hp = player.max_hp * 0.55
			player.invulnerability = 3.0
			if world:
				world.on_player_revived()
		else:
			player._play_death_animation()


func heal(amount: float, show_effect := true) -> void:
	var old_hp: float = player.hp
	player.hp = minf(player.max_hp, player.hp + amount)
	if show_effect and player.hp > old_hp:
		var world: Node = player.get_tree().get_first_node_in_group("world")
		if world:
			world.spawn_effect(player.global_position, Color("65ff9a"), 55.0, 0.35)
			world.spawn_damage_number(player.global_position, player.hp - old_hp, false, true)


func on_damage_dealt(amount: float, target_is_boss: bool) -> void:
	if player.life_steal <= 0.0 or amount <= 0.0:
		return
	var multiplier: float = 1.65 if target_is_boss else 1.0
	heal(minf(6.0, amount * player.life_steal * multiplier), false)
