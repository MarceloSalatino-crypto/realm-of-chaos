extends RefCounted

const GameDefs = preload("res://scripts/game_defs.gd")
const BossArenaScript = preload("res://scripts/boss_arena.gd")

var world


func _init(owner_world) -> void:
	world = owner_world


func update_spawn_timer(delta: float) -> void:
	world.spawn_timer -= delta
	if world.spawn_timer > 0.0:
		return
	var difficulty := GameDefs.difficulty_data(world.time_survived)
	world.spawn_timer += float(difficulty.interval)
	var enemy_cap := int(difficulty.cap)
	var current_count: int = world.enemies.get_child_count()
	if current_count >= enemy_cap:
		return
	var requested_batch: int = ceili(float(difficulty.batch) * world.event_spawn_multiplier)
	var batch: int = mini(requested_batch, enemy_cap - current_count)
	for _index in range(batch):
		world.spawn_enemy(pick_enemy_type(), false)


func pick_enemy_type() -> String:
	var phase_id := str(GameDefs.difficulty_data(world.time_survived).id)
	var choices: Array[String]
	match phase_id:
		"hard":
			choices = ["prowler", "bat", "bat", "mage", "archer", "brute", "bomber", "swarm"]
		"chaos":
			choices = ["bat", "mage", "archer", "brute", "brute", "ember", "bomber", "assassin", "necromancer", "swarm"]
		"inferno":
			choices = ["mage", "archer", "brute", "brute", "ember", "bomber", "assassin", "necromancer", "guardian", "swarm", "swarm"]
		_:
			choices = ["prowler", "prowler", "prowler"]
			if world.time_survived >= 18.0:
				choices.append_array(["bat", "bat", "swarm"])
			if world.time_survived >= 52.0:
				choices.append_array(["mage", "archer"])
			if world.time_survived >= 115.0:
				choices.append("brute")
			if world.time_survived >= 205.0:
				choices.append_array(["ember", "bomber"])
	return choices.pick_random()


func update_boss_schedule() -> void:
	var schedule := GameDefs.boss_schedule()
	if has_live_active_boss() or has_pending_boss_spawn() or world.boss_index >= schedule.size():
		return
	var entry: Dictionary = schedule[world.boss_index]
	if world.time_survived < float(entry.time):
		return
	if world.is_processing():
		world.director_spawn_queue.append({"type": "boss", "entry": entry, "index": world.boss_index})
		return
	if spawn_scheduled_boss(entry, world.boss_index):
		world.boss_index += 1


func has_live_active_boss() -> bool:
	return is_instance_valid(world.active_boss) and not bool(world.active_boss.dead)


func has_pending_boss_spawn() -> bool:
	for job in world.director_spawn_queue:
		if str(job.get("type", "")) == "boss":
			return true
	return false


func process_spawn_queue() -> void:
	if world.director_spawn_queue.is_empty():
		return
	var job: Dictionary = world.director_spawn_queue.pop_front()
	if str(job.get("type", "")) == "boss":
		var job_index := int(job.index)
		if job_index != world.boss_index or has_live_active_boss():
			return
		if spawn_scheduled_boss(job.entry, job_index):
			world.boss_index += 1
	else:
		world.spawn_enemy(str(job.kind), bool(job.get("elite", false)))


func spawn_scheduled_boss(entry: Dictionary, index: int) -> Node:
	if has_live_active_boss():
		return null
	var boss_power := 1.0 + float(world.run_cycle) * 0.32
	world.active_boss = world.spawn_enemy(str(entry.kind), false, boss_power)
	if not world.active_boss:
		return null
	world.active_boss.global_position = world.get_spawn_position(520.0, 610.0)
	world.boss_spawn_log.append(str(entry.kind))
	if bool(entry.final):
		world.final_boss_spawned = true
	if is_instance_valid(world.active_boss_arena):
		world.active_boss_arena.finish()
	world.active_boss_arena = BossArenaScript.new()
	world.active_boss_arena.configure(world, world.active_boss, world.player.global_position, str(entry.kind), bool(entry.final))
	world.add_child(world.active_boss_arena)
	world.hud.show_boss(str(entry.name), world.active_boss.hp, world.active_boss.max_hp)
	world.hud.show_stage_banner("CHEFE FINAL · O RITUAL EXIGE UMA VITÓRIA" if bool(entry.final) else "MINI-CHEFE %d/4 · %s" % [index + 1, str(entry.name)])
	world.hud.show_boss_intro(str(entry.name), "CHEFE FINAL" if bool(entry.final) else "GUARDIÃO DO MINUTO %d" % int(float(entry.time) / 60.0), bool(entry.final))
	world.audio.play_boss_spawn()
	world.audio.set_music_stage("boss")
	world.shake_camera(9.0 if bool(entry.final) else 6.0, 0.38)
	return world.active_boss


