extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")


class SurgicalCriticalEffect extends Node2D:
	var mechanically_complete := false
	var stage_delay := 0.25
	var age := 0.0
	var stage_tracker: Array = []


	func setup(complete: bool, tracker: Array = []) -> void:
		mechanically_complete = complete
		stage_tracker = tracker
		set_meta("combat_critical_visual", true)


	func has_pending_combat_stages() -> bool:
		return not mechanically_complete


	func _process(delta: float) -> void:
		age += delta
		if mechanically_complete or age < stage_delay:
			return
		mechanically_complete = true
		if not stage_tracker.is_empty():
			stage_tracker[0] = true


var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("CRITICAL EFFECT OVERFLOW: teste excedeu 20 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CRITICAL EFFECT OVERFLOW: " + message)


func _clear_effects(world: Node) -> void:
	for effect in world.effects.get_children():
		effect.queue_free()
	await process_frame


func _add_critical_effect(world: Node, complete: bool, tracker: Array = []) -> Node:
	var effect := SurgicalCriticalEffect.new()
	effect.setup(complete, tracker)
	world.effects.add_child(effect)
	return effect


func _fill_critical_effects(world: Node, complete: bool) -> Array[Node]:
	var effects: Array[Node] = []
	for _index in range(world.MAX_EFFECTS):
		effects.append(_add_critical_effect(world, complete))
	return effects


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_process(false)
	world.player.set_physics_process(false)

	# Cenário A/C: o crítico mais antigo ainda tem uma etapa futura, enquanto
	# os demais críticos já terminaram sua parte mecânica e são substituíveis.
	var pending_stage := [false]
	var pending_oldest := _add_critical_effect(world, false, pending_stage)
	for _index in range(world.MAX_EFFECTS - 1):
		_add_critical_effect(world, true)
	var replacement = world.spawn_crimson_reaper_slash(Vector2.ZERO, 0.0, 120.0)
	_check(is_instance_valid(replacement), "novo efeito crítico não ocupou a vaga de um crítico concluído")
	_check(
		is_instance_valid(pending_oldest) and pending_oldest.get_parent() == world.effects,
		"efeito crítico com estágio pendente foi removido antes de um crítico mecanicamente concluído"
	)
	if is_instance_valid(pending_oldest) and pending_oldest.get_parent() == world.effects:
		pending_oldest._process(0.30)
	_check(bool(pending_stage[0]), "estágio mecânico futuro foi cancelado pela saturação visual")

	# Cenário B: efeitos não críticos continuam sendo a primeira opção de descarte.
	await _clear_effects(world)
	var cosmetic := Node2D.new()
	cosmetic.set_meta("combat_critical_visual", false)
	world.effects.add_child(cosmetic)
	var protected_pending: Array[Node] = []
	for _index in range(world.MAX_EFFECTS - 1):
		protected_pending.append(_add_critical_effect(world, false))
	replacement = world.spawn_crimson_reaper_slash(Vector2.ZERO, 0.0, 120.0)
	_check(is_instance_valid(replacement), "novo crítico foi bloqueado apesar de haver cosmético descartável")
	_check(cosmetic.get_parent() == null, "efeito não crítico não foi descartado primeiro")
	for effect in protected_pending:
		_check(effect.get_parent() == world.effects, "crítico pendente foi removido enquanto havia cosmético")

	# Caso-limite: se todos os 120 críticos ainda forem indispensáveis, nenhum
	# deles pode ser cancelado. Quando um conclui, uma nova tentativa deve entrar.
	await _clear_effects(world)
	var all_pending := _fill_critical_effects(world, false)
	replacement = world.spawn_crimson_reaper_slash(Vector2.ZERO, 0.0, 120.0)
	_check(replacement == null, "novo crítico substituiu outro enquanto todos tinham mecânica pendente")
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "teto de 120 efeitos foi alterado")
	for effect in all_pending:
		_check(effect.get_parent() == world.effects, "crítico indispensável foi removido no limite extremo")
	all_pending[0].mechanically_complete = true
	replacement = world.spawn_crimson_reaper_slash(Vector2.ZERO, 0.0, 120.0)
	_check(is_instance_valid(replacement), "efeitos críticos continuaram bloqueados após surgir vaga substituível")
	_check(all_pending[0].get_parent() == null, "crítico já concluído não foi escolhido após ficar substituível")
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "substituição ultrapassou o teto de 120")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("CRITICAL EFFECT OVERFLOW OK: cosmético, crítico concluído e 120 críticos pendentes preservados")
		quit(0)
	else:
		quit(1)
