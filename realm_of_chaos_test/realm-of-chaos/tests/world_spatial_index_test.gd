extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("WORLD SPATIAL INDEX: " + message)


func _spawn_stationary_enemy(world: Node, position: Vector2) -> Node:
	var enemy = world.spawn_enemy("prowler", false, 1.0)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.global_position = position
	return enemy


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true

	_check(world.has_method("get_enemies_near"), "get_enemies_near deixou de existir no World")
	_check(world.has_method("get_nearest_enemy"), "get_nearest_enemy deixou de existir no World")
	_check(world.has_method("_rebuild_spatial_grid"), "_rebuild_spatial_grid deixou de existir no World")
	_check(world._grid_cell(Vector2(-1.0, -1.0)) == Vector2i(-1, -1), "coordenadas negativas nao usam arredondamento para baixo")

	var origin := Vector2(-200.0, -90.0)
	var nearest = _spawn_stationary_enemy(world, origin + Vector2(35.0, 0.0))
	var diagonal = _spawn_stationary_enemy(world, origin + Vector2(-120.0, 90.0))
	var boundary = _spawn_stationary_enemy(world, origin + Vector2(250.0, 0.0))
	var outside = _spawn_stationary_enemy(world, origin + Vector2(251.0, 0.0))
	var dead = _spawn_stationary_enemy(world, origin + Vector2(15.0, 0.0))
	var moved = _spawn_stationary_enemy(world, origin + Vector2(900.0, 0.0))
	dead.dead = true

	world._rebuild_spatial_grid()
	var nearby: Array[Node] = world.get_enemies_near(origin, 250.0)
	_check(nearby.size() == 3, "consulta radial nao preservou a quantidade esperada")
	_check(nearest in nearby and diagonal in nearby and boundary in nearby, "consulta radial perdeu um inimigo valido")
	_check(outside not in nearby, "consulta radial incluiu inimigo fora do raio")
	_check(dead not in nearby, "consulta radial incluiu inimigo morto")
	_check(world.get_nearest_enemy(origin, 250.0) == nearest, "busca do alvo mais proximo mudou")
	_check(world.get_nearest_enemy(origin, 10.0) == null, "limite maximo da busca do alvo nao foi respeitado")

	moved.global_position = origin + Vector2(20.0, 0.0)
	_check(moved not in world.get_enemies_near(origin, 250.0), "indice mudou antes da reconstrucao explicita")
	world._rebuild_spatial_grid()
	_check(moved in world.get_enemies_near(origin, 250.0), "indice nao refletiu movimento apos reconstrucao")
	_check(world.get_nearest_enemy(origin, 250.0) == moved, "alvo mais proximo nao refletiu a reconstrucao")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("WORLD SPATIAL INDEX OK: API, raio, mortos, limites, coordenadas negativas e reconstrucao validados")
	quit(0 if failures.is_empty() else 1)
