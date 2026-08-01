extends SceneTree

const BulletScene = preload("res://scenes/bullet.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PROJECTILE BATCH: " + message)


func _spawn_player_projectile(world: Node, weapon: String, radius: float) -> Node:
	var projectile = BulletScene.instantiate()
	projectile.global_position = Vector2(120.0 + world.projectiles.get_child_count() * 40.0, 0.0)
	projectile.setup(Vector2.RIGHT, 0.0, 0.0, 99, radius, Color("a96cff"), false, weapon)
	projectile.lifetime = 5.0
	world.add_player_projectile(projectile)
	return projectile


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true

	var player_renderer = world.player_projectile_batch_renderer
	var enemy_renderer = world.enemy_projectile_batch_renderer
	_check(is_instance_valid(player_renderer), "renderizador do jogador não foi criado")
	_check(is_instance_valid(enemy_renderer), "renderizador inimigo não foi criado")
	_check(player_renderer.get_parent() == world, "renderizador alterou a contagem do container do jogador")
	_check(enemy_renderer.get_parent() == world, "renderizador alterou a contagem do container inimigo")

	_spawn_player_projectile(world, "unknown", 7.0)
	_spawn_player_projectile(world, "shadow_blades", 6.0)
	_spawn_player_projectile(world, "chaos_bolt", 10.0)
	var generic = world.spawn_enemy_projectile(Vector2(-120.0, 0.0), Vector2.LEFT, 0.0, 0.0, Color("62c7ff"), 8.0, false)
	world.spawn_enemy_projectile(Vector2(-180.0, 0.0), Vector2.LEFT, 0.0, 0.0, Color("ff496d"), 8.0, true)
	await process_frame
	await process_frame

	_check(world.projectiles.get_child_count() == 3, "batch alterou o total lógico de projéteis do jogador")
	_check(world.enemy_projectiles.get_child_count() == 2, "batch alterou o total lógico de projéteis inimigos")
	_check(player_renderer._entries.size() == 3, "registro do lote do jogador perdeu projéteis")
	_check(enemy_renderer._entries.size() == 2, "registro do lote inimigo perdeu projéteis")
	if player_renderer.rendering_enabled:
		_check(player_renderer._batches.default.multimesh.visible_instance_count == 1, "sigilo genérico não entrou no lote correto")
		_check(player_renderer._batches.shadow_small.multimesh.visible_instance_count == 1, "Lâminas Sombrias não entrou no lote correto")
		_check(player_renderer._batches.chaos.multimesh.visible_instance_count == 1, "Chaos Bolt não entrou no lote correto")
		_check(enemy_renderer._batches.generic.multimesh.visible_instance_count == 1, "projétil inimigo genérico não entrou no lote correto")
		_check(enemy_renderer._batches.danger.multimesh.visible_instance_count == 1, "estrela de perigo não entrou no lote correto")
		for style in player_renderer._style_order:
			var batch: Dictionary = player_renderer._batches[style]
			_check(batch.instance.material == player_renderer._material, "lote %s não compartilha material" % style)
			_check(batch.multimesh.mesh.get_surface_count() == 1, "lote %s foi dividido em múltiplas superfícies" % style)

	generic.prepare_for_pool()
	world.recycle_enemy_projectile(generic)
	await process_frame
	await process_frame
	if enemy_renderer.rendering_enabled:
		_check(enemy_renderer._batches.generic.multimesh.visible_instance_count == 0, "projétil reciclado continuou desenhado")
	_check(world.enemy_projectiles.get_child_count() == 1, "reciclagem do projétil inimigo mudou")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PROJECTILE BATCH TEST: renderização agrupada preservou contagem, estilos e pooling")
	quit(0 if failures.is_empty() else 1)
