extends SceneTree

const BulletScene = preload("res://scenes/bullet.tscn")
const CYCLES := 80
const PLAYER_BURST := 48
const ENEMY_BURST := 96

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PROJECTILE BATCH LIFECYCLE: " + message)


func _spawn_player_burst(world: Node, cycle: int) -> Array[Node]:
	var spawned: Array[Node] = []
	for index in range(PLAYER_BURST):
		var projectile = BulletScene.instantiate()
		projectile.global_position = Vector2(float(index * 5), float(cycle % 7) * 6.0)
		projectile.setup(Vector2.RIGHT, 0.0, 0.0, 99, 6.0 + float(index % 4), Color("a96cff"), false, "chaos_bolt")
		projectile.lifetime = 30.0
		world.add_player_projectile(projectile)
		projectile.set_physics_process(false)
		spawned.append(projectile)
	return spawned


func _spawn_enemy_burst(world: Node, cycle: int) -> Array[Node]:
	var spawned: Array[Node] = []
	for index in range(ENEMY_BURST):
		var projectile = world.spawn_enemy_projectile(
			Vector2(float(index * 4), float(cycle % 9) * 5.0), Vector2.LEFT,
			0.0, 0.0, Color("62c7ff"), 7.0 + float(index % 3), index % 5 == 0
		)
		projectile.set_physics_process(false)
		spawned.append(projectile)
	return spawned


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true

	var first_pool_ids: Dictionary = {}
	var pool_reuse_observed := false
	for cycle in range(CYCLES):
		var player_projectiles := _spawn_player_burst(world, cycle)
		await process_frame
		for projectile in player_projectiles:
			projectile.queue_free()
		await process_frame
		await process_frame
		_check(world.projectiles.get_child_count() == 0, "ciclo %d manteve projétil do jogador destruído" % cycle)
		_check(world.player_projectile_batch_renderer._entries.is_empty(), "ciclo %d manteve referência liberada do jogador" % cycle)

		var enemy_projectiles := _spawn_enemy_burst(world, cycle)
		if cycle == 1:
			for projectile in enemy_projectiles:
				if first_pool_ids.has(projectile.get_instance_id()):
					pool_reuse_observed = true
		await process_frame
		for projectile in enemy_projectiles:
			projectile.prepare_for_pool()
			world.recycle_enemy_projectile(projectile)
			if cycle == 0:
				first_pool_ids[projectile.get_instance_id()] = true
		await process_frame
		await process_frame
		_check(world.enemy_projectiles.get_child_count() == 0, "ciclo %d manteve projétil inimigo ativo" % cycle)
		_check(world.enemy_projectile_batch_renderer._entries.is_empty(), "ciclo %d manteve projétil reciclado registrado" % cycle)
		if world.enemy_projectile_batch_renderer.rendering_enabled:
			world.player_projectile_batch_renderer._sync_batches()
			world.enemy_projectile_batch_renderer._sync_batches()

	_check(pool_reuse_observed, "o teste não reutilizou instâncias do pool inimigo")
	_check(world.enemy_projectile_pool.get_child_count() == ENEMY_BURST, "pool inimigo mudou de tamanho após os ciclos")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PROJECTILE BATCH LIFECYCLE OK: %d ciclos, %d liberações diretas e %d reciclagens/reusos" % [CYCLES, CYCLES * PLAYER_BURST, CYCLES * ENEMY_BURST])
	quit(0 if failures.is_empty() else 1)
