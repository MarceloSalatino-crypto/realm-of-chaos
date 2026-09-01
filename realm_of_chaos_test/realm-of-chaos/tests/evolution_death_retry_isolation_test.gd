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

const ALL_EVOLUTION_SCRIPTS := [
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
	var watchdog := create_timer(30.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("EVOLUTION DEATH/RETRY: teste excedeu 30 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("EVOLUTION DEATH/RETRY: " + message)


func _spawn_target(world: Node, position: Vector2, kind := "prowler", elite := false) -> Node:
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


func _prepare_all_evolutions(player: Node) -> void:
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


func _effects_by_script(world: Node) -> Dictionary:
	var result := {}
	for effect in world.effects.get_children():
		if is_instance_valid(effect) and not effect.is_queued_for_deletion():
			result[effect.get_script()] = weakref(effect)
	return result



func _effect_ref(effects: Dictionary, script: Script) -> Node:
	var reference: WeakRef = effects.get(script) as WeakRef
	return reference.get_ref() if reference else null


func _record_exit_signature(effect: Node, storage: Dictionary) -> void:
	storage[effect.get_script()] = effect.visual_signature().duplicate(true)


func _signature(effects: Dictionary, exit_signatures: Dictionary, script: Script) -> Dictionary:
	var effect := _effect_ref(effects, script)
	if is_instance_valid(effect):
		return effect.visual_signature()
	return exit_signatures.get(script, {})


func _stage_snapshot(effects: Dictionary, exit_signatures: Dictionary) -> Dictionary:
	var ballista := _signature(effects, exit_signatures, ABYSSAL_BALLISTA_SCRIPT)
	var dance := _signature(effects, exit_signatures, SHADOW_DANCE_SCRIPT)
	var collapse := _signature(effects, exit_signatures, VOID_COLLAPSE_SCRIPT)
	var codex := _signature(effects, exit_signatures, CODEX_RITUAL_SCRIPT)
	var cataclysm := _signature(effects, exit_signatures, CATACLYSM_RUPTURE_SCRIPT)
	var storm := _signature(effects, exit_signatures, ETERNAL_STORM_SCRIPT)
	var legion := _signature(effects, exit_signatures, LEGION_FOCUS_SCRIPT)
	return {
		"ballista_projectiles": int(ballista.get("released_projectile_count", -1)),
		"dance_projectiles": int(dance.get("released_projectile_count", -1)),
		"void_pulls": int(collapse.get("pull_stage_count", -1)),
		"void_damage": int(collapse.get("damage_stage_count", -1)),
		"codex_damage": int(codex.get("damage_stage_count", -1)),
		"cataclysm_ruptures": int(cataclysm.get("rupture_stage_count", -1)),
		"storm_echo": int(storm.get("echo_stage_count", -1)),
		"legion_waves": int(legion.get("attack_stage_count", -1)),
	}


func _all_false(values: Dictionary) -> bool:
	for value in values.values():
		if bool(value):
			return false
	return true


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO
	_prepare_all_evolutions(world.player)

	for index in range(50):
		var angle := TAU * float(index) / 50.0
		var radius := 110.0 + float(index % 8) * 45.0
		_spawn_target(world, Vector2.RIGHT.rotated(angle) * radius)
	_spawn_target(world, Vector2(330.0, 30.0), "guardian", true)
	_spawn_target(world, Vector2(520.0, -25.0), "ossuary_colossus")
	world._rebuild_spatial_grid()

	world.player._fire_chaos_bolt()
	world.player._fire_shadow_blades(6)
	_check(world.player.combat.release_soul_essence(220.0), "Devorador não iniciou a descarga")
	world.player._cast_nova(6)
	world.player._swing_blood_scythe(6)
	world.player._cast_forbidden_grimoire(6)
	world.player._slam_rune_hammer(6)
	world.player._cast_storm_chain(6)
	world.player._release_swarm_eyes(6)

	var effects := _effects_by_script(world)
	var exit_signatures := {}
	for expected_script in ALL_EVOLUTION_SCRIPTS:
		_check(effects.has(expected_script), "evolução atrasada/visual ausente: %s" % expected_script.resource_path)
	_check(world.effects.get_child_count() >= ALL_EVOLUTION_SCRIPTS.size(), "integração não manteve efeitos ativos")
	_check(world.projectiles.get_child_count() > 0, "integração não manteve projéteis ativos")
	_check(not world.player_projectile_batch_renderer._entries.is_empty(), "integração não registrou o batch ativo")
	_check(_effect_ref(effects, ABYSSAL_BALLISTA_SCRIPT).owner_ref != null, "Balista não manteve WeakRef para o Player")
	_check(_effect_ref(effects, SHADOW_DANCE_SCRIPT).owner_ref != null, "Dança não manteve WeakRef para o Player")
	_check(_effect_ref(effects, LEGION_FOCUS_SCRIPT).owner_ref != null, "Legião não manteve WeakRef para o Player")
	for expected_script in ALL_EVOLUTION_SCRIPTS:
		var evolution_effect := _effect_ref(effects, expected_script)
		if is_instance_valid(evolution_effect):
			evolution_effect.tree_exiting.connect(
				_record_exit_signature.bind(evolution_effect, exit_signatures), CONNECT_ONE_SHOT
			)

	var old_world_ref: WeakRef = weakref(world)
	var old_player_ref: WeakRef = weakref(world.player)
	var old_effect_refs: Array = []
	for effect in world.effects.get_children():
		old_effect_refs.append(weakref(effect))
	var old_projectile_refs: Array = []
	for projectile in world.projectiles.get_children():
		projectile.set_physics_process(false)
		old_projectile_refs.append(weakref(projectile))

	world.player.visual_controller.play_death_animation()
	_check(world.player.death_started and world.player.disabled, "morte não entrou no estado visual/funcional esperado")
	for _frame in range(90):
		await process_frame
		if world.game_ended:
			break
	_check(world.game_ended, "end_run não ocorreu ao terminar a animação de morte")
	_check(paused, "end_run não pausou a árvore")

	var paused_snapshot := _stage_snapshot(effects, exit_signatures)
	print("EVOLUTION DEATH SNAPSHOT: %s" % paused_snapshot)
	_check(
		int(paused_snapshot.ballista_projectiles) == int(_signature(effects, exit_signatures, ABYSSAL_BALLISTA_SCRIPT).entry_count),
		"Balista não concluiu a salva antes de end_run"
	)
	_check(int(paused_snapshot.dance_projectiles) == 16, "Dança não concluiu as quatro ondas antes de end_run")
	_check(int(paused_snapshot.cataclysm_ruptures) == 3, "Cataclismo não concluiu as fissuras antes de end_run")
	_check(int(paused_snapshot.storm_echo) == 1, "Tempestade não concluiu o eco antes de end_run")
	_check(int(paused_snapshot.void_damage) == 0, "Colapso implodiu depois do limite temporal da morte")
	_check(int(paused_snapshot.void_pulls) in [2, 3], "Colapso não preservou os pulls anteriores/limítrofes ao end_run")
	_check(int(paused_snapshot.codex_damage) in [1, 2], "Códice executou quantidade impossível antes do end_run")
	_check(int(paused_snapshot.legion_waves) in [1, 2], "Legião executou quantidade impossível antes do end_run")

	for _frame in range(12):
		await process_frame
	_check(_stage_snapshot(effects, exit_signatures) == paused_snapshot, "estágios continuaram executando com a árvore pausada")

	world.run_flow.restart_run()
	for _frame in range(90):
		await process_frame
		if is_instance_valid(current_scene) and current_scene != world:
			break
	var new_world = current_scene
	_check(is_instance_valid(new_world), "retry não criou um novo World")
	_check(new_world != old_world_ref.get_ref(), "retry reutilizou o World antigo")
	if is_instance_valid(new_world):
		new_world.suppress_save = true
		new_world.audio.enabled = false
		new_world.set_process(false)
		new_world.set_physics_process(false)
		new_world.player.set_process(false)
		new_world.player.set_physics_process(false)
		_check(old_world_ref.get_ref() == null, "World antigo sobreviveu ao retry")
		_check(old_player_ref.get_ref() == null, "Player antigo sobreviveu ao retry")
		_check(_all_false(new_world.player.evolved_weapons), "novo Player herdou evoluções antigas")
		_check(new_world.player.combat.soul_essence_charges == 0, "novo Player herdou cargas do Devorador")
		_check(new_world.player.combat.soul_essence_damage == 0.0, "novo Player herdou dano reservado do Devorador")
		_check(new_world.player.combat.soul_devourer_release_count == 0, "novo Player herdou contagem de descarga")
		_check(new_world.player.combat.legion_cast_count == 0, "novo Player herdou contador da Legião")
		_check(new_world.player.orbit_hit_times.is_empty(), "novo Player herdou histórico da Órbita")
		_check(new_world.effects.get_child_count() == 0, "novo World herdou efeitos antigos")
		_check(new_world.projectiles.get_child_count() == 0, "novo World herdou projéteis antigos")
		_check(new_world.player_projectile_batch_renderer._entries.is_empty(), "batch novo herdou IDs antigos")
		_check(new_world.hud.bound_world == new_world, "HUD não foi vinculado ao novo World/Player")
	for reference in old_effect_refs:
		_check(reference.get_ref() == null, "efeito do World antigo sobreviveu ao retry")
	for reference in old_projectile_refs:
		_check(reference.get_ref() == null, "projétil do World antigo sobreviveu ao retry")

	for _frame in range(20):
		await process_frame
	_check(old_world_ref.get_ref() == null, "callback tardio reativou/reteve o World antigo")
	paused = false
	if is_instance_valid(new_world):
		new_world.queue_free()
		await process_frame
	current_scene = null
	if failures.is_empty():
		print("EVOLUTION DEATH/RETRY OK: estágios antes da pausa=%s; retry isolou 9 evoluções, estados, callbacks e batches" % paused_snapshot)
		quit(0)
	else:
		quit(1)
