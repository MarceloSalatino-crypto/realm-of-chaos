extends SceneTree

const EnemyScene = preload("res://scenes/enemies/enemy.tscn")


class PlayerProbe:
	extends Node2D

	var damage_taken := 0.0
	var boss_damage_multiplier := 1.0

	func take_damage(amount: float, _force := Vector2.ZERO) -> void:
		damage_taken += amount


class WorldProbe:
	extends Node2D

	var enemy_speed_multiplier := 1.0
	var nearby: Array = []
	var query_calls := 0
	var effects: Array[Dictionary] = []
	var spawn_position := Vector2(321.0, 654.0)
	var spawn_position_calls := 0

	func get_enemies_near(_position: Vector2, _radius: float) -> Array:
		query_calls += 1
		return nearby

	func spawn_effect(position: Vector2, color: Color, radius: float, duration: float, important := false) -> void:
		effects.append({
			"position": position,
			"color": color,
			"radius": radius,
			"duration": duration,
			"important": important,
		})

	func get_spawn_position(_minimum: float, _maximum: float) -> Vector2:
		spawn_position_calls += 1
		return spawn_position

	func is_position_in_visual_bounds(_position: Vector2) -> bool:
		return true


var failures: Array[String] = []
var spawned_enemies: Array[Node] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ENEMY MOTION: " + message)


func _spawn_enemy(world: Node, player: Node) -> Node:
	var enemy = EnemyScene.instantiate()
	enemy.setup("prowler", 1.0, false, world)
	root.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.player = player
	spawned_enemies.append(enemy)
	return enemy


