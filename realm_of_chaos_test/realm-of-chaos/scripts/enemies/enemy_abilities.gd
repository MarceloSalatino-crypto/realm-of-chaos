extends RefCounted

const EnemyProjectileScene = preload("res://scenes/enemies/enemy_projectile.tscn")

var enemy


func _init(owner_enemy) -> void:
	enemy = owner_enemy


func try_begin_special(distance: float) -> void:
	if enemy.special_cooldown > 0.0:
		return
	match enemy.behavior:
		"bomber":
			if distance <= 105.0:
				begin_special("explode", 0.62)
		"assassin":
			begin_special("dash", 0.42)
		"necromancer":
			begin_special("summon", 0.82)
		"guardian":
			begin_special("ward", 0.66)
		"ossuary":
			begin_special("slam", 0.82)
		"glacial":
			begin_special("radial", 0.78)
		"reaper":
			begin_special("reaper_dash", 0.52)
		"titan":
			begin_special("titan_slam", 0.92)
		"sovereign":
			begin_special("sovereign", 0.68)
		_:
			enemy.special_cooldown = 3.0


func begin_special(special_id: String, duration: float) -> void:
	enemy.pending_special = special_id
	enemy.telegraph_time = duration
	enemy.telegraph_duration = duration
	enemy.attack_pulse = 1.0
	enemy.velocity *= 0.2
	enemy.queue_redraw()
	if enemy.world:
		var radius: float = special_radius()
		enemy.world.spawn_effect(enemy.global_position, enemy.definition_color, radius, duration, false)


func execute_special(direction: Vector2) -> void:
	var executed: String = enemy.pending_special
	enemy.pending_special = ""
	enemy.attack_pulse = 0.46
	match executed:
		"explode":
			bomber_burst()
		"dash":
			enemy.dash_velocity = direction * 560.0
			enemy.special_cooldown = 3.0
		"summon":
			summon_minions(3 + enemy.boss_phase)
			enemy.special_cooldown = 6.5
		"ward":
			cast_guardian_ward()
			enemy.special_cooldown = 5.4
		"slam":
			ground_slam(165.0, 0.82)
			if enemy.boss_phase >= 2:
				spawn_radial_projectiles(5 + enemy.boss_phase * 2, 220.0, 0.45)
			if enemy.boss_phase >= 3:
				summon_minions(2)
			enemy.special_cooldown = maxf(1.6, 3.8 - enemy.boss_phase * 0.45)
		"radial":
			spawn_radial_projectiles(9 + enemy.boss_phase * 3, 235.0 + enemy.boss_phase * 18.0, 0.62)
			if enemy.boss_phase >= 2:
				ground_slam(145.0 + enemy.boss_phase * 18.0, 0.52)
			enemy.special_cooldown = maxf(1.5, 3.5 - enemy.boss_phase * 0.42)
		"reaper_dash":
			enemy.dash_velocity = direction * (690.0 + enemy.boss_phase * 80.0)
			spawn_radial_projectiles(5 + enemy.boss_phase * 2, 285.0, 0.48)
			if enemy.boss_phase >= 3:
				summon_minions(3)
			enemy.special_cooldown = maxf(1.25, 3.0 - enemy.boss_phase * 0.42)
		"titan_slam":
			ground_slam(225.0 + enemy.boss_phase * 18.0, 1.0)
			spawn_radial_projectiles(8 + enemy.boss_phase * 2, 210.0, 0.55)
			if enemy.boss_phase >= 2:
				cast_guardian_ward()
			if enemy.boss_phase >= 3:
				summon_minions(4)
			enemy.special_cooldown = maxf(1.7, 4.0 - enemy.boss_phase * 0.5)
		"sovereign":
			execute_sovereign_pattern(direction)
			enemy.special_cooldown = maxf(1.0, 2.8 - enemy.boss_phase * 0.48)
	enemy.queue_redraw()


func execute_sovereign_pattern(direction: Vector2) -> void:
	enemy.boss_pattern_index += 1
	if enemy.boss_phase == 1:
		if enemy.boss_pattern_index % 2 == 0:
			spawn_radial_projectiles(14, 275.0, 0.58)
		else:
			enemy.dash_velocity = direction * 620.0
			ground_slam(155.0, 0.48)
	elif enemy.boss_phase == 2:
		if enemy.boss_pattern_index % 2 == 0:
			spawn_radial_projectiles(18, 305.0, 0.62)
			summon_minions(4)
		else:
			enemy.dash_velocity = direction * 690.0
			ground_slam(215.0, 0.62)
	else:
		enemy.dash_velocity = direction * 760.0
		spawn_radial_projectiles(24, 340.0, 0.68)
		ground_slam(250.0, 0.72)


