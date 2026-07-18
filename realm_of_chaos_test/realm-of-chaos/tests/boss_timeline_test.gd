extends SceneTree

const GameDefs = preload("res://scripts/game_defs.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("BOSS TIMELINE: " + message)


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	var schedule := GameDefs.boss_schedule()
	for index in range(schedule.size()):
		var entry: Dictionary = schedule[index]
		world.time_survived = float(entry.time)
		world._update_boss_schedule()
		var spawned = world.active_boss
		_check(spawned != null, "nenhum chefe surgiu em %d minutos" % int(float(entry.time) / 60.0))
		if not spawned:
			continue
		spawned.set_physics_process(false)
		_check(spawned.enemy_type == str(entry.kind), "chefe incorreto em %d minutos" % int(float(entry.time) / 60.0))
		_check(spawned.boss and spawned.sprite.hframes == 4, "chefe sem animação ou marcador de boss")
		spawned.take_damage(spawned.max_hp * 2.0, Vector2.ZERO, true)
		await process_frame
		if not bool(entry.final):
			_check(not world.game_ended, "mini-chefe encerrou a partida antes do chefe final")

	await process_frame
	_check(world.boss_spawn_log == ["ossuary_colossus", "glacial_archon", "infernal_reaper", "void_titan", "chaos_sovereign"], "ordem dos cinco confrontos está incorreta")
	_check(world.game_ended and paused, "morte do chefe final não concluiu a fase")
	_check(world.hud.end_title.text == "VITÓRIA!", "chefe final não abriu a tela de vitória")
	_check(world.hud.get_node("EndOverlay/Panel/Margin/VBox/Restart").text == "PRÓXIMA FASE", "vitória não oferece a próxima fase")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("BOSS TIMELINE OK: mini-chefes em 5/10/15/20 e chefe final em 25 minutos")
		quit(0)
	else:
		quit(1)