func _run() -> void:
	var player := PlayerProbe.new()
	root.add_child(player)
	player.add_to_group("player")
	var world := WorldProbe.new()
	root.add_child(world)
	var enemy = _spawn_enemy(world, player)
	enemy.move_speed = 100.0

	for method in ["_update_movement", "_apply_separation", "apply_slow"]:
		_check(enemy.has_method(method), "API de movimento ausente: " + method)

	enemy.behavior = "hunter"
	enemy._update_movement(Vector2.RIGHT, 500.0)
	_check(enemy.velocity.is_equal_approx(Vector2(100.0, 0.0)), "perseguicao comum mudou")

	enemy.behavior = "ranged"
	enemy._update_movement(Vector2.RIGHT, 300.0)
	_check(enemy.velocity.is_equal_approx(Vector2(100.0, 0.0)), "aproximacao ranged mudou")
	enemy._update_movement(Vector2.RIGHT, 180.0)
	_check(enemy.velocity.is_equal_approx(Vector2(-100.0, 0.0)), "recuo ranged mudou")
	enemy.movement_age = PI * 0.5 / 1.7
	enemy._update_movement(Vector2.RIGHT, 220.0)
	_check(enemy.velocity.is_equal_approx(Vector2(0.0, 100.0)), "strafe ranged mudou")

	enemy.behavior = "archer"
	enemy._update_movement(Vector2.RIGHT, 219.0)
	_check(enemy.velocity.is_equal_approx(Vector2(-100.0, 0.0)), "distancia minima do arqueiro mudou")
	enemy._update_movement(Vector2.RIGHT, 341.0)
	_check(enemy.velocity.is_equal_approx(Vector2(100.0, 0.0)), "distancia maxima do arqueiro mudou")

	enemy.behavior = "swarm_flight"
	enemy.movement_age = PI * 0.5 / 5.5
	enemy._update_movement(Vector2.RIGHT, 500.0)
	_check(enemy.velocity.is_equal_approx(Vector2.RIGHT.rotated(0.28) * 100.0), "oscilacao de voo mudou")
	enemy.behavior = "assassin"
	enemy.movement_age = PI * 0.5 / 3.2
	enemy._update_movement(Vector2.RIGHT, 500.0)
	_check(enemy.velocity.is_equal_approx(Vector2.RIGHT.rotated(0.12) * 100.0), "trajetoria do assassino mudou")
	enemy.behavior = "sovereign"
	enemy.movement_age = PI * 0.5 / 1.5
	enemy._update_movement(Vector2.RIGHT, 500.0)
	_check(enemy.velocity.is_equal_approx(Vector2.RIGHT.rotated(0.15) * 100.0), "trajetoria do Soberano mudou")

	var neighbor_a := Node2D.new()
	var neighbor_b := Node2D.new()
	root.add_child(neighbor_a)
	root.add_child(neighbor_b)
	neighbor_a.global_position = Vector2(-10.0, 0.0)
	neighbor_b.global_position = Vector2(-20.0, 0.0)
	enemy.global_position = Vector2.ZERO
	enemy.boss = false
	enemy.separation_timer = 0.0
	enemy.separation_force = Vector2.ZERO
	enemy.velocity = Vector2.ZERO
	world.nearby = [enemy, neighbor_a, neighbor_b]
	world.query_calls = 0
	enemy._apply_separation(0.01)
	_check(world.query_calls == 1 and enemy.separation_force.is_equal_approx(Vector2(16.0, 0.0)), "recalculo da separacao mudou")
	_check(enemy.velocity.is_equal_approx(enemy.separation_force) and enemy.separation_timer >= 0.10, "aplicacao ou intervalo da separacao mudou")

	enemy.separation_timer = 0.05
	enemy.separation_force = Vector2(7.0, 3.0)
	enemy.velocity = Vector2(1.0, 2.0)
	var queries_before_cache: int = world.query_calls
	enemy._apply_separation(0.01)
	_check(enemy.velocity.is_equal_approx(Vector2(8.0, 5.0)) and is_equal_approx(enemy.separation_timer, 0.04), "cache da separacao mudou")
	_check(world.query_calls == queries_before_cache, "cache da separacao consultou vizinhos novamente")

	var crowded_neighbors: Array[Node] = []
	for index in range(10):
		var neighbor := Node2D.new()
		root.add_child(neighbor)
		neighbor.global_position = Vector2(-10.0 - index, 0.0)
		crowded_neighbors.append(neighbor)
	enemy.separation_timer = 0.0
	enemy.velocity = Vector2.ZERO
	world.nearby = crowded_neighbors
	enemy._apply_separation(0.01)
	_check(is_equal_approx(enemy.separation_force.length(), 52.0), "limite de oito vizinhos da separacao mudou")
	enemy.boss = true
	enemy.velocity = Vector2(3.0, 4.0)
	enemy.separation_timer = 0.0
	var queries_before_boss: int = world.query_calls
	enemy._apply_separation(0.01)
	_check(enemy.velocity.is_equal_approx(Vector2(3.0, 4.0)) and world.query_calls == queries_before_boss, "chefe passou a receber separacao")
	enemy.boss = false

	world.effects.clear()
	enemy.slow_multiplier = 1.0
	enemy.slow_time = 0.0
	enemy.apply_slow(0.20, 2.0)
	_check(is_equal_approx(enemy.slow_multiplier, 0.35) and is_equal_approx(enemy.slow_time, 2.0), "limite ou duracao da lentidao comum mudou")
	_check(world.effects.size() == 1 and is_equal_approx(float(world.effects[0].radius), enemy.hit_radius * 1.4), "efeito visual da lentidao mudou")
	enemy.apply_slow(0.80, 1.0)
	_check(is_equal_approx(enemy.slow_multiplier, 0.35) and is_equal_approx(enemy.slow_time, 2.0), "lentidao mais fraca substituiu a mais forte")
	enemy.boss = true
	enemy.slow_multiplier = 1.0
	enemy.slow_time = 0.0
	enemy.apply_slow(0.60, 2.0)
	_check(is_equal_approx(enemy.slow_multiplier, 0.60) and is_equal_approx(enemy.slow_time, 0.90), "resistencia de chefe a lentidao mudou")
	enemy.boss = false

	enemy.behavior = "hunter"
	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(1000.0, 0.0)
	world.enemy_speed_multiplier = 1.5
	world.nearby = []
	enemy.move_speed = 100.0
	enemy.slow_multiplier = 0.5
	enemy.slow_time = 1.0
	enemy.knockback_velocity = Vector2(20.0, 0.0)
	enemy.dash_velocity = Vector2(30.0, 0.0)
	enemy.obstacle_avoidance = Vector2(10.0, 0.0)
	enemy.separation_timer = 1.0
	enemy.separation_force = Vector2.ZERO
	enemy.special_cooldown = 100.0
	enemy.cast_cooldown = 100.0
	enemy.damage_cooldown = 100.0
	enemy._physics_process(0.10)
	_check(enemy.velocity.is_equal_approx(Vector2(120.0, 0.0)), "ordem de impulsos e multiplicadores mudou")
	_check(enemy.knockback_velocity.is_zero_approx() and enemy.dash_velocity.is_zero_approx() and enemy.obstacle_avoidance.is_zero_approx(), "dissipacao dos impulsos mudou")
	_check(is_equal_approx(enemy.slow_time, 0.90) and is_equal_approx(enemy.slow_multiplier, 0.5), "tick da lentidao durante movimento mudou")

	enemy.slow_multiplier = 0.5
	enemy.slow_time = 0.05
	enemy.knockback_velocity = Vector2.ZERO
	enemy.dash_velocity = Vector2.ZERO
	enemy.obstacle_avoidance = Vector2.ZERO
	enemy._physics_process(0.10)
	_check(is_zero_approx(enemy.slow_time) and is_equal_approx(enemy.slow_multiplier, 1.0), "lentidao nao terminou no instante esperado")

	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(2000.0, 0.0)
	world.enemy_speed_multiplier = 1.0
	world.spawn_position_calls = 0
	enemy.slow_multiplier = 1.0
	enemy.slow_time = 0.0
	enemy.separation_timer = 1.0
	enemy._physics_process(0.01)
	_check(enemy.global_position.is_equal_approx(world.spawn_position) and world.spawn_position_calls == 1, "reposicionamento distante mudou")

	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(1000.0, 0.0)
	enemy.hit_freeze = 0.10
	enemy.velocity = Vector2(100.0, 0.0)
	var age_before_freeze: float = enemy.movement_age
	enemy._physics_process(0.04)
	_check(enemy.velocity.is_zero_approx() and is_equal_approx(enemy.hit_freeze, 0.06), "bloqueio de movimento durante hit freeze mudou")
	_check(is_equal_approx(enemy.movement_age, age_before_freeze), "relogio de movimento avancou durante hit freeze")

	for spawned_enemy in spawned_enemies:
		if is_instance_valid(spawned_enemy):
			spawned_enemy.queue_free()
	for neighbor in crowded_neighbors:
		if is_instance_valid(neighbor):
			neighbor.queue_free()
	neighbor_a.queue_free()
	neighbor_b.queue_free()
	world.queue_free()
	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY MOTION OK: comportamentos, separacao, lentidao, impulsos e reposicionamento validados")
	quit(0 if failures.is_empty() else 1)
