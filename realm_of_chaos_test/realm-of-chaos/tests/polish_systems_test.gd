extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("POLISH SYSTEMS: " + message)


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)

	var catalog: Array[Dictionary] = world.player.get_upgrade_options(GameDefs.upgrades().size())
	var scythe_option: Dictionary = {}
	for option in catalog:
		_check(option.has("category") and option.has("current_level") and option.has("levels_gained"), "carta sem metadados de build")
		if str(option.id) == "blood_scythe":
			scythe_option = option
	_check(not scythe_option.is_empty() and "SANGUE ANCESTRAL" in str(scythe_option.evolution_hint), "receita da Foice Hemática não aparece na carta")

	var first_roll: Array[Dictionary] = world.player.get_upgrade_options(3)
	var excluded: Array[String] = []
	for option in first_roll:
		excluded.append(str(option.id))
	var second_roll: Array[Dictionary] = world.player.get_upgrade_options(3, excluded)
	for option in second_roll:
		_check(not str(option.id) in excluded, "reroll repetiu carta apesar de haver alternativas")

	for weapon_id in world.player.WEAPON_IDS:
		world.player.weapon_levels[weapon_id] = 0
		world.player.evolved_weapons[weapon_id] = false
	for weapon_id in world.player.WEAPON_IDS.slice(0, world.player.MAX_WEAPONS):
		world.player.weapon_levels[weapon_id] = world.player._upgrade_max(weapon_id)
		world.player.evolved_weapons[weapon_id] = true
	_check(world.player.all_weapons_evolved(), "conquista não reconheceu seis armas evoluídas")
	world.player.evolved_weapons[world.player.WEAPON_IDS[0]] = false
	_check(not world.player.all_weapons_evolved(), "conquista aceitou build parcialmente evoluída")
	world.player.evolved_weapons[world.player.WEAPON_IDS[0]] = true
	_check("\n" in world.player.weapon_summary(), "resumo de seis armas não foi dividido em duas linhas")
	for passive_id in world.player.passive_levels:
		world.player.passive_levels[passive_id] = world.player._upgrade_max(str(passive_id))
	world.player.hp = world.player.max_hp * 0.50
	var essence_before_overflow: int = world.essence_earned
	world._on_level_up_requested()
	await process_frame
	_check(not world.upgrade_active and not world.hud.upgrade_overlay.visible, "build completa abriu seleção vazia")
	_check(world.essence_earned == essence_before_overflow + 2 and world.player.hp > world.player.max_hp * 0.50, "nível excedente não concedeu cura e Essência")

	for index in range(world.MAX_PICKUPS + 17):
		world._spawn_pickup(1, Vector2(index % 30, float(index) / 30.0), "xp")
	_check(world.pickups.get_child_count() == world.MAX_PICKUPS, "cristais excedentes não foram fundidos")
	var stored_xp := 0
	for pickup in world.pickups.get_children():
		stored_xp += int(pickup.value)
	_check(stored_xp == world.MAX_PICKUPS + 17, "fusão de cristais perdeu experiência")

	for _index in range(40):
		var spawn_position: Vector2 = world.get_spawn_position()
		_check(world._spawn_position_is_clear(spawn_position), "diretor escolheu spawn dentro de obstáculo ou santuário")
	_check("05:00" in world._next_boss_status(), "HUD não informa o primeiro chefe")
	world.time_survived = 299.2
	_check("00:01" in world._next_boss_status(), "contagem do chefe não arredonda corretamente")

	world.hud.update_run(20.0, 100.0, 0, 10, 1, 0, 1500.0, "I · NORMAL")
	_check("PERIGO" in world.hud.health_label.text, "HUD não alerta vida baixa")
	world.hud.update_run(80.0, 100.0, 0, 10, 1, 0, 1500.0, "I · NORMAL")
	_check(not "PERIGO" in world.hud.health_label.text, "alerta de vida baixa não foi limpo")

	for _index in range(world.MAX_PLAYER_PROJECTILES + 9):
		world.add_player_projectile(Node2D.new())
	_check(world.projectiles.get_child_count() == world.MAX_PLAYER_PROJECTILES, "limite imediato de projéteis foi ultrapassado")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("POLISH SYSTEMS OK: cartas, conquista, HUD, spawns, cristais e limites validados")
		quit(0)
	else:
		quit(1)
