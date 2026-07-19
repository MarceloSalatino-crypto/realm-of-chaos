extends Node2D

const GameDefs = preload("res://scripts/game_defs.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const GemScene = preload("res://scenes/xp_gem.tscn")
const EffectScript = preload("res://scripts/effect.gd")
const DamageNumberScript = preload("res://scripts/damage_number.gd")
const AudioDirectorScript = preload("res://scripts/audio_director.gd")
const RewardChestScript = preload("res://scripts/reward_chest.gd")
const ArenaHazardScript = preload("res://scripts/arena_hazard.gd")
const MapOverlayScript = preload("res://scripts/map_overlay.gd")
const MapLandmarkScript = preload("res://scripts/map_landmark.gd")

const RUN_DURATION := 25.0 * 60.0
const BOSS_TIMES := [300.0, 600.0, 900.0, 1200.0, 1500.0]
const EVENT_TIMES := [150.0, 450.0, 750.0, 1050.0, 1350.0]
const SAVE_PATH := "user://realm_of_chaos.cfg"
const GRID_CELL_SIZE := 180.0
const MAX_PLAYER_PROJECTILES := 360
const MAX_EFFECTS := 120

var time_survived := 0.0
var enemies_killed := 0
var essence_earned := 0
var spawn_timer := 0.2
var boss_index := 0
var event_index := 0
var game_ended := false
var pending_upgrades := 0
var upgrade_active := false
var active_boss: Node
var last_stage := ""
var run_cycle := 0
var biome: Dictionary = {}
var final_boss_spawned := false
var boss_spawn_log: Array[String] = []
var spatial_grid: Dictionary = {}
var spatial_timer := 0.0
var current_event := ""
var current_event_title := ""
var event_remaining := 0.0
var enemy_speed_multiplier := 1.0
var event_spawn_multiplier := 1.0
var event_magnet_applied := false
var suppress_save := false
var audio: Node
var rewards: Node2D
var hazards: Node2D
var landmarks: Node2D
var obstacles: Node2D
var map_overlay: Node2D
var landmark_positions: Array[Vector2] = []
var shrines_activated := 0
var pending_chest: Node
var damage_by_source: Dictionary = {}
var damage_taken := 0.0
var bosses_defeated := 0
var accessibility_settings: Dictionary = {}

@onready var player = $Player
@onready var ground: Sprite2D = $Ground
@onready var enemies = $Enemies
@onready var projectiles = $Projectiles
@onready var enemy_projectiles = $EnemyProjectiles
@onready var pickups = $Pickups
@onready var effects = $Effects
@onready var decorations = $Decorations
@onready var hud = $HUD


func _ready() -> void:
	randomize()
	get_tree().paused = false
	rewards = Node2D.new()
	rewards.name = "Rewards"
	add_child(rewards)
	hazards = Node2D.new()
	hazards.name = "ArenaHazards"
	add_child(hazards)
	landmarks = Node2D.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	obstacles = Node2D.new()
	obstacles.name = "PhysicalObstacles"
	add_child(obstacles)
	map_overlay = MapOverlayScript.new()
	map_overlay.name = "MapOverlay"
	add_child(map_overlay)
	audio = AudioDirectorScript.new()
	audio.name = "AudioDirector"
	add_child(audio)
	_load_progression()
	_apply_biome()
	audio.set_music_stage("normal")
	player.level_up_requested.connect(_on_level_up_requested)
	player.died.connect(_on_player_died)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.relic_selected.connect(_on_relic_selected)
	hud.restart_requested.connect(_restart_run)
	hud.menu_requested.connect(_return_to_menu)
	hud.resume_requested.connect(_resume_run)
	hud.bind_world(self)
	_generate_environment()
	last_stage = GameDefs.stage_name(time_survived)
	hud.show_stage_banner("%s · ARMA SORTEADA: %s" % [str(biome.name), player.equipped_weapon_title()])
	_rebuild_spatial_grid()


func _process(delta: float) -> void:
	if game_ended or player.death_started:
		return
	time_survived = minf(RUN_DURATION, time_survived + delta)
	spatial_timer -= delta
	if spatial_timer <= 0.0:
		_rebuild_spatial_grid()
		spatial_timer = 0.14
	_spawn_timer_update(delta)
	_update_boss_schedule()
	_update_world_events(delta)
	_update_stage()
	_update_hud()


func _spawn_timer_update(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var difficulty := GameDefs.difficulty_data(time_survived)
	spawn_timer += float(difficulty.interval)
	var enemy_cap := int(difficulty.cap)
	var current_count := enemies.get_child_count()
	if current_count >= enemy_cap:
		return
	var requested_batch := ceili(float(difficulty.batch) * event_spawn_multiplier)
	var batch := mini(requested_batch, enemy_cap - current_count)
	for _index in range(batch):
		spawn_enemy(_pick_enemy_type(), false)


func _pick_enemy_type() -> String:
	var phase_id := str(GameDefs.difficulty_data(time_survived).id)
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
			if time_survived >= 18.0:
				choices.append_array(["bat", "bat", "swarm"])
			if time_survived >= 52.0:
				choices.append_array(["mage", "archer"])
			if time_survived >= 115.0:
				choices.append("brute")
			if time_survived >= 205.0:
				choices.append_array(["ember", "bomber"])
	return choices.pick_random()


func spawn_enemy(kind: String, force_elite := false, power_override := -1.0) -> Node:
	if game_ended or not is_instance_valid(player):
		return null
	var enemy = EnemyScene.instantiate()
	var phase := GameDefs.difficulty_data(time_survived)
	var data := GameDefs.enemy_data(kind)
	var difficulty := float(phase.power) * float(biome.get("enemy_power", 1.0))
	if power_override > 0.0:
		difficulty = power_override
	var elite_chance := float(phase.elite_chance)
	var is_boss := bool(data.get("boss", false))
	var is_elite := force_elite or (not is_boss and randf() < elite_chance)
	enemy.setup(kind, difficulty, is_elite, self)
	enemies.add_child(enemy)
	enemy.global_position = get_spawn_position(580.0 if is_boss else 610.0, 670.0 if is_boss else 760.0)
	return enemy


func get_spawn_position(minimum := 610.0, maximum := 760.0) -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	var angle := randf() * TAU
	return player.global_position + Vector2.RIGHT.rotated(angle) * randf_range(minimum, maximum)


func _update_boss_schedule() -> void:
	var schedule := GameDefs.boss_schedule()
	while boss_index < schedule.size() and time_survived >= float(schedule[boss_index].time):
		_spawn_scheduled_boss(schedule[boss_index], boss_index)
		boss_index += 1


func _spawn_scheduled_boss(entry: Dictionary, index: int) -> Node:
	var boss_power := 1.0 + float(run_cycle) * 0.32
	active_boss = spawn_enemy(str(entry.kind), false, boss_power)
	if not active_boss:
		return null
	active_boss.global_position = get_spawn_position(520.0, 610.0)
	boss_spawn_log.append(str(entry.kind))
	if bool(entry.final):
		final_boss_spawned = true
	hud.show_boss(str(entry.name), active_boss.hp, active_boss.max_hp)
	hud.show_stage_banner("CHEFE FINAL · O RITUAL EXIGE UMA VITÓRIA" if bool(entry.final) else "MINI-CHEFE %d/4 · %s" % [index + 1, str(entry.name)])
	hud.show_boss_intro(str(entry.name), "CHEFE FINAL" if bool(entry.final) else "GUARDIÃO DO MINUTO %d" % int(float(entry.time) / 60.0), bool(entry.final))
	audio.play_boss_spawn()
	audio.set_music_stage("boss")
	shake_camera(9.0 if bool(entry.final) else 6.0, 0.38)
	return active_boss


func _update_stage() -> void:
	var current_stage := GameDefs.stage_name(time_survived)
	if current_stage == last_stage:
		return
	last_stage = current_stage
	audio.set_music_stage(str(GameDefs.difficulty_data(time_survived).id))
	hud.show_stage_banner(current_stage)
	var phase_id := str(GameDefs.difficulty_data(time_survived).id)
	var surge_count := 4
	if phase_id == "chaos":
		surge_count = 8
	elif phase_id == "inferno":
		surge_count = 12
	for index in range(surge_count):
		spawn_enemy("guardian" if index % 3 == 0 else ("bomber" if index % 2 == 0 else "assassin"), true)


func _update_hud() -> void:
	var remaining := maxf(0.0, RUN_DURATION - time_survived)
	var environment: Dictionary = get_environment_effect(player.global_position)
	var passive_status := "%s · %ds" % [player.blessing_title, ceili(player.blessing_time)] if player.blessing_time > 0.0 else str(environment.get("name", ""))
	var status_title := current_event_title if not current_event_title.is_empty() else passive_status
	hud.update_run(
		player.hp, player.max_hp, player.experience, player.experience_needed,
		player.level, enemies_killed, remaining, last_stage, player.weapon_summary(),
		essence_earned, status_title
	)
	hud.update_navigation(player.dash_status(), player.blessing_title, player.blessing_time)
	if is_instance_valid(active_boss) and not active_boss.dead:
		hud.update_boss(active_boss.hp, active_boss.max_hp)
	else:
		hud.hide_boss()


func _update_world_events(delta: float) -> void:
	if event_remaining > 0.0:
		event_remaining -= delta
		if event_remaining <= 0.0:
			_end_world_event()
	while event_index < EVENT_TIMES.size() and time_survived >= EVENT_TIMES[event_index]:
		var event_ids := ["blood_moon", "soul_storm", "eclipse", "blood_moon", "void_rain"]
		_trigger_world_event(event_ids[event_index])
		event_index += 1


func _trigger_world_event(event_id: String) -> void:
	_end_world_event()
	current_event = event_id
	event_remaining = 22.0
	match event_id:
		"blood_moon":
			current_event_title = "EVENTO · LUA DE SANGUE"
			event_spawn_multiplier = 1.65
			ground.modulate = Color("dd7a82")
			for _index in range(10):
				spawn_enemy("assassin" if _index % 3 == 0 else "swarm", false)
		"soul_storm":
			current_event_title = "EVENTO · TEMPESTADE DE ALMAS"
			player.pickup_radius *= 1.8
			event_magnet_applied = true
			ground.modulate = Color("aa8ee0")
		"eclipse":
			current_event_title = "EVENTO · ECLIPSE"
			enemy_speed_multiplier = 1.28
			ground.modulate = Color("9a75b7")
		"void_rain":
			current_event_title = "EVENTO · CHUVA DO VAZIO"
			ground.modulate = Color("8e72b9")
			for enemy in get_enemies_near(player.global_position, 900.0):
				enemy.take_damage(enemy.max_hp * 0.08, Vector2.ZERO, false)
	hud.show_event(current_event_title, GameDefs.difficulty_data(time_survived).color)


func _end_world_event() -> void:
	if event_magnet_applied:
		player.pickup_radius /= 1.8
	event_magnet_applied = false
	enemy_speed_multiplier = 1.0
	event_spawn_multiplier = 1.0
	current_event = ""
	current_event_title = ""
	event_remaining = 0.0
	if not biome.is_empty() and is_instance_valid(ground):
		ground.modulate = biome.ground_modulate


func handle_enemy_death(enemy: Node, xp_value: int, was_elite: bool, was_boss: bool) -> void:
	enemies_killed += 1
	if was_boss:
		essence_earned += 50 if enemy.final_boss else 18
	elif was_elite:
		essence_earned += 3
	elif enemies_killed % 7 == 0:
		essence_earned += 1
	var gem = GemScene.instantiate()
	pickups.add_child(gem)
	gem.setup(xp_value, enemy.global_position, "xp")
	var death_color: Color = GameDefs.enemy_data(enemy.enemy_type).color
	spawn_effect(enemy.global_position, death_color, enemy.hit_radius * 2.2, 0.32, true)
	if (was_elite and randf() < 0.35) or (not was_elite and randf() < 0.018):
		var heart = GemScene.instantiate()
		pickups.add_child(heart)
		heart.setup(24 if not was_boss else 60, enemy.global_position + Vector2(18, 0), "heal")
	if not was_boss:
		return
	bosses_defeated += 1
	if active_boss == enemy:
		active_boss = null
	for index in range(10 if enemy.final_boss else 7):
		var bonus = GemScene.instantiate()
		pickups.add_child(bonus)
		bonus.setup(18 if enemy.final_boss else 12, enemy.global_position + Vector2.RIGHT.rotated(TAU * index / 10.0) * randf_range(28.0, 92.0), "xp")
	player.grant_boss_reward(enemy.final_boss)
	shake_camera(12.0, 0.55)
	if enemy.final_boss:
		hud.show_stage_banner("SOBERANO DERROTADO · PRÓXIMA FASE DESBLOQUEADA")
		call_deferred("_end_run", true)
	else:
		_spawn_reward_chest(enemy.global_position, str(GameDefs.enemy_data(enemy.enemy_type).name))
		hud.show_stage_banner("MINI-CHEFE BANIDO · O BAÚ DO RITUAL SURGIU")
		audio.set_music_stage(str(GameDefs.difficulty_data(time_survived).id))


func _spawn_reward_chest(chest_position: Vector2, boss_name: String) -> Node:
	var chest = RewardChestScript.new()
	rewards.add_child(chest)
	chest.setup(self, chest_position, boss_name)
	spawn_effect(chest_position, Color("d99cff"), 125.0, 0.75, true)
	return chest


func open_reward_chest(chest: Node) -> void:
	if game_ended or pending_chest != null or not is_instance_valid(chest):
		return
	pending_chest = chest
	var options: Array[Dictionary] = player.get_relic_options(3)
	if options.is_empty():
		player.grant_boss_reward(false)
		chest.queue_free()
		pending_chest = null
		return
	get_tree().paused = true
	hud.show_relic_choice(options, str(chest.source_boss))
	audio.play_reward()


func _on_relic_selected(relic_id: String) -> void:
	if pending_chest == null:
		return
	var selected_title := relic_id
	for definition in GameDefs.relics():
		if str(definition.id) == relic_id:
			selected_title = str(definition.title)
			break
	player.apply_relic(relic_id)
	hud.hide_relic_choice()
	hud.show_stage_banner("RELÍQUIA ABSORVIDA · %s" % selected_title)
	spawn_effect(player.global_position, Color("ffd36b"), 180.0, 0.70, true)
	if is_instance_valid(pending_chest):
		pending_chest.queue_free()
	pending_chest = null
	get_tree().paused = false


func add_player_projectile(projectile: Node) -> void:
	if projectiles.get_child_count() >= MAX_PLAYER_PROJECTILES:
		var oldest := projectiles.get_child(0)
		oldest.queue_free()
	projectiles.add_child(projectile)


func add_enemy_projectile(projectile: Node) -> void:
	if enemy_projectiles.get_child_count() >= 260:
		enemy_projectiles.get_child(0).queue_free()
	enemy_projectiles.add_child(projectile)


func spawn_effect(position: Vector2, color: Color, radius: float, duration := 0.35, filled := false) -> void:
	if effects.get_child_count() >= MAX_EFFECTS:
		return
	var effect = EffectScript.new()
	effects.add_child(effect)
	effect.setup(position, color, radius, duration, filled)


func spawn_damage_number(position: Vector2, amount: float, critical := false, healing := false, custom_text := "") -> void:
	if effects.get_child_count() >= MAX_EFFECTS:
		return
	var number = DamageNumberScript.new()
	effects.add_child(number)
	number.setup(position, amount, critical, healing, custom_text)


func on_enemy_hit(position: Vector2, amount: float, critical: bool, is_boss: bool) -> void:
	spawn_damage_number(position, amount, critical)
	audio.play_hit(critical)
	if critical:
		spawn_effect(position, Color("ffd86b"), 30.0, 0.16, true)
	if critical and is_boss:
		shake_camera(3.5, 0.10)


func on_weapon_evolved(title: String) -> void:
	hud.show_stage_banner("EVOLUÇÃO · %s" % title)
	audio.play_evolution()
	shake_camera(7.0, 0.32)
	spawn_effect(player.global_position, Color("ffd36b"), 210.0, 0.72, true)


func on_boss_phase_changed(enemy: Node, phase: int) -> void:
	if active_boss == enemy:
		hud.show_stage_banner("%s · FASE %d" % [str(GameDefs.enemy_data(enemy.enemy_type).name), phase])
		hud.set_boss_phase(phase)
		shake_camera(8.0, 0.28)


func on_player_damaged() -> void:
	hud.flash_damage(float(accessibility_settings.get("flash", 0.7)))
	audio.play_player_hurt()
	shake_camera(7.0, 0.18)


func on_player_revived() -> void:
	hud.show_stage_banner("PLUMA DA FÊNIX · VOCÊ RETORNOU")
	spawn_effect(player.global_position, Color("ffb35a"), 240.0, 1.0, true)
	audio.play_evolution()


func on_player_dash(direction: Vector2) -> void:
	spawn_effect(player.global_position - direction * 18.0, Color("9d72ff"), 58.0, 0.22, true)
	audio.play_dash()
	shake_camera(1.8, 0.10)


func activate_landmark(landmark: Node) -> void:
	if not is_instance_valid(landmark) or landmark.activated or game_ended:
		return
	var landmark_color: Color = landmark.minimap_color()
	landmark.mark_activated()
	shrines_activated += 1
	essence_earned += 4
	var blessing_name: String = player.apply_landmark_blessing(str(landmark.landmark_kind), 40.0)
	if str(landmark.landmark_kind) == "tree":
		for pickup in pickups.get_children():
			if is_instance_valid(pickup) and pickup.global_position.distance_to(player.global_position) <= 1450.0:
				pickup.attracted = true
	hud.show_stage_banner("SANTUÁRIO ATIVADO · %s · 40 SEGUNDOS" % blessing_name)
	spawn_effect(landmark.global_position, landmark_color, 225.0, 0.90, true)
	audio.play_reward()
	shake_camera(4.0, 0.22)


func record_damage(source_id: String, amount: float, target_is_boss := false) -> void:
	damage_by_source[source_id] = float(damage_by_source.get(source_id, 0.0)) + amount
	if is_instance_valid(player):
		player.on_damage_dealt(amount, target_is_boss)


func record_player_damage(amount: float) -> void:
	damage_taken += amount


func shake_camera(strength: float, duration := 0.18) -> void:
	if not is_instance_valid(player):
		return
	strength *= float(accessibility_settings.get("shake", 0.75))
	if strength <= 0.01:
		return
	var camera: Camera2D = player.get_node("Camera2D")
	var original := Vector2.ZERO
	camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	var tween := create_tween()
	tween.tween_property(camera, "offset", original, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _rebuild_spatial_grid() -> void:
	spatial_grid.clear()
	for enemy in enemies.get_children():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var cell := _grid_cell(enemy.global_position)
		if not spatial_grid.has(cell):
			spatial_grid[cell] = []
		spatial_grid[cell].append(enemy)


func _grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / GRID_CELL_SIZE), floori(position.y / GRID_CELL_SIZE))


func get_enemies_near(position: Vector2, radius: float) -> Array[Node]:
	if spatial_grid.is_empty() and enemies.get_child_count() > 0:
		_rebuild_spatial_grid()
	var result: Array[Node] = []
	var center := _grid_cell(position)
	var reach := ceili(radius / GRID_CELL_SIZE)
	var radius_squared := radius * radius
	for x_offset in range(-reach, reach + 1):
		for y_offset in range(-reach, reach + 1):
			var cell := center + Vector2i(x_offset, y_offset)
			for enemy in spatial_grid.get(cell, []):
				if is_instance_valid(enemy) and not enemy.dead and position.distance_squared_to(enemy.global_position) <= radius_squared:
					result.append(enemy)
	return result


func get_nearest_enemy(position: Vector2, maximum_distance := 1500.0) -> Node2D:
	var nearest: Node2D
	var nearest_distance := maximum_distance * maximum_distance
	for enemy in get_enemies_near(position, maximum_distance):
		var distance := position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func _on_level_up_requested() -> void:
	pending_upgrades += 1
	if not upgrade_active:
		call_deferred("_show_next_upgrade")


func _show_next_upgrade() -> void:
	if pending_upgrades <= 0 or game_ended:
		return
	upgrade_active = true
	get_tree().paused = true
	hud.show_level_up(player.level, player.get_upgrade_options(3))


func _on_upgrade_selected(upgrade_id: String, rarity: String) -> void:
	player.apply_upgrade(upgrade_id, rarity)
	pending_upgrades -= 1
	if pending_upgrades > 0:
		hud.show_level_up(player.level, player.get_upgrade_options(3))
	else:
		upgrade_active = false
		hud.hide_level_up()
		get_tree().paused = false


func _on_player_died() -> void:
	_end_run(false)


func _end_run(victory: bool) -> void:
	if game_ended:
		return
	game_ended = true
	get_tree().paused = true
	var new_achievements := _evaluate_achievements(victory)
	_save_record(victory)
	var next_biome := str(GameDefs.biome_data(run_cycle + 1).name) if victory else str(biome.name)
	hud.show_end_screen(victory, time_survived, enemies_killed, player.level, essence_earned, next_biome, _run_stats_text(), new_achievements)


func _run_stats_text() -> String:
	var total_damage := 0.0
	var top_source := ""
	var top_damage := 0.0
	for source_id in damage_by_source:
		var amount := float(damage_by_source[source_id])
		total_damage += amount
		if amount > top_damage:
			top_damage = amount
			top_source = str(source_id)
	var top_title := _weapon_title(top_source) if not top_source.is_empty() else "Nenhuma"
	return "Dano causado  %d\nMaior fonte  %s (%d)\nDano recebido  %d\nChefes derrotados  %d/5 · Santuários  %d/4\nRelíquias  %s" % [
		ceili(total_damage), top_title, ceili(top_damage), ceili(damage_taken), bosses_defeated, shrines_activated, player.relic_summary()
	]


func _weapon_title(source_id: String) -> String:
	for definition in GameDefs.upgrades():
		if str(definition.id) == source_id:
			return str(definition.title)
	return source_id.capitalize()


func _evaluate_achievements(victory: bool) -> Array[String]:
	var earned_ids: Array[String] = []
	if bosses_defeated >= 1:
		earned_ids.append("first_boss")
	if bosses_defeated >= 5:
		earned_ids.append("boss_slayer")
	if victory:
		earned_ids.append("survivor")
	if enemies_killed >= 500:
		earned_ids.append("exterminator")
	if player.all_weapons_evolved():
		earned_ids.append("arsenal")
	if victory and damage_taken <= 100.0:
		earned_ids.append("untouchable")
	if shrines_activated >= 4:
		earned_ids.append("cartographer")
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var newly_unlocked: Array[String] = []
	for definition in GameDefs.achievements():
		var achievement_id := str(definition.id)
		if not achievement_id in earned_ids or bool(config.get_value("achievements", achievement_id, false)):
			continue
		newly_unlocked.append(str(definition.title))
		config.set_value("achievements", achievement_id, true)
	if not suppress_save:
		config.save(SAVE_PATH)
	return newly_unlocked


func _save_record(victory: bool) -> void:
	if suppress_save:
		return
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var best_time := float(config.get_value("record", "best_time", 0.0))
	var best_kills := int(config.get_value("record", "best_kills", 0))
	config.set_value("record", "best_time", maxf(best_time, time_survived))
	config.set_value("record", "best_kills", maxi(best_kills, enemies_killed))
	config.set_value("record", "victories", int(config.get_value("record", "victories", 0)) + (1 if victory else 0))
	config.set_value("meta", "essence", int(config.get_value("meta", "essence", 0)) + essence_earned)
	if victory:
		config.set_value("progress", "active_cycle", run_cycle + 1)
		config.set_value("progress", "highest_cycle", maxi(run_cycle + 1, int(config.get_value("progress", "highest_cycle", 0))))
	config.save(SAVE_PATH)


func _load_progression() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("profile", "version", 2)
	run_cycle = int(config.get_value("progress", "active_cycle", 0))
	biome = GameDefs.biome_data(run_cycle)
	var meta := {
		"power": int(config.get_value("meta", "power", 0)),
		"vitality": int(config.get_value("meta", "vitality", 0)),
		"speed": int(config.get_value("meta", "speed", 0)),
		"fortune": int(config.get_value("meta", "fortune", 0))
	}
	player.apply_meta_bonuses(meta)
	player.apply_character(str(config.get_value("profile", "character", "eclipse_hunter")))
	accessibility_settings = GameDefs.default_settings()
	for setting_id in accessibility_settings:
		accessibility_settings[setting_id] = config.get_value("settings", setting_id, accessibility_settings[setting_id])
	audio.set_levels(float(accessibility_settings.music), float(accessibility_settings.sfx))
	hud.set_accessibility(float(accessibility_settings.flash))


func _apply_biome() -> void:
	ground.texture = load(str(biome.ground))
	ground.modulate = biome.ground_modulate


func _restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _resume_run() -> void:
	if not upgrade_active and not game_ended:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("editor") or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F7:
			_debug_jump_to_next_boss()
		KEY_F8:
			_debug_unlock_evolved_build()
		KEY_F9:
			_debug_defeat_active_boss()


func _debug_jump_to_next_boss() -> void:
	if boss_index >= BOSS_TIMES.size() or game_ended:
		return
	time_survived = maxf(time_survived, BOSS_TIMES[boss_index] - 0.02)
	spawn_timer = 0.5
	hud.show_stage_banner("TESTE · PRÓXIMO CHEFE EM INSTANTES")


func _debug_unlock_evolved_build() -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = player._upgrade_max(weapon_id)
	for passive_id in ["critical", "swiftness", "regeneration", "might"]:
		player.passive_levels[passive_id] = 5
	player._check_weapon_evolutions()
	hud.show_stage_banner("TESTE · QUATRO EVOLUÇÕES LIBERADAS")


func _debug_defeat_active_boss() -> void:
	if is_instance_valid(active_boss) and not active_boss.dead:
		active_boss.take_damage(active_boss.max_hp * 2.0, Vector2.ZERO, true)


func _generate_environment() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 864210 + run_cycle * 913
	_generate_map_layout(rng)
	var texture_paths := [
		"res://assets/environment/Tree/Tree_1.png", "res://assets/environment/Tree/Tree_2.png",
		"res://assets/environment/Tree/Tree_3.png", "res://assets/environment/props/bush/bush_01.png",
		"res://assets/environment/props/bush/bush_02.png", "res://assets/environment/props/Mushroom/Mushroom_03.png",
		"res://assets/environment/props/little stone/little stone_03.png"
	]
	var textures: Array[Texture2D] = []
	for path in texture_paths:
		textures.append(load(path))
	var biome_tint := Color("9ec7df") if str(biome.id) == "frozen" else (Color("9e82bb") if str(biome.id) == "cathedral" else Color("b3c7bd"))
	for index in range(310):
		var sprite := Sprite2D.new()
		sprite.texture = textures[rng.randi_range(0, textures.size() - 1)]
		var decoration_position := _find_free_map_position(rng, 5400.0)
		sprite.position = decoration_position
		var scale_value := rng.randf_range(0.65, 1.15)
		sprite.scale = Vector2.ONE * scale_value
		sprite.flip_h = rng.randf() < 0.5
		sprite.modulate = Color(biome_tint, rng.randf_range(0.36, 0.72))
		sprite.z_index = -4
		decorations.add_child(sprite)
	_generate_obstacles(rng)
	_generate_hazards(rng)


func _generate_map_layout(rng: RandomNumberGenerator) -> void:
	landmark_positions.clear()
	var rotation := float(run_cycle) * 0.31
	var base_positions: Array[Vector2] = [
		Vector2(1280.0, -920.0), Vector2(-1760.0, -1080.0),
		Vector2(1580.0, 1710.0), Vector2(-2200.0, 1470.0)
	]
	for base_position in base_positions:
		var jitter := Vector2(rng.randf_range(-130.0, 130.0), rng.randf_range(-130.0, 130.0))
		landmark_positions.append(base_position.rotated(rotation) + jitter)
	map_overlay.configure(str(biome.id), landmark_positions, 44321 + run_cycle * 701)
	var kinds: Array[String] = ["altar", "obelisk", "tree", "portal"]
	for index in range(kinds.size()):
		var landmark = MapLandmarkScript.new()
		landmark.configure(self, kinds[index], landmark_positions[index], index)
		landmarks.add_child(landmark)


func _find_free_map_position(rng: RandomNumberGenerator, maximum: float) -> Vector2:
	var candidate := Vector2.ZERO
	for _attempt in range(28):
		candidate = Vector2(rng.randf_range(-maximum, maximum), rng.randf_range(-maximum, maximum))
		if candidate.length() < 430.0:
			continue
		var blocked := false
		for landmark_position in landmark_positions:
			if candidate.distance_to(landmark_position) < 315.0 or _point_segment_distance(candidate, Vector2.ZERO, landmark_position) < 165.0:
				blocked = true
				break
		if not blocked:
			return candidate
	return candidate


func _point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * amount)


