extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SMOKE TEST: " + message)


func _run() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	await process_frame

	_check(is_instance_valid(world.player), "player não foi instanciado")
	_check(world.decorations.get_child_count() == 310, "mundo procedural incompleto")
	_check(world.hud != null, "HUD não foi instanciado")

	for kind in ["prowler", "bat", "mage", "brute", "ember", "void_knight"]:
		var enemy = world.spawn_enemy(kind)
		_check(enemy != null, "falha ao criar inimigo: " + kind)
		if enemy:
			enemy.global_position = world.player.global_position + Vector2(280, 0)
	await process_frame
	_check(world.enemies.get_child_count() >= 6, "diretor não manteve o bestiário ativo")

	var target = world.spawn_enemy("prowler")
	target.global_position = world.player.global_position + Vector2(90, 0)
	world.player._fire_chaos_bolt()
	await process_frame
	_check(world.projectiles.get_child_count() > 0, "arma principal não criou projétil")

	var kills_before: int = world.enemies_killed
	target.take_damage(99999.0)
	await process_frame
	_check(world.enemies_killed == kills_before + 1, "morte não incrementou contador")
	_check(world.pickups.get_child_count() > 0, "morte não gerou cristal de experiência")

	var old_damage: float = world.player.damage_multiplier
	world.player.apply_upgrade("might", "COMUM")
	_check(world.player.damage_multiplier > old_damage, "upgrade passivo não foi aplicado")
	world.player.apply_upgrade("soul_orbit", "RARO")
	_check(world.player.weapon_levels.soul_orbit > 0, "arma desbloqueável não foi aplicada")
	_check(world.player.get_upgrade_options(3).size() == 3, "seleção de upgrades incompleta")
	world._on_level_up_requested()
	await process_frame
	_check(world.upgrade_active and world.hud.upgrade_overlay.visible, "fluxo visual de level-up não abriu")
	world._on_upgrade_selected("magnet", "COMUM")
	_check(not paused and not world.hud.upgrade_overlay.visible, "fluxo de level-up não retomou a partida")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("SMOKE TEST OK: mundo, 6 inimigos, combate, drops e upgrades validados")
		quit(0)
	else:
		print("SMOKE TEST FALHOU: %d problema(s)" % failures.size())
		quit(1)
