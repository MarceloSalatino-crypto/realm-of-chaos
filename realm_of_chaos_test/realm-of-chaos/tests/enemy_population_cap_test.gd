extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ENEMY POPULATION CAP: " + message)


func _clear_enemy_state(world: Node) -> void:
	for child in world.enemies.get_children():
		world.enemies.remove_child(child)
		child.free()
	if is_instance_valid(world.active_boss_arena):
		var arena: Node = world.active_boss_arena
		if arena.get_parent():
			arena.get_parent().remove_child(arena)
		arena.free()
	world.active_boss = null
	world.active_boss_arena = null
	world.director_spawn_queue.clear()
	world.boss_index = 0
	world.boss_spawn_log.clear()
	world.final_boss_spawned = false
	world._rebuild_spatial_grid()


func _fill_with_dummies(world: Node, target: int) -> void:
	while world.enemies.get_child_count() < target:
		world.enemies.add_child(Node2D.new())


func _remove_dummy(world: Node) -> void:
	for child in world.enemies.get_children():
		if not child.has_method("take_damage"):
			world.enemies.remove_child(child)
			child.free()
			return


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true

	# Spawn comum: ocupa a ultima vaga, bloqueia a seguinte e preserva o timer.
	world.time_survived = 0.0
	var cap: int = world.enemy_population_cap()
	_check(cap == 60, "teto inicial Normal deveria ser 60")
	_fill_with_dummies(world, cap - 1)
	_check(world.remaining_enemy_capacity() == 1 and world.has_enemy_capacity(), "consulta de capacidade restante incorreta")
	_check(world.spawn_enemy("prowler", false, 1.0) != null, "spawn comum nao ocupou a ultima vaga")
	_check(world.enemies.get_child_count() == cap, "spawn comum nao terminou exatamente no teto")
	_check(world.spawn_enemy("prowler", false, 1.0) == null, "spawn comum ultrapassou o teto global")
	world.spawn_timer = 0.0
	var normal_interval := float(GameDefs.difficulty_data(world.time_survived).interval)
	world._spawn_timer_update(0.0)
	_check(is_equal_approx(world.spawn_timer, normal_interval), "tentativa comum bloqueada alterou o timer")
	_check(world.enemies.get_child_count() == cap, "timer comum ultrapassou o teto")

	# Elites ja enfileiradas entram uma por vaga, sem serem descartadas.
	_clear_enemy_state(world)
	world.time_survived = 300.0
	cap = world.enemy_population_cap()
	_fill_with_dummies(world, cap - 1)
	world.director_spawn_queue.append({"type": "elite", "kind": "guardian", "elite": true})
	world.director_spawn_queue.append({"type": "elite", "kind": "assassin", "elite": true})
	world._process_director_spawn_queue()
	_check(world.enemies.get_child_count() == cap, "primeira elite nao ocupou a vaga disponivel")
	_check(world.director_spawn_queue.size() == 1, "fila de elites nao consumiu somente o job criado")
	world._process_director_spawn_queue()
	_check(world.director_spawn_queue.size() == 1 and world.enemies.get_child_count() == cap, "elite sem vaga foi descartada ou ultrapassou o teto")
	_remove_dummy(world)
	world._process_director_spawn_queue()
	_check(world.director_spawn_queue.is_empty() and world.enemies.get_child_count() == cap, "elite pendente nao entrou quando surgiu vaga")

	# Evento cria somente o numero que cabe.
	_clear_enemy_state(world)
	world.time_survived = 600.0
	cap = world.enemy_population_cap()
	_fill_with_dummies(world, cap - 3)
	world._trigger_world_event("blood_moon")
	_check(world.enemies.get_child_count() == cap, "evento nao limitou seu burst as tres vagas disponiveis")
	world._end_world_event()

	# Invocacao do necromante tambem para exatamente no teto.
	_clear_enemy_state(world)
	world.time_survived = 600.0
	cap = world.enemy_population_cap()
	var caster = world.spawn_enemy("necromancer", false, 1.0)
	_fill_with_dummies(world, cap - 2)
	caster._summon_minions(5)
	_check(world.enemies.get_child_count() == cap, "invocacao nao criou somente os dois lacaios que cabiam")

	# Boss nunca e perdido: permanece pendente e ganha prioridade no proximo frame com vaga.
	_clear_enemy_state(world)
	world.time_survived = 300.0
	cap = world.enemy_population_cap()
	_fill_with_dummies(world, cap)
	world.set_process(true)
	world._update_boss_schedule()
	world.set_process(false)
	_check(world.director_spawn_queue.size() == 1 and world.boss_index == 0, "boss devido nao entrou na fila")
	for _attempt in range(3):
		world._process_director_spawn_queue()
	_check(world.director_spawn_queue.size() == 1, "boss sem vaga foi descartado ou duplicado")
	_check(world.boss_index == 0 and not is_instance_valid(world.active_boss), "boss_index avancou sem criar o boss")
	_remove_dummy(world)
	world._process_director_spawn_queue()
	_check(world.director_spawn_queue.is_empty(), "job de boss permaneceu depois da criacao")
	_check(world.boss_index == 1 and is_instance_valid(world.active_boss), "boss pendente nao foi criado quando surgiu vaga")
	_check(world.enemies.get_child_count() == cap, "boss pendente ultrapassou o teto global")

	# Varias fontes no mesmo frame disputam a mesma ultima vaga sem corrida ou excesso.
	_clear_enemy_state(world)
	world.time_survived = 600.0
	cap = world.enemy_population_cap()
	caster = world.spawn_enemy("necromancer", false, 1.0)
	_fill_with_dummies(world, cap - 1)
	_check(world.spawn_enemy("prowler", false, 1.0) != null, "fonte comum nao ocupou a ultima vaga")
	caster._summon_minions(4)
	world._trigger_world_event("blood_moon")
	world.director_spawn_queue.append({"type": "elite", "kind": "guardian", "elite": true})
	world._process_director_spawn_queue()
	_check(world.enemies.get_child_count() == cap, "fontes simultaneas ultrapassaram o teto global")
	_check(world.director_spawn_queue.size() == 1, "elite simultanea nao permaneceu pendente no teto")
	world._end_world_event()

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY POPULATION CAP OK: comum, elites, evento, invocacao, boss pendente e fontes simultaneas validados")
		quit(0)
	else:
		quit(1)
