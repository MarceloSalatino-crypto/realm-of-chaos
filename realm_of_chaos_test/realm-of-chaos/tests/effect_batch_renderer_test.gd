extends SceneTree

const EffectScript = preload("res://scripts/effect.gd")
const QUALITY_COLORS := [Color("79ddff"), Color("be72ff"), Color("ff5f68")]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("EFFECT BATCH: " + message)


func _spawn_effect(world: Node, quality: int, filled: bool) -> Node:
	var effect = EffectScript.new()
	world.effects.add_child(effect)
	effect.setup(Vector2(quality * 80.0, 40.0 if filled else -40.0), QUALITY_COLORS[quality], 64.0, 3.0, filled, quality)
	return effect


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true
	var renderer = world.effect_batch_renderer
	_check(is_instance_valid(renderer), "renderizador não foi criado")
	_check(renderer.get_parent() == world, "renderizador alterou a contagem do container")
	for quality in range(3):
		_spawn_effect(world, quality, false)
		_spawn_effect(world, quality, true)
	await process_frame
	await process_frame
	_check(world.effects.get_child_count() == 6, "batch alterou o total lógico de efeitos")
	_check(renderer._entries.size() == 6, "registro perdeu efeitos")
	var filled_by_quality := {0: 0, 1: 0, 2: 0}
	for entry in renderer._entries:
		_check(int(entry.quality) in [0, 1, 2], "qualidade saiu da faixa")
		if bool(entry.filled):
			filled_by_quality[int(entry.quality)] += 1
	for quality in range(3):
		_check(filled_by_quality[quality] == 1, "preenchimento da qualidade %d não foi preservado" % quality)
	if renderer.rendering_enabled:
		_check(not renderer._vertices.is_empty(), "efeitos não foram consolidados no lote")
		_check(renderer._indices.size() % 3 == 0, "lote não contém triângulos completos")
	if renderer.rendering_enabled:
		var quality_zero_visible := false
		for vertex_color in renderer._colors:
			if vertex_color.g > 0.72 and vertex_color.b > 0.90 and vertex_color.r < 0.62:
				quality_zero_visible = true
				break
		_check(quality_zero_visible, "qualidade visual minima desapareceu no lote misto")
	var removed = world.effects.get_child(0)
	removed.queue_free()
	await process_frame
	await process_frame
	_check(renderer._entries.size() == 5, "efeito removido permaneceu registrado")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("EFFECT BATCH TEST: qualidades, preenchimento, contagem e remoção preservados")
	quit(0 if failures.is_empty() else 1)
