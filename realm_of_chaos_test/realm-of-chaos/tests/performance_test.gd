extends SceneTree

const ENEMY_TYPES := ["prowler", "bat", "mage", "brute", "ember", "bomber", "necromancer", "archer", "assassin", "swarm", "guardian"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true
	for index in range(300):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], false, 3.0)
		var ring := 420.0 + float(index % 8) * 62.0
		enemy.global_position = Vector2.RIGHT.rotated(TAU * index / 300.0) * ring
	world._rebuild_spatial_grid()
	var query_count: int = world.get_enemies_near(Vector2.ZERO, 1000.0).size()
	var started := Time.get_ticks_usec()
	for _frame in range(120):
		await process_frame
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var average_ms := elapsed_ms / 120.0
	var valid: bool = query_count >= 280 and world.enemies.get_child_count() >= 280
	print("PERFORMANCE: 300 inimigos, %.2f ms/quadro no teste headless, índice retornou %d" % [average_ms, query_count])
	world.queue_free()
	await process_frame
	quit(0 if valid else 1)
