extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


class DropEnemy:
	extends Node2D

	var final_boss := false
	var enemy_type := "prowler"
	var hit_radius := 21.0


func _initialize() -> void:
	var watchdog := create_timer(15.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("MAX BUILD DROPS: teste excedeu 15 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MAX BUILD DROPS: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.4f, obtido %.4f)" % [message, expected, actual])


func _count_pickups(world: Node, kind: String) -> int:
	var count := 0
	for pickup in world.pickups.get_children():
		if is_instance_valid(pickup) and str(pickup.pickup_kind) == kind:
			count += 1
	return count


func _clear_pickups(world: Node) -> void:
	for pickup in world.pickups.get_children():
		pickup.queue_free()
	await process_frame


func _complete_build(player: Node) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
	for index in range(player.MAX_WEAPONS):
		var weapon_id: String = player.WEAPON_IDS[index]
		player.weapon_levels[weapon_id] = player._upgrade_max(weapon_id)
	var passive_index := 0
	for passive_id in player.passive_levels:
		player.passive_levels[passive_id] = (
			player._upgrade_max(str(passive_id))
			if passive_index < player.MAX_PASSIVES
			else 0
		)
		passive_index += 1


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)

	var common_enemy := DropEnemy.new()
	common_enemy.global_position = Vector2(900.0, 0.0)
	var experience_before_drop: int = world.player.experience
	world.handle_enemy_death(common_enemy, 7, false, false, 0.0)
	_check(_count_pickups(world, "xp") == 1, "inimigo deixou de dropar XP antes da build completa")
	_check(world.player.experience == experience_before_drop, "XP foi entregue diretamente antes da build completa")
	await _clear_pickups(world)

	_complete_build(world.player)
	_check(world.player.refresh_build_complete(), "seis armas e seis passivos máximos não concluíram a build")
	_check(world.player.get_upgrade_options(3).is_empty(), "build completa ainda ofereceu upgrade")

	world.player.hp = world.player.max_hp * 0.40
	world.player.experience = world.player.experience_needed - 1
	var level_before_reward: int = world.player.level
	var hp_before_reward: float = world.player.hp
	var essence_before_reward: int = world.essence_earned
	world.handle_enemy_death(common_enemy, 1, false, false, 0.0)
	_check(_count_pickups(world, "xp") == 0, "morte comum criou orb de XP com build completa")
	await process_frame
	_check(world.player.level == level_before_reward + 1, "XP direto não preservou o avanço de nível")
	_check_close(world.player.hp, hp_before_reward + world.player.max_hp * 0.15, "cura pós-build mudou")
	_check(world.essence_earned == essence_before_reward + 2, "recompensa pós-build não concedeu 2 Essências")
	_check(not world.upgrade_active and world.pending_upgrades == 0 and not paused, "recompensa pós-build deixou modal ou pausa ativos")
	await _clear_pickups(world)

	world.player.experience = 0
	world.player.experience_needed = 1_000_000
	seed(44117)
	for index in range(40):
		common_enemy.global_position = Vector2(1000.0 + index * 3.0, 400.0)
		world.handle_enemy_death(common_enemy, 0, true, false)
	_check(_count_pickups(world, "xp") == 0, "elites criaram XP visual com build completa")
	_check(_count_pickups(world, "heal") > 0, "drops de vida de elite foram desativados junto com o XP")
	await _clear_pickups(world)

	_check(world.run_flow.should_spawn_reward_chest(false, 0.999), "baú deixou de ser garantido antes da build completa")
	_check(world.run_flow.should_spawn_reward_chest(true, 0.2999), "chance abaixo de 30% não gerou baú pós-build")
	_check(not world.run_flow.should_spawn_reward_chest(true, 0.30), "limite de 30% foi tratado como inclusivo")
	_check(not world.run_flow.should_spawn_reward_chest(true, 0.95), "chance alta gerou baú pós-build")

	var mini_boss := DropEnemy.new()
	mini_boss.enemy_type = "ossuary_colossus"
	mini_boss.global_position = Vector2(1200.0, 0.0)
	var mini_experience_before: int = world.player.experience
	var mini_damage_before: float = world.player.damage_multiplier
	var mini_max_hp_before: float = world.player.max_hp
	world.handle_enemy_death(mini_boss, 120, false, true)
	_check(_count_pickups(world, "xp") == 0, "mini-boss criou XP visual com build completa")
	_check(world.player.experience == mini_experience_before + 120 + 7 * 12, "XP base ou extra do mini-boss não foi entregue diretamente")
	_check_close(world.player.damage_multiplier, mini_damage_before * 1.045, "recompensa de dano do mini-boss mudou")
	_check_close(world.player.max_hp, mini_max_hp_before + 5.0, "recompensa de vida do mini-boss mudou")

	var final_boss := DropEnemy.new()
	final_boss.final_boss = true
	final_boss.enemy_type = "chaos_sovereign"
	final_boss.global_position = Vector2(1400.0, 0.0)
	var final_experience_before: int = world.player.experience
	var final_damage_before: float = world.player.damage_multiplier
	var final_max_hp_before: float = world.player.max_hp
	world.handle_enemy_death(final_boss, 900, false, true)
	_check(_count_pickups(world, "xp") == 0, "boss final criou XP visual com build completa")
	_check(world.player.experience == final_experience_before + 900 + 10 * 18, "XP base ou extra do boss final não foi entregue diretamente")
	_check_close(world.player.damage_multiplier, final_damage_before * 1.08, "recompensa de dano do boss final mudou")
	_check_close(world.player.max_hp, final_max_hp_before + 12.0, "recompensa de vida do boss final mudou")

	world.game_ended = true
	common_enemy.free()
	mini_boss.free()
	final_boss.free()
	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("MAX BUILD DROPS OK: XP direto, cura/Essência, vida, bosses e baús a 30% validados")
		quit(0)
	else:
		quit(1)