func update_stage() -> void:
	var current_stage := GameDefs.stage_name(world.time_survived)
	if current_stage == world.last_stage:
		return
	world.last_stage = current_stage
	world.audio.set_music_stage(str(GameDefs.difficulty_data(world.time_survived).id))
	world.hud.show_stage_banner(current_stage)
	var phase_id := str(GameDefs.difficulty_data(world.time_survived).id)
	var surge_count := 4
	if phase_id == "chaos":
		surge_count = 8
	elif phase_id == "inferno":
		surge_count = 12
	for index in range(surge_count):
		var kind := "guardian" if index % 3 == 0 else ("bomber" if index % 2 == 0 else "assassin")
		if world.is_processing():
			world.director_spawn_queue.append({"type": "elite", "kind": kind, "elite": true})
		else:
			world.spawn_enemy(kind, true)


func next_boss_status() -> String:
	if is_instance_valid(world.active_boss) and not world.active_boss.dead:
		return "CHEFE ATIVO"
	var schedule := GameDefs.boss_schedule()
	if world.boss_index >= schedule.size():
		return "RITUAL FINAL"
	var seconds_left := maxi(0, ceili(float(schedule[world.boss_index].time) - world.time_survived))
	@warning_ignore("integer_division")
	return "PRÓXIMO CHEFE %02d:%02d" % [seconds_left / 60, seconds_left % 60]


func update_world_events(delta: float) -> void:
	if world.event_remaining > 0.0:
		world.event_remaining -= delta
		if world.event_remaining <= 0.0:
			end_world_event()
	while world.event_index < world.EVENT_TIMES.size() and world.time_survived >= world.EVENT_TIMES[world.event_index]:
		var event_ids := ["blood_moon", "soul_storm", "eclipse", "blood_moon", "void_rain"]
		trigger_world_event(event_ids[world.event_index])
		world.event_index += 1


func trigger_world_event(event_id: String) -> void:
	end_world_event()
	world.current_event = event_id
	world.event_remaining = 22.0
	match event_id:
		"blood_moon":
			world.current_event_title = "EVENTO · LUA DE SANGUE"
			world.event_spawn_multiplier = 1.65
			world.ground.modulate = Color("dd7a82")
			for index in range(10):
				world.spawn_enemy("assassin" if index % 3 == 0 else "swarm", false)
		"soul_storm":
			world.current_event_title = "EVENTO · TEMPESTADE DE ALMAS"
			world.player.pickup_radius *= 1.8
			world.event_magnet_applied = true
			world.ground.modulate = Color("aa8ee0")
		"eclipse":
			world.current_event_title = "EVENTO · ECLIPSE"
			world.enemy_speed_multiplier = 1.28
			world.ground.modulate = Color("9a75b7")
		"void_rain":
			world.current_event_title = "EVENTO · CHUVA DO VAZIO"
			world.ground.modulate = Color("8e72b9")
			for enemy in world.get_enemies_near(world.player.global_position, 900.0):
				enemy.take_damage(enemy.max_hp * 0.08, Vector2.ZERO, false)
	world.hud.show_event(world.current_event_title, GameDefs.difficulty_data(world.time_survived).color)


func end_world_event() -> void:
	if world.event_magnet_applied:
		world.player.pickup_radius /= 1.8
	world.event_magnet_applied = false
	world.enemy_speed_multiplier = 1.0
	world.event_spawn_multiplier = 1.0
	world.current_event = ""
	world.current_event_title = ""
	world.event_remaining = 0.0
	if not world.biome.is_empty() and is_instance_valid(world.ground):
		world.ground.modulate = world.biome.ground_modulate
