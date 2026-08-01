extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PICKUP BATCH: " + message)


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true

	var renderer = world.pickup_batch_renderer
	_check(is_instance_valid(renderer), "renderizador não foi criado")
	_check(renderer.get_parent() == world, "renderizador alterou a contagem do container")
	var common = world._spawn_pickup(1, Vector2(180.0, 0.0), "xp")
	var high = world._spawn_pickup(12, Vector2(240.0, 0.0), "xp")
	var heal = world._spawn_pickup(24, Vector2(300.0, 0.0), "heal")
	for pickup in [common, high, heal]:
		pickup._on_screen_entered()
	await process_frame
	await process_frame

	_check(world.pickups.get_child_count() == 3, "batch alterou o total lógico de pickups")
	_check(renderer._entries.size() == 3, "registro perdeu pickups")
	_check(renderer._entries_by_id[common.get_instance_id()].style == "xp_common", "XP comum entrou no lote incorreto")
	_check(renderer._entries_by_id[high.get_instance_id()].style == "xp_high", "XP alto entrou no lote incorreto")
	_check(renderer._entries_by_id[heal.get_instance_id()].style == "heal", "cura entrou no lote incorreto")
	_check(is_zero_approx(heal.rotation), "cura deixou de permanecer vertical")

	if renderer.rendering_enabled:
		_check(renderer._batches.xp_common.multimesh.visible_instance_count == 1, "XP comum não foi desenhado")
		_check(renderer._batches.xp_high.multimesh.visible_instance_count == 1, "XP alto não foi desenhado")
		_check(renderer._batches.heal.multimesh.visible_instance_count == 1, "cura não foi desenhada")
		for style in renderer._style_order:
			var batch: Dictionary = renderer._batches[style]
			_check(batch.multimesh.mesh.get_surface_count() == 1, "lote %s possui múltiplas superfícies" % style)

	common.value = 8
	common.request_visual_refresh()
	await process_frame
	_check(renderer._entries_by_id[common.get_instance_id()].style == "xp_high", "fusão não trocou XP verde para dourado")
	if renderer.rendering_enabled:
		_check(renderer._batches.xp_common.multimesh.visible_instance_count == 0, "XP fundido permaneceu no lote verde")
		_check(renderer._batches.xp_high.multimesh.visible_instance_count == 2, "XP fundido não entrou no lote dourado")

	high._on_screen_exited()
	await process_frame
	if renderer.rendering_enabled:
		_check(renderer._batches.xp_high.multimesh.visible_instance_count == 1, "pickup fora da câmera continuou desenhado")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PICKUP BATCH TEST: estilos, fusão, visibilidade e contagem preservados")
	quit(0 if failures.is_empty() else 1)