func ground_slam(radius: float, damage_scale: float) -> void:
	if enemy.global_position.distance_to(enemy.player.global_position) <= radius + 20.0:
		enemy.player.take_damage(enemy.contact_damage * damage_scale, (enemy.player.global_position - enemy.global_position).normalized())
	if enemy.world:
		enemy.world.spawn_effect(enemy.global_position, enemy.definition_color, radius, 0.48, true)
		enemy.world.audio.play_explosion()
		enemy.world.shake_camera(8.0 if enemy.boss else 4.0, 0.24)


func bomber_burst() -> void:
	if enemy.explosion_done:
		return
	enemy.explosion_done = true
	ground_slam(128.0, 0.86)
	enemy.hp = 0.0
	enemy._die()


func summon_minions(count: int) -> void:
	if not enemy.world:
		return
	for index in range(count):
		var kind := "swarm" if index % 3 == 0 else "prowler"
		var minion = enemy.world.spawn_enemy(kind, false)
		if minion:
			minion.global_position = enemy.global_position + Vector2.RIGHT.rotated(TAU * index / count) * randf_range(54.0, 92.0)
	enemy.world.spawn_effect(enemy.global_position, Color("9d72ff"), 115.0, 0.5, true)


func cast_guardian_ward() -> void:
	if not enemy.world:
		return
	for ally in enemy.world.get_enemies_near(enemy.global_position, 190.0):
		if ally == enemy:
			continue
		ally.hp = minf(ally.max_hp, ally.hp + ally.max_hp * 0.09)
		ally._update_health_visual()
	enemy.world.spawn_effect(enemy.global_position, Color("e0b779"), 190.0, 0.55, false)


func special_radius() -> float:
	match enemy.pending_special:
		"explode": return 128.0
		"slam": return 165.0
		"titan_slam": return 225.0 + enemy.boss_phase * 18.0
		"ward": return 190.0
		"sovereign": return 250.0
		_: return enemy.hit_radius * 2.4


func update_boss_phase() -> void:
	if not enemy.boss or enemy.max_hp <= 0.0:
		return
	var ratio: float = enemy.hp / enemy.max_hp
	var new_phase := 3 if ratio <= 0.34 else (2 if ratio <= 0.67 else 1)
	if new_phase <= enemy.boss_phase:
		return
	for _crossed_phase in range(enemy.boss_phase + 1, new_phase + 1):
		enemy.move_speed *= 1.13
		enemy.contact_damage *= 1.08
	enemy.boss_phase = new_phase
	enemy.special_cooldown = 0.35
	if enemy.world:
		enemy.world.on_boss_phase_changed(enemy, enemy.boss_phase)


func cast_projectile(direction: Vector2) -> void:
	enemy.cast_pulse = 1.0
	enemy.cast_cooldown = 2.7 if enemy.behavior in ["ranged", "necromancer"] else 1.65
	var count := 3 if enemy.behavior == "archer" else 1
	for index in range(count):
		var offset := float(index) - float(count - 1) * 0.5
		spawn_enemy_projectile(direction.rotated(offset * 0.13), enemy.contact_damage * 0.70, 245.0, 8.0)


func spawn_radial_projectiles(count: int, projectile_speed: float, damage_scale: float) -> void:
	enemy.cast_pulse = 1.0
	for index in range(count):
		spawn_enemy_projectile(Vector2.RIGHT.rotated(TAU * index / count + enemy.movement_age * 0.08), enemy.contact_damage * damage_scale, projectile_speed, 9.0 if not enemy.final_boss else 12.0)


func spawn_enemy_projectile(direction: Vector2, amount: float, projectile_speed: float, size: float) -> void:
	var mage_projectile: bool = enemy.enemy_type == "mage"
	var color: Color = Color("ff496d") if mage_projectile else enemy.definition_color
	var spawn_position: Vector2 = enemy.global_position + direction * (enemy.hit_radius + 8.0)
	if enemy.world and enemy.world.has_method("spawn_enemy_projectile"):
		enemy.world.spawn_enemy_projectile(spawn_position, direction, amount, projectile_speed, color, size, mage_projectile)
		return
	var projectile = EnemyProjectileScene.instantiate()
	enemy.get_tree().current_scene.add_child(projectile)
	projectile.global_position = spawn_position
	projectile.setup(direction, amount, projectile_speed, color, size, mage_projectile, null, enemy.player)
