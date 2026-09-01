extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FOREST NO ROOT HAZARD: " + message)


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	world.suppress_save = true
	world.campaign_map_override_id = "profaned_forest"
	root.add_child(world)
	await process_frame
	world.audio.enabled = false
	world.set_process(false)

	_check(str(world.biome.id) == "forest", "teste não iniciou no Bosque Profanado")
	_check(str(world.encounter_profile.profile_id) == "profaned_forest_no_roots", "Bosque carregou o perfil de encontros incorreto")
	_check(world.hazards.get_child_count() == 0, "container ambiental ainda contém hazards")
	var owned_hazards := 0
	for hazard in get_nodes_in_group("arena_hazards"):
		if is_instance_valid(hazard) and world.is_ancestor_of(hazard):
			owned_hazards += 1
	_check(owned_hazards == 0, "árvore real ainda contém hazards no grupo global")

	var sample_points: Array[Vector2] = [
		world.player.global_position,
		Vector2.ZERO,
		Vector2(1280.0, -920.0),
		Vector2(-1760.0, -1080.0),
		Vector2(1580.0, 1710.0),
		Vector2(-2200.0, 1470.0),
	]
	for sample in sample_points:
		var environment: Dictionary = world.get_environment_effect(sample)
		_check(is_equal_approx(float(environment.get("speed", 0.0)), 1.0), "velocidade residual em %s" % sample)
		_check(is_equal_approx(float(environment.get("traction", 0.0)), 1.0), "tração residual em %s" % sample)
		_check(is_zero_approx(float(environment.get("damage", -1.0))), "dano residual em %s" % sample)
		_check(str(environment.get("name", "residual")).is_empty(), "nome de hazard residual em %s" % sample)

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("FOREST NO ROOT HAZARD OK: sem linhas, nós, slow, tração ou dano residual no Bosque")
		quit(0)
	else:
		quit(1)
