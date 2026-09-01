extends RefCounted

const BossArenaScript = preload("res://scripts/boss_arena.gd")

var world


func _init(owner_world) -> void:
	world = owner_world


func update_spawn_timer(delta: float) -> void:
	world.spawn_timer -= delta
	if world.spawn_timer > 0.0:
		return
	var difficulty: Dictionary = world.difficulty_data()
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
	var choices: Array[String] = world.encounter_profile.enemy_choices_at(world.time_survived)
	return choices.pick_random()


func update_boss_schedule() -> void:
	var schedule: Array[Dictionary] = world.encounter_profile.boss_schedule
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
	var job: Dictionary = world.director_spawn_queue.front()
	if str(job.get("type", "")) == "boss":
		var job_index := int(job.index)
		if job_index != world.boss_index:
			world.director_spawn_queue.pop_front()
			return
		if has_live_active_boss():
			return
		if spawn_scheduled_boss(job.entry, job_index):
			world.director_spawn_queue.pop_front()
			world.boss_index += 1
	else:
		if world.spawn_enemy(str(job.kind), bool(job.get("elite", false))):
			world.director_spawn_queue.pop_front()


func spawn_scheduled_boss(entry: Dictionary, index: int) -> Node:
	if has_live_active_boss() or not world.has_enemy_capacity():
		return null
	var boss_power: float = float(world.map_boss_power)
	var boss_kind := str(entry.kind)
	var is_final := bool(entry.final)
	var arena_radius := BossArenaScript.radius_for(is_final)
	var arena_center: Vector2 = world.player.global_position
	var use_safe_environment: bool = world.environment_builder.supports_safe_boss_arena_placement()
	var placement: Dictionary = {}
	if use_safe_environment:
		var boss_radius := float(GameDefs.enemy_data(boss_kind).radius)
		placement = world.environment_builder.find_safe_boss_arena_placement(
			world.player.global_position, arena_radius, boss_radius
		)
		if placement.is_empty():
			return null
		arena_center = Vector2(placement.center)
		world.active_boss = world.spawn_enemy_at_validated_position(
			boss_kind, Vector2(placement.boss_position), false, boss_power
		)
	else:
		world.active_boss = world.spawn_enemy_near(
			boss_kind, world.player.global_position, 520.0, 610.0, false, boss_power
		)
	if not world.active_boss:
		return null
	if use_safe_environment and bool(placement.get("reposition_player", false)):
		world.player.global_position = arena_center
		world.player.velocity = Vector2.ZERO
		world.camera.reset_smoothing()
	world.boss_spawn_log.append(boss_kind)
	if is_final:
		world.final_boss_spawned = true
	if is_instance_valid(world.active_boss_arena):
		world.active_boss_arena.finish()
	world.active_boss_arena = BossArenaScript.new()
	world.active_boss_arena.configure(
		world, world.active_boss, arena_center, boss_kind, is_final, use_safe_environment
	)
	world.add_child(world.active_boss_arena)
	world.hud.show_boss(str(entry.name), world.active_boss.hp, world.active_boss.max_hp)
	world.hud.show_stage_banner("CHEFE FINAL · O RITUAL EXIGE UMA VITÓRIA" if is_final else "MINI-CHEFE %d/4 · %s" % [index + 1, str(entry.name)])
	world.hud.show_boss_intro(str(entry.name), "CHEFE FINAL" if is_final else "GUARDIÃO DO MINUTO %d" % int(float(entry.time) / 60.0), is_final)
	world.audio.play_boss_spawn()
	world.audio.set_music_stage(world.encounter_profile.music_stage_for("boss"))
	world.shake_camera(9.0 if bool(entry.final) else 6.0, 0.38)
	return world.active_boss


func update_stage() -> void:
	var difficulty: Dictionary = world.difficulty_data()
	var current_stage := str(difficulty.name)
	if current_stage == world.last_stage:
		return
	world.last_stage = current_stage
	var phase_id := str(difficulty.id)
	world.audio.set_music_stage(world.encounter_profile.music_stage_for(phase_id))
	world.hud.show_stage_banner(current_stage)
	var surge: Dictionary = world.encounter_profile.elite_surge_for_phase(phase_id)
	for enemy_id in Array(surge.get("sequence", [])):
		var kind := str(enemy_id)
		if world.is_processing():
			world.director_spawn_queue.append({"type": "elite", "kind": kind, "elite": true})
		else:
			world.spawn_enemy(kind, true)


func next_boss_status() -> String:
	if is_instance_valid(world.active_boss) and not world.active_boss.dead:
		return "CHEFE ATIVO"
	var schedule: Array[Dictionary] = world.encounter_profile.boss_schedule
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
	while world.event_index < world.encounter_profile.world_events.size():
		var entry: Dictionary = world.encounter_profile.event_at(world.event_index)
		if world.time_survived < float(entry.time):
			break
		_trigger_world_event_entry(entry)
		world.event_index += 1


func trigger_world_event(event_id: String) -> void:
	var entry: Dictionary = world.encounter_profile.event_by_id(event_id)
	if entry.is_empty():
		return
	_trigger_world_event_entry(entry)


func _trigger_world_event_entry(entry: Dictionary) -> void:
	end_world_event()
	world.current_event = str(entry.get("id", ""))
	world.current_event_title = str(entry.get("title", ""))
	world.event_remaining = float(entry.get("duration", 22.0))
	world.event_spawn_multiplier = float(entry.get("spawn_multiplier", 1.0))
	world.enemy_speed_multiplier = float(entry.get("enemy_speed_multiplier", 1.0))
	world.event_pickup_multiplier = float(entry.get("pickup_multiplier", 1.0))
	if not is_equal_approx(world.event_pickup_multiplier, 1.0):
		world.player.pickup_radius *= world.event_pickup_multiplier
		world.event_magnet_applied = true
	world.ground.modulate = Color(entry.get("ground_modulate", world.biome.ground_modulate))
	for enemy_id in Array(entry.get("burst_sequence", [])):
		world.spawn_enemy(str(enemy_id), false)
	var damage_ratio := float(entry.get("nearby_enemy_damage_ratio", 0.0))
	if damage_ratio > 0.0:
		var damage_radius := float(entry.get("nearby_enemy_damage_radius", 900.0))
		for enemy in world.get_enemies_near(world.player.global_position, damage_radius):
			enemy.take_damage(enemy.max_hp * damage_ratio, Vector2.ZERO, false)
	world.hud.show_event(world.current_event_title, Color(world.difficulty_data().color))


func end_world_event() -> void:
	if world.event_magnet_applied:
		world.player.pickup_radius /= maxf(world.event_pickup_multiplier, 0.001)
	world.event_magnet_applied = false
	world.event_pickup_multiplier = 1.0
	world.enemy_speed_multiplier = 1.0
	world.event_spawn_multiplier = 1.0
	world.current_event = ""
	world.current_event_title = ""
	world.event_remaining = 0.0
	if not world.biome.is_empty() and is_instance_valid(world.ground):
		world.ground.modulate = world.biome.ground_modulate
