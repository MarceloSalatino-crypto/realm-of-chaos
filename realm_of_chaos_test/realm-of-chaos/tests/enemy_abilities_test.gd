extends SceneTree

const EnemyScene = preload("res://scenes/enemies/enemy.tscn")


class AudioProbe:
	extends Node

	var explosions := 0

	func play_explosion() -> void:
		explosions += 1


class PlayerProbe:
	extends Node2D

	var damage_taken := 0.0
	var last_force := Vector2.ZERO
	var boss_damage_multiplier := 1.0

	func take_damage(amount: float, force := Vector2.ZERO) -> void:
		damage_taken += amount
		last_force = force


class WorldProbe:
	extends Node2D

	var effects: Array[Dictionary] = []
	var projectiles: Array[Dictionary] = []
	var spawned_minions: Array[Node2D] = []
	var nearby: Array = []
	var phase_changes: Array[int] = []
	var shakes: Array[Vector2] = []
	var deaths := 0
	var audio: Node

	func spawn_effect(world_position: Vector2, color: Color, radius: float, duration: float, important := false) -> void:
		effects.append({
			"position": world_position,
			"color": color,
			"radius": radius,
			"duration": duration,
			"important": important,
		})

	func spawn_enemy_projectile(
		world_position: Vector2,
		direction: Vector2,
		amount: float,
		projectile_speed: float,
		color: Color,
		size: float,
		danger_style := false
	) -> Node:
		projectiles.append({
			"position": world_position,
			"direction": direction,
			"amount": amount,
			"speed": projectile_speed,
			"color": color,
			"size": size,
			"danger": danger_style,
		})
		return null

	func spawn_enemy(kind: String, _force_elite := false) -> Node:
		var minion := Node2D.new()
		minion.set_meta("kind", kind)
		add_child(minion)
		spawned_minions.append(minion)
		return minion

	func get_enemies_near(_position: Vector2, _radius: float) -> Array:
		return nearby

	func shake_camera(strength: float, duration: float) -> void:
		shakes.append(Vector2(strength, duration))

	func on_boss_phase_changed(_enemy: Node, phase: int) -> void:
		phase_changes.append(phase)

	func handle_enemy_death(_enemy: Node, _xp: int, _elite: bool, _boss: bool) -> void:
		deaths += 1


var failures: Array[String] = []
var spawned_enemies: Array[Node] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ENEMY ABILITIES: " + message)


func _spawn_enemy(kind: String, world: Node) -> Node:
	var enemy = EnemyScene.instantiate()
	enemy.setup(kind, 1.0, false, world)
	root.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	spawned_enemies.append(enemy)
	return enemy


func _reset_probe(world: Node, player: Node) -> void:
	world.effects.clear()
	world.projectiles.clear()
	world.spawned_minions.clear()
	world.shakes.clear()
	world.audio.explosions = 0
	player.damage_taken = 0.0
	player.last_force = Vector2.ZERO


func _release_prepared_projectiles(enemy: Node) -> void:
	enemy._update_projectile_attack(enemy.PROJECTILE_PREPARE_DURATION + 0.001)


func _finish_projectile_release(enemy: Node) -> void:
	enemy._update_projectile_attack(enemy.PROJECTILE_RELEASE_DURATION + 0.001)