func _generate_obstacles(rng: RandomNumberGenerator) -> void:
	var obstacle_textures: Array[Texture2D] = [
		load("res://assets/environment/Tree/Tree_1.png"),
		load("res://assets/environment/Tree/Tree_2.png"),
		load("res://assets/environment/Tree/Tree_3.png"),
		load("res://assets/environment/props/little stone/little stone_03.png")
	]
	for index in range(24):
		var body := StaticBody2D.new()
		body.position = _find_free_map_position(rng, 5150.0)
		body.z_index = -3
		body.collision_layer = 1
		body.collision_mask = 1
		var obstacle_sprite := Sprite2D.new()
		obstacle_sprite.texture = obstacle_textures[index % obstacle_textures.size()]
		var obstacle_scale := rng.randf_range(0.82, 1.18)
		obstacle_sprite.scale = Vector2.ONE * obstacle_scale
		obstacle_sprite.modulate = Color(0.76, 0.82, 0.86, 0.90)
		body.add_child(obstacle_sprite)
		var collision := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 18.0 * obstacle_scale
		collision.position.y = 7.0
		collision.shape = circle
		body.add_child(collision)
		obstacles.add_child(body)


func _generate_hazards(rng: RandomNumberGenerator) -> void:
	var hazard_kind := "roots"
	if str(biome.id) == "frozen":
		hazard_kind = "ice"
	elif str(biome.id) == "cathedral":
		hazard_kind = "void"
	for index in range(18):
		var hazard_position := _find_free_map_position(rng, 5000.0)
		var hazard = ArenaHazardScript.new()
		hazards.add_child(hazard)
		hazard.setup(hazard_kind, hazard_position, rng.randf_range(82.0, 138.0), rng.randi())


func get_environment_effect(position: Vector2) -> Dictionary:
	for hazard in get_tree().get_nodes_in_group("arena_hazards"):
		if is_instance_valid(hazard) and hazard.contains_point(position):
			return hazard.effect_data()
	return {"speed": 1.0, "traction": 1.0, "damage": 0.0, "name": ""}
