extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const ABYSSAL_BALLISTA_SCRIPT = preload("res://scripts/abyssal_ballista_volley.gd")
const SHADOW_DANCE_SCRIPT = preload("res://scripts/shadow_dance_sequence.gd")
const SPIRIT_DEVOURER_SCRIPT = preload("res://scripts/spirit_devourer_release.gd")
const VOID_COLLAPSE_SCRIPT = preload("res://scripts/void_collapse.gd")
const CRIMSON_REAPER_SCRIPT = preload("res://scripts/crimson_reaper_slash.gd")
const CODEX_RITUAL_SCRIPT = preload("res://scripts/codex_ritual.gd")
const CATACLYSM_RUPTURE_SCRIPT = preload("res://scripts/cataclysm_rupture.gd")
const ETERNAL_STORM_SCRIPT = preload("res://scripts/eternal_storm.gd")
const LEGION_FOCUS_SCRIPT = preload("res://scripts/legion_focus.gd")

const EVOLUTION_SCRIPTS := [
	ABYSSAL_BALLISTA_SCRIPT,
	SHADOW_DANCE_SCRIPT,
	SPIRIT_DEVOURER_SCRIPT,
	VOID_COLLAPSE_SCRIPT,
	CRIMSON_REAPER_SCRIPT,
	CODEX_RITUAL_SCRIPT,
	CATACLYSM_RUPTURE_SCRIPT,
	ETERNAL_STORM_SCRIPT,
	LEGION_FOCUS_SCRIPT,
]

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(25.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("EVOLUTION INTEGRATION: teste excedeu 25 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("EVOLUTION INTEGRATION: " + message)


func _spawn_target(world, position: Vector2, kind := "prowler", elite := false) -> Node:
	var enemy = world.spawn_enemy(kind, elite, 1.0)
	_check(is_instance_valid(enemy), "não foi possível criar alvo %s" % kind)
	if not is_instance_valid(enemy):
		return null
	enemy.global_position = position
	enemy.hp = 10_000_000.0
	enemy.max_hp = enemy.hp
	enemy.velocity = Vector2.ZERO
	enemy.knockback_velocity = Vector2.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)
	return enemy


func _prepare_all_evolutions(player) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 6
		player.evolved_weapons[weapon_id] = true
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.projectile_bonus = 0
	player.combat.legion_cast_count = 2
	player.combat.soul_essence_charges = player.combat.SOUL_DEVOURER_CHARGE_LIMIT
	player.combat.soul_essence_damage = 180.0


func _fill_near_global_caps(world) -> void:
	for index in range(world.MAX_EFFECTS - EVOLUTION_SCRIPTS.size()):
		var cosmetic := Node2D.new()
		cosmetic.name = "IntegrationCosmetic%d" % index
		cosmetic.set_meta("combat_critical_visual", false)
		world.effects.add_child(cosmetic)
	for index in range(world.MAX_PLAYER_PROJECTILES - 30):
		var projectile_placeholder := Node2D.new()
		projectile_placeholder.name = "IntegrationProjectile%d" % index
		world.projectiles.add_child(projectile_placeholder)


func _critical_effects_by_script(world) -> Dictionary:
	var result := {}
	for effect in world.effects.get_children():
		if not is_instance_valid(effect) or not bool(effect.get_meta("combat_critical_visual", false)):
			continue
		result[effect.get_script()] = effect
	return result


func _drive_critical_effect(effect: Node) -> void:
	match effect.get_script():
		ABYSSAL_BALLISTA_SCRIPT:
			effect._process(0.21)
		SHADOW_DANCE_SCRIPT:
			effect._process(0.28)
		VOID_COLLAPSE_SCRIPT:
			effect._process(0.69)
		CODEX_RITUAL_SCRIPT:
			effect._process(0.85)
		CATACLYSM_RUPTURE_SCRIPT:
			effect._process(0.31)
		ETERNAL_STORM_SCRIPT:
			effect._process(0.17)
		LEGION_FOCUS_SCRIPT:
			effect._process(0.51)
		_:
			effect._process(0.10)


func _verify_stage_counts(effects_by_script: Dictionary) -> void:
	var ballista: Node = effects_by_script.get(ABYSSAL_BALLISTA_SCRIPT)
	var dance: Node = effects_by_script.get(SHADOW_DANCE_SCRIPT)
	var collapse: Node = effects_by_script.get(VOID_COLLAPSE_SCRIPT)
	var codex: Node = effects_by_script.get(CODEX_RITUAL_SCRIPT)
	var cataclysm: Node = effects_by_script.get(CATACLYSM_RUPTURE_SCRIPT)
	var storm: Node = effects_by_script.get(ETERNAL_STORM_SCRIPT)
	var legion: Node = effects_by_script.get(LEGION_FOCUS_SCRIPT)
	if is_instance_valid(ballista):
		_check(int(ballista.visual_signature().released_projectile_count) > 0, "Balista não liberou a salva")
	if is_instance_valid(dance):
		_check(int(dance.visual_signature().released_projectile_count) == 16, "Dança não concluiu ida e retorno")
	if is_instance_valid(collapse):
		_check(int(collapse.visual_signature().damage_stage_count) == 1, "Colapso não concluiu a implosão")
	if is_instance_valid(codex):
		_check(int(codex.visual_signature().damage_stage_count) == 3, "Códice não concluiu dois pulsos e implosão")
	if is_instance_valid(cataclysm):
		_check(int(cataclysm.visual_signature().rupture_stage_count) == 3, "Cataclismo não concluiu as três fissuras")
	if is_instance_valid(storm):
		_check(int(storm.visual_signature().echo_stage_count) == 1, "Tempestade não concluiu o eco")
	if is_instance_valid(legion):
		_check(int(legion.visual_signature().attack_stage_count) == 2, "Legião não concluiu as duas salvas")


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
	world.player.global_position = Vector2.ZERO
	_prepare_all_evolutions(world.player)

	var first_target: Node = null
	for index in range(50):
		var angle := TAU * float(index) / 50.0
		var radius := 120.0 + float(index % 8) * 42.0
		var target = _spawn_target(world, Vector2.RIGHT.rotated(angle) * radius)
		if first_target == null:
			first_target = target
	_spawn_target(world, Vector2(330.0, 40.0), "guardian", true)
	_spawn_target(world, Vector2(520.0, -30.0), "ossuary_colossus")
	world._rebuild_spatial_grid()
	_fill_near_global_caps(world)

	var hp_before := float(first_target.hp)
	world.player._fire_chaos_bolt()
	world.player._fire_shadow_blades(6)
	_check(world.player.combat.release_soul_essence(220.0), "Devorador não liberou a essência carregada")
	world.player._cast_nova(6)
	world.player._swing_blood_scythe(6)
	world.player._cast_forbidden_grimoire(6)
	world.player._slam_rune_hammer(6)
	world.player._cast_storm_chain(6)
	world.player._release_swarm_eyes(6)

	var effects_by_script := _critical_effects_by_script(world)
	for expected_script in EVOLUTION_SCRIPTS:
		_check(effects_by_script.has(expected_script), "visual crítico ausente para %s" % expected_script.resource_path)
	_check(world.effects.get_child_count() <= world.MAX_EFFECTS, "combinação ultrapassou 120 efeitos")
	_check(world.projectiles.get_child_count() <= world.MAX_PLAYER_PROJECTILES, "combinação ultrapassou 360 projéteis antes das sequências")

	for effect in effects_by_script.values():
		effect.set_process(false)
		_drive_critical_effect(effect)
	_verify_stage_counts(effects_by_script)
	_check(world.effects.get_child_count() <= world.MAX_EFFECTS, "sequências ultrapassaram 120 efeitos")
	_check(world.projectiles.get_child_count() <= world.MAX_PLAYER_PROJECTILES, "sequências ultrapassaram 360 projéteis")
	_check(float(first_target.hp) < hp_before, "nenhuma evolução aplicou dano à horda")
	_check(world.player.combat.soul_essence_charges == 0, "essência não foi consumida após a descarga")
	_check(world.player.combat.soul_devourer_release_count == 1, "descarga de essência duplicou")
	_check(world.player.combat.legion_cast_count == 3, "contador da Legião avançou mais de uma vez")
	for timer_name in ["bolt_timer", "blades_timer", "nova_timer", "scythe_timer", "grimoire_timer", "hammer_timer", "storm_timer", "swarm_timer"]:
		_check(float(world.player.get(timer_name)) > 0.0, "cooldown inválido após combinação: %s" % timer_name)

	for effect in effects_by_script.values():
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			effect._process(2.0)
	await process_frame
	for effect in world.effects.get_children():
		_check(not bool(effect.get_meta("combat_critical_visual", false)), "efeito crítico sobreviveu além da própria duração")
	world.player.combat.reset_soul_devourer_state()
	_check(world.player.combat.soul_devourer_signature().release_count == 0, "estado do Devorador não reiniciou")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("EVOLUTION INTEGRATION OK: 9 evoluções simultâneas, horda+elite+boss, 120 efeitos, 360 projéteis e limpeza validados")
		quit(0)
	else:
		quit(1)