func _run() -> void:
	var player := PlayerProbe.new()
	root.add_child(player)
	player.add_to_group("player")
	var world := WorldProbe.new()
	root.add_child(world)
	var audio := AudioProbe.new()
	world.add_child(audio)
	world.audio = audio

	var caster = _spawn_enemy("prowler", world)
	caster.player = player
	for method in [
		"_try_begin_special", "_begin_special", "_execute_special", "_execute_sovereign_pattern",
		"_ground_slam", "_bomber_burst", "_summon_minions", "_cast_guardian_ward",
		"_special_radius", "_update_boss_phase", "_cast_projectile",
		"_update_projectile_attack", "_spawn_radial_projectiles", "_spawn_enemy_projectile"
	]:
		_check(caster.has_method(method), "API de habilidade ausente: " + method)

	var begin_cases := [
		{"behavior": "bomber", "distance": 100.0, "id": "explode", "duration": 0.62},
		{"behavior": "assassin", "distance": 500.0, "id": "dash", "duration": 0.42},
		{"behavior": "necromancer", "distance": 500.0, "id": "summon", "duration": 0.82},
		{"behavior": "guardian", "distance": 500.0, "id": "ward", "duration": 0.66},
		{"behavior": "ossuary", "distance": 500.0, "id": "slam", "duration": 0.82},
		{"behavior": "glacial", "distance": 500.0, "id": "radial", "duration": 0.78},
		{"behavior": "reaper", "distance": 500.0, "id": "reaper_dash", "duration": 0.52},
		{"behavior": "titan", "distance": 500.0, "id": "titan_slam", "duration": 0.92},
		{"behavior": "sovereign", "distance": 500.0, "id": "sovereign", "duration": 0.68},
	]
	for entry in begin_cases:
		world.effects.clear()
		caster.behavior = str(entry.behavior)
		caster.special_cooldown = 0.0
		caster.pending_special = ""
		caster.velocity = Vector2(100.0, 0.0)
		caster._try_begin_special(float(entry.distance))
		_check(caster.pending_special == str(entry.id), "selecao incorreta para " + str(entry.behavior))
		_check(is_equal_approx(caster.telegraph_time, float(entry.duration)) and is_equal_approx(caster.telegraph_duration, float(entry.duration)), "duracao incorreta para " + str(entry.behavior))
		_check(caster.velocity.is_equal_approx(Vector2(20.0, 0.0)) and is_equal_approx(caster.attack_pulse, 1.0), "preparacao incorreta para " + str(entry.behavior))
		_check(world.effects.is_empty(), "anel generico duplicado ainda foi criado para " + str(entry.behavior))

	world.effects.clear()
	caster.behavior = "bomber"
	caster.special_cooldown = 0.0
	caster.pending_special = ""
	caster._try_begin_special(106.0)
	_check(caster.pending_special.is_empty() and world.effects.is_empty(), "bomber iniciou explosao fora do alcance")
	caster.behavior = "hunter"
	caster.special_cooldown = 0.0
	caster._try_begin_special(100.0)
	_check(is_equal_approx(caster.special_cooldown, 3.0), "comportamento comum nao aplicou o cooldown de seguranca")

	caster.boss_phase = 2
	caster.hit_radius = 21.0
	var radius_cases := {
		"explode": 128.0,
		"slam": 165.0,
		"titan_slam": 261.0,
		"ward": 190.0,
		"sovereign": 250.0,
		"radial": 50.4,
	}
	for special_id in radius_cases:
		caster.pending_special = special_id
		_check(is_equal_approx(caster._special_radius(), float(radius_cases[special_id])), "raio incorreto para " + special_id)

	var mage = _spawn_enemy("mage", world)
	mage.player = player
	world.projectiles.clear()
	mage._cast_projectile(Vector2.RIGHT)
	_check(world.projectiles.is_empty() and mage.pending_projectile_attack == "normal", "mago disparou antes da pose de preparacao")
	_check(is_equal_approx(mage.cast_cooldown, 2.7) and is_equal_approx(mage.cast_pulse, 1.0), "cooldown ou pulso inicial do mago mudou")
	mage._update_projectile_attack(0.19)
	_check(world.projectiles.is_empty(), "mago disparou antes dos 0,20s de preparacao")
	mage._update_projectile_attack(0.011)
	_check(world.projectiles.size() == 1 and mage.pending_projectile_attack.is_empty(), "disparo simples do mago nao saiu na liberacao")
	_check(bool(world.projectiles[0].danger) and Color(world.projectiles[0].color).is_equal_approx(Color("ff496d")), "identidade visual perigosa do projetil do mago mudou")
	_check(is_equal_approx(float(world.projectiles[0].amount), mage.contact_damage * 0.70) and is_equal_approx(float(world.projectiles[0].speed), 245.0), "parametros do projetil do mago mudaram")
	_check(Vector2(world.projectiles[0].position).is_equal_approx(mage.global_position + Vector2.RIGHT * (mage.hit_radius + 8.0)), "alcance inicial do projetil do mago mudou")

	var archer = _spawn_enemy("archer", world)
	archer.player = player
	world.projectiles.clear()
	archer._cast_projectile(Vector2.RIGHT)
	_check(world.projectiles.is_empty() and archer.pending_projectile_attack == "normal" and is_equal_approx(archer.cast_cooldown, 1.65), "preparacao ou cooldown da rajada tripla mudou")
	_release_prepared_projectiles(archer)
	_check(world.projectiles.size() == 3, "rajada tripla do arqueiro nao saiu na liberacao")
	_check(float(world.projectiles[0].direction.y) < 0.0 and is_zero_approx(float(world.projectiles[1].direction.y)) and float(world.projectiles[2].direction.y) > 0.0, "abertura angular do arqueiro mudou")

	var overlapping_necromancer = _spawn_enemy("necromancer", world)
	overlapping_necromancer.player = player
	overlapping_necromancer._cast_projectile(Vector2.RIGHT)
	overlapping_necromancer.special_cooldown = 0.0
	overlapping_necromancer._try_begin_special(500.0)
	_check(overlapping_necromancer.pending_projectile_attack == "normal" and overlapping_necromancer.pending_special == "summon", "preparacao do tiro atrasou a frequencia do especial do necromante")

	world.projectiles.clear()
	caster.final_boss = true
	caster.movement_age = 0.0
	caster._spawn_radial_projectiles(7, 300.0, 0.5)
	_check(world.projectiles.is_empty() and caster.pending_projectile_attack == "radial" and is_equal_approx(caster.cast_pulse, 1.0), "rajada radial nao entrou em preparacao")
	_release_prepared_projectiles(caster)
	_check(world.projectiles.size() == 7 and is_equal_approx(caster.cast_pulse, 0.46), "quantidade ou pose de liberacao da rajada radial mudou")
	_check(is_equal_approx(float(world.projectiles[0].size), 12.0) and is_equal_approx(float(world.projectiles[0].amount), caster.contact_damage * 0.5), "parametros da rajada radial final mudaram")

	var ally = _spawn_enemy("prowler", world)
	ally.player = player
	ally.max_hp = 100.0
	ally.hp = 50.0
	ally.health_bar.max_value = ally.max_hp
	ally._update_health_visual()
	world.nearby = [caster, ally]
	world.effects.clear()
	caster._cast_guardian_ward()
	_check(is_equal_approx(ally.hp, 59.0) and is_equal_approx(ally.health_bar.value, 59.0), "cura e barra do guardiao mudaram")
	_check(world.effects.size() == 1 and is_equal_approx(float(world.effects[0].radius), 190.0), "efeito da protecao do guardiao mudou")

	var ability_boss = _spawn_enemy("ossuary_colossus", world)
	ability_boss.player = player
	ability_boss.global_position = Vector2.ZERO
	player.global_position = Vector2(10.0, 0.0)
	ability_boss.contact_damage = 100.0
	ability_boss.boss_phase = 2
	_reset_probe(world, player)
	ability_boss.pending_special = "slam"
	ability_boss._execute_special(Vector2.RIGHT)
	_check(ability_boss.pending_special.is_empty() and is_equal_approx(ability_boss.attack_pulse, 0.46), "estado comum de execucao do especial mudou")
	_check(is_equal_approx(player.damage_taken, 82.0) and world.projectiles.is_empty(), "impacto do colosso mudou ou projeteis ignoraram a preparacao")
	_check(is_equal_approx(ability_boss.special_cooldown, 2.9) and world.audio.explosions == 1, "cooldown ou audio do colosso mudou")
	_release_prepared_projectiles(ability_boss)
	_check(world.projectiles.size() == 9, "projeteis do colosso nao sairam na liberacao")
	_finish_projectile_release(ability_boss)

	_reset_probe(world, player)
	ability_boss.boss_phase = 2
	ability_boss.pending_special = "radial"
	ability_boss._execute_special(Vector2.RIGHT)
	_check(world.projectiles.is_empty() and is_equal_approx(player.damage_taken, 52.0), "padrao radial ignorou a preparacao ou mudou o impacto")
	_check(is_equal_approx(ability_boss.special_cooldown, 2.66), "cooldown do padrao radial mudou")
	_release_prepared_projectiles(ability_boss)
	_check(world.projectiles.size() == 15, "padrao radial da segunda fase nao saiu na liberacao")
	_finish_projectile_release(ability_boss)

	_reset_probe(world, player)
	ability_boss.boss_phase = 3
	ability_boss.dash_velocity = Vector2.ZERO
	ability_boss.pending_special = "reaper_dash"
	ability_boss._execute_special(Vector2.RIGHT)
	_check(ability_boss.dash_velocity.is_equal_approx(Vector2(930.0, 0.0)) and world.projectiles.is_empty() and world.spawned_minions.size() == 3, "padrao do ceifador ignorou a preparacao ou mudou dash/invocacoes")
	_check(is_equal_approx(ability_boss.special_cooldown, 1.74), "cooldown do ceifador mudou")
	_release_prepared_projectiles(ability_boss)
	_check(world.projectiles.size() == 11, "projeteis do ceifador nao sairam na liberacao")
	_finish_projectile_release(ability_boss)

	_reset_probe(world, player)
	world.nearby = [ability_boss, ally]
	ability_boss.boss_phase = 3
	ability_boss.pending_special = "titan_slam"
	ability_boss._execute_special(Vector2.RIGHT)
	_check(world.projectiles.is_empty() and world.spawned_minions.size() == 4 and is_equal_approx(player.damage_taken, 100.0), "padrao do tita ignorou a preparacao ou mudou impacto/invocacoes")
	_check(is_equal_approx(ability_boss.special_cooldown, 2.5), "cooldown do tita mudou")
	_release_prepared_projectiles(ability_boss)
	_check(world.projectiles.size() == 14, "projeteis do tita nao sairam na liberacao")
	_finish_projectile_release(ability_boss)

	_reset_probe(world, player)
	ability_boss.boss_phase = 3
	ability_boss.boss_pattern_index = 0
	ability_boss.dash_velocity = Vector2.ZERO
	ability_boss.pending_special = "sovereign"
	ability_boss._execute_special(Vector2.RIGHT)
	_check(ability_boss.boss_pattern_index == 1 and ability_boss.dash_velocity.is_equal_approx(Vector2(760.0, 0.0)), "avanco do Soberano mudou")
	_check(world.projectiles.is_empty() and is_equal_approx(player.damage_taken, 72.0) and is_equal_approx(ability_boss.special_cooldown, 1.36), "padrao final do Soberano ignorou a preparacao ou mudou impacto/cooldown")
	_release_prepared_projectiles(ability_boss)
	_check(world.projectiles.size() == 24, "projeteis finais do Soberano nao sairam na liberacao")

	var phase_boss = _spawn_enemy("ossuary_colossus", world)
	phase_boss.player = player
	phase_boss.max_hp = 100.0
	phase_boss.hp = 67.0
	var phase_one_speed: float = phase_boss.move_speed
	var phase_one_damage: float = phase_boss.contact_damage
	world.phase_changes.clear()
	phase_boss._update_boss_phase()
	_check(phase_boss.boss_phase == 2 and is_equal_approx(phase_boss.move_speed, phase_one_speed * 1.13), "entrada na segunda fase mudou")
	_check(is_equal_approx(phase_boss.contact_damage, phase_one_damage * 1.08) and is_equal_approx(phase_boss.special_cooldown, 0.35), "bonus ou cooldown da segunda fase mudou")
	phase_boss.hp = 34.0
	phase_boss._update_boss_phase()
	_check(phase_boss.boss_phase == 3 and world.phase_changes == [2, 3], "entrada na terceira fase ou notificacao mudou")
	var sequential_phase_speed: float = phase_boss.move_speed
	var sequential_phase_damage: float = phase_boss.contact_damage
	_check(is_equal_approx(sequential_phase_speed, phase_one_speed * 1.2769), "velocidade final da transicao sequencial mudou")
	_check(is_equal_approx(sequential_phase_damage, phase_one_damage * 1.1664), "dano final da transicao sequencial mudou")

	var skipped_phase_boss = _spawn_enemy("ossuary_colossus", world)
	skipped_phase_boss.player = player
	skipped_phase_boss.max_hp = 100.0
	skipped_phase_boss.hp = 34.0
	var skipped_base_speed: float = skipped_phase_boss.move_speed
	var skipped_base_damage: float = skipped_phase_boss.contact_damage
	world.phase_changes.clear()
	skipped_phase_boss._update_boss_phase()
	_check(skipped_phase_boss.boss_phase == 3, "salto direto nao chegou a terceira fase")
	_check(is_equal_approx(skipped_phase_boss.move_speed, skipped_base_speed * 1.2769), "salto direto nao acumulou dois bonus de velocidade")
	_check(is_equal_approx(skipped_phase_boss.contact_damage, skipped_base_damage * 1.1664), "salto direto nao acumulou dois bonus de dano")
	_check(
		is_equal_approx(skipped_phase_boss.move_speed / skipped_base_speed, sequential_phase_speed / phase_one_speed)
		and is_equal_approx(skipped_phase_boss.contact_damage / skipped_base_damage, sequential_phase_damage / phase_one_damage),
		"salto direto e transicao sequencial deixaram forcas diferentes"
	)
	_check(world.phase_changes == [3], "salto direto notificou fases intermediarias")
	_check(is_equal_approx(skipped_phase_boss.special_cooldown, 0.35), "salto direto nao reiniciou o cooldown uma unica vez")

	var skipped_speed_after_transition: float = skipped_phase_boss.move_speed
	var skipped_damage_after_transition: float = skipped_phase_boss.contact_damage
	skipped_phase_boss.special_cooldown = 1.25
	skipped_phase_boss._update_boss_phase()
	_check(
		is_equal_approx(skipped_phase_boss.move_speed, skipped_speed_after_transition)
		and is_equal_approx(skipped_phase_boss.contact_damage, skipped_damage_after_transition)
		and is_equal_approx(skipped_phase_boss.special_cooldown, 1.25)
		and world.phase_changes == [3],
		"atualizacao repetida duplicou bonus, cooldown ou notificacao"
	)
	skipped_phase_boss.hp = 100.0
	skipped_phase_boss._update_boss_phase()
	_check(
		skipped_phase_boss.boss_phase == 3
		and is_equal_approx(skipped_phase_boss.move_speed, skipped_speed_after_transition)
		and is_equal_approx(skipped_phase_boss.contact_damage, skipped_damage_after_transition)
		and is_equal_approx(skipped_phase_boss.special_cooldown, 1.25)
		and world.phase_changes == [3],
		"cura regrediu a fase ou reaplicou efeitos da transicao"
	)

	var bomber = _spawn_enemy("bomber", world)
	bomber.player = player
	bomber.global_position = Vector2.ZERO
	bomber.contact_damage = 100.0
	_reset_probe(world, player)
	var deaths_before: int = world.deaths
	bomber._bomber_burst()
	_check(bomber.explosion_done and bomber.dead and is_equal_approx(bomber.hp, 0.0), "explosao fatal do bomber mudou")
	_check(is_equal_approx(player.damage_taken, 86.0) and world.deaths == deaths_before + 1, "dano ou morte do bomber mudou")
	bomber._bomber_burst()
	_check(world.deaths == deaths_before + 1, "bomber explodiu mais de uma vez")

	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	world.queue_free()
	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY ABILITIES OK: telegrafias, projeteis, padroes, invocacoes, cura e fases validados")
	quit(0 if failures.is_empty() else 1)
