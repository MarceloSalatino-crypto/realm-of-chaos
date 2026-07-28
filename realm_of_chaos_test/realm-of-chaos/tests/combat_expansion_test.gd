extends SceneTree

const GameDefs = preload("res://scripts/game_defs.gd")

const NEW_WEAPONS := [
	"blood_scythe", "forbidden_grimoire", "rune_hammer", "storm_relic", "swarm_idol"
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("COMBAT EXPANSION: " + message)


func _spawn_targets(world: Node, count: int, radius := 125.0) -> Array[Node]:
	var targets: Array[Node] = []
	for index in range(count):
		var enemy = world.spawn_enemy("guardian", false, 4.0)
		enemy.global_position = world.player.global_position + Vector2.RIGHT.rotated(TAU * index / count) * radius
		enemy.set_physics_process(false)
		targets.append(enemy)
	world._rebuild_spatial_grid()
	return targets


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	var upgrade_ids: Array[String] = []
	for definition in GameDefs.upgrades():
		upgrade_ids.append(str(definition.id))
	for weapon_id in NEW_WEAPONS:
		_check(weapon_id in world.player.WEAPON_IDS and weapon_id in upgrade_ids, "arma ausente do catálogo: " + weapon_id)
		_check(not GameDefs.evolution_data(weapon_id).is_empty(), "evolução ausente: " + weapon_id)

	var targets := _spawn_targets(world, 12)
	world.player.weapon_levels.blood_scythe = 3
	world.player._swing_blood_scythe(3)
	_check(float(world.damage_by_source.get("blood_scythe", 0.0)) > 0.0, "Foice Hemática não causou dano")
	world.player.weapon_levels.forbidden_grimoire = 3
	world.player._cast_forbidden_grimoire(3)
	_check(float(world.damage_by_source.get("forbidden_grimoire", 0.0)) > 0.0, "Grimório Proibido não causou dano")
	world.player.weapon_levels.rune_hammer = 3
	world.player._slam_rune_hammer(3)
	_check(float(world.damage_by_source.get("rune_hammer", 0.0)) > 0.0, "Martelo Rúnico não causou dano")
	world.player.weapon_levels.storm_relic = 3
	world.player._cast_storm_chain(3)
	_check(float(world.damage_by_source.get("storm_relic", 0.0)) > 0.0, "Relíquia da Tempestade não encadeou dano")
	world.player.weapon_levels.swarm_idol = 3
	world.player._release_swarm_eyes(3)
	_check(world.projectiles.get_child_count() >= 3, "Ídolo do Enxame não criou olhos perseguidores")

	for weapon_id in NEW_WEAPONS:
		world.player.weapon_levels[weapon_id] = 6
		var evolution := GameDefs.evolution_data(weapon_id)
		world.player.passive_levels[str(evolution.passive)] = 3
	world.player._check_weapon_evolutions()
	for weapon_id in NEW_WEAPONS:
		_check(bool(world.player.evolved_weapons[weapon_id]), "arma não evoluiu: " + weapon_id)

	world.player.character_id = "glacial_oracle"
	world.player._activate_character_skill(world)
	_check(targets[0].slow_time > 0.0, "Pulso Glacial não aplicou controle")
	world.player.character_id = "crimson_knight"
	world.player._activate_character_skill(world)
	_check(world.player.character_guard_time > 0.0, "Contra-ataque Rubro não concedeu guarda")
	world.player.character_id = "void_automaton"
	world.player._activate_character_skill(world)
	_check(float(world.damage_by_source.get("automaton_skill", 0.0)) > 0.0, "Sobrecarga Arcana não atingiu a horda")
	world.player.character_id = "eclipse_hunter"
	var projectile_count: int = world.projectiles.get_child_count()
	world.player._activate_character_skill(world)
	_check(world.projectiles.get_child_count() >= projectile_count + 5, "Rajada do Eclipse não criou cinco projéteis")

	world._on_level_up_requested()
	await process_frame
	_check(world.hud.upgrade_options.size() == 3, "level up não apresentou três cartas")
	_check(
		not world.has_method("_on_reroll_requested")
		and not world.has_method("_on_banish_requested")
		and not world.has_method("_on_skip_requested"),
		"ações removidas ainda estão expostas no World"
	)
	var first_option: Dictionary = world.hud.upgrade_options[0]
	world._on_upgrade_selected(str(first_option.id), str(first_option.rarity))
	_check(not world.upgrade_active and not paused, "escolha da carta não retomou a partida")

	var boss = world._spawn_scheduled_boss(GameDefs.boss_schedule()[0], 0)
	_check(is_instance_valid(world.active_boss_arena) and world.active_boss_arena.active, "mini-chefe não criou arena própria")
	boss.hp = boss.max_hp * 0.30
	boss._update_boss_phase()
	_check(world.active_boss_arena.phase == 3, "arena não acompanhou a fase do chefe")
	boss.take_damage(boss.max_hp * 2.0, Vector2.ZERO, true)
	await process_frame
	_check(world.active_boss == null, "morte do mini-chefe não encerrou a arena")

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT EXPANSION OK: cinco armas, evoluções, habilidades, escolhas e arenas validadas")
		quit(0)
	else:
		quit(1)
