extends Node2D

const GameDefs = preload("res://scripts/game_defs.gd")
const AudioDirectorScript = preload("res://scripts/audio_director.gd")
const WorldSpatialIndexScript = preload("res://scripts/world_spatial_index.gd")
const WorldEnvironmentBuilderScript = preload("res://scripts/world_environment_builder.gd")
const WorldPersistenceScript = preload("res://scripts/world_persistence.gd")
const WorldDirectorScript = preload("res://scripts/world_director.gd")
const WorldEntityManagerScript = preload("res://scripts/world_entity_manager.gd")
const WorldRunFlowScript = preload("res://scripts/world_run_flow.gd")

const RUN_DURATION := 25.0 * 60.0
const BOSS_TIMES := [300.0, 600.0, 900.0, 1200.0, 1500.0]
const EVENT_TIMES := [150.0, 450.0, 750.0, 1050.0, 1350.0]
const SAVE_PATH := "user://realm_of_chaos.cfg"
const GRID_CELL_SIZE := 180.0
const MAX_PLAYER_PROJECTILES := 360
const MAX_ENEMY_PROJECTILES := 260
const ENEMY_PROJECTILE_POOL_LIMIT := 160
const MAX_EFFECTS := 120
const MAX_PICKUPS := 520
const EFFECT_MEDIUM_LOAD := 36
const EFFECT_HIGH_LOAD := 84
const ENEMY_MEDIUM_VISUAL_LOAD := 120
const ENEMY_HIGH_VISUAL_LOAD := 210

var time_survived := 0.0
var enemies_killed := 0
var essence_earned := 0
var spawn_timer := 0.2
var boss_index := 0
var event_index := 0
var game_ended := false
var pending_upgrades := 0
var upgrade_active := false
var rerolls_left := 3
var banishes_left := 3
var skips_left := 2
var active_boss: Node
var active_boss_arena: Node
var last_stage := ""
var run_cycle := 0
var biome: Dictionary = {}
var final_boss_spawned := false
var boss_spawn_log: Array[String] = []
var spatial_index = WorldSpatialIndexScript.new(GRID_CELL_SIZE)
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
var environment_builder: WorldEnvironmentBuilderScript
var persistence: WorldPersistenceScript
var director: WorldDirectorScript
var entity_manager: WorldEntityManagerScript
var run_flow: WorldRunFlowScript
var landmark_positions: Array[Vector2] = []
var shrines_activated := 0
var pending_chest: Node
var damage_by_source: Dictionary = {}
var damage_taken := 0.0
var bosses_defeated := 0
var accessibility_settings: Dictionary = {}
var pickup_merge_cursor := 0
var visual_view_half_size := Vector2(640.0, 360.0)
var director_spawn_queue: Array[Dictionary] = []

@onready var player = $Player
@onready var ground: Sprite2D = $Ground
@onready var enemies = $Enemies
@onready var projectiles = $Projectiles
@onready var enemy_projectiles = $EnemyProjectiles
@onready var enemy_projectile_pool = $EnemyProjectilePool
@onready var pickups = $Pickups
@onready var effects = $Effects
@onready var decorations = $Decorations
@onready var hud = $HUD
@onready var camera: Camera2D = $Player/Camera2D


func _ready() -> void:
	randomize()
	get_tree().paused = false
	rewards = Node2D.new()
	rewards.name = "Rewards"
	add_child(rewards)
	environment_builder = WorldEnvironmentBuilderScript.new(self)
	environment_builder.create_runtime_nodes()
	audio = AudioDirectorScript.new()
	audio.name = "AudioDirector"
	add_child(audio)
	entity_manager = WorldEntityManagerScript.new(self)
	persistence = WorldPersistenceScript.new(self, SAVE_PATH)
	director = WorldDirectorScript.new(self)
	run_flow = WorldRunFlowScript.new(self)
	_load_progression()
	_apply_biome()
	audio.set_music_stage("normal")
	player.level_up_requested.connect(_on_level_up_requested)
	player.died.connect(_on_player_died)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.reroll_requested.connect(_on_reroll_requested)
	hud.banish_requested.connect(_on_banish_requested)
	hud.skip_requested.connect(_on_skip_requested)
	hud.relic_selected.connect(_on_relic_selected)
	hud.restart_requested.connect(_restart_run)
	hud.menu_requested.connect(_return_to_menu)
	hud.resume_requested.connect(_resume_run)
	hud.bind_world(self)
	_generate_environment()
	_refresh_visual_bounds()
	last_stage = GameDefs.stage_name(time_survived)
	hud.show_stage_banner("%s · ARMA SORTEADA: %s" % [str(biome.name), player.equipped_weapon_title()])
	_rebuild_spatial_grid()


func _process(delta: float) -> void:
	if game_ended or player.death_started:
		return
	director.process_spawn_queue()
	_refresh_visual_bounds()
	time_survived = minf(RUN_DURATION, time_survived + delta)
	spatial_timer -= delta
	if spatial_timer <= 0.0:
		_rebuild_spatial_grid()
		spatial_timer = 0.14
	director.update_spawn_timer(delta)
	director.update_boss_schedule()
	director.update_world_events(delta)
	director.update_stage()
	run_flow.update_hud()


func _spawn_timer_update(delta: float) -> void:
	director.update_spawn_timer(delta)


func _pick_enemy_type() -> String:
	return director.pick_enemy_type()


func spawn_enemy(kind: String, force_elite := false, power_override := -1.0) -> Node:
	return entity_manager.spawn_enemy(kind, force_elite, power_override)


func get_spawn_position(minimum := 610.0, maximum := 760.0) -> Vector2:
	return entity_manager.get_spawn_position(minimum, maximum)


func _refresh_visual_bounds() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var camera_zoom := Vector2.ONE
	if is_instance_valid(camera):
		camera_zoom = camera.zoom
	visual_view_half_size = Vector2(
		viewport_size.x * 0.5 / maxf(camera_zoom.x, 0.01),
		viewport_size.y * 0.5 / maxf(camera_zoom.y, 0.01)
	)


func is_position_in_visual_bounds(position: Vector2, margin := 128.0) -> bool:
	if not is_instance_valid(player):
		return true
	var offset: Vector2 = position - player.global_position
	return absf(offset.x) <= visual_view_half_size.x + margin and absf(offset.y) <= visual_view_half_size.y + margin


func _spawn_position_is_clear(position: Vector2) -> bool:
	return environment_builder.is_spawn_position_clear(position)


func _update_boss_schedule() -> void:
	director.update_boss_schedule()


func _process_director_spawn_queue() -> void:
	director.process_spawn_queue()


func _spawn_scheduled_boss(entry: Dictionary, index: int) -> Node:
	return director.spawn_scheduled_boss(entry, index)


func _update_stage() -> void:
	director.update_stage()


func _update_hud() -> void:
	run_flow.update_hud()


func _next_boss_status() -> String:
	return director.next_boss_status()


func _update_world_events(delta: float) -> void:
	director.update_world_events(delta)


func _trigger_world_event(event_id: String) -> void:
	director.trigger_world_event(event_id)


func _end_world_event() -> void:
	director.end_world_event()


func handle_enemy_death(enemy: Node, xp_value: int, was_elite: bool, was_boss: bool) -> void:
	run_flow.handle_enemy_death(enemy, xp_value, was_elite, was_boss)


func _spawn_reward_chest(chest_position: Vector2, boss_name: String) -> Node:
	return run_flow.spawn_reward_chest(chest_position, boss_name)


func open_reward_chest(chest: Node) -> void:
	run_flow.open_reward_chest(chest)


func _on_relic_selected(relic_id: String) -> void:
	run_flow.on_relic_selected(relic_id)


func add_player_projectile(projectile: Node) -> void:
	entity_manager.add_player_projectile(projectile)


func spawn_enemy_projectile(position: Vector2, direction: Vector2, amount: float, projectile_speed: float, color: Color, size: float, danger_style := false) -> Node:
	return entity_manager.spawn_enemy_projectile(position, direction, amount, projectile_speed, color, size, danger_style)


func recycle_enemy_projectile(projectile: Node) -> void:
	entity_manager.recycle_enemy_projectile(projectile)


func add_enemy_projectile(projectile: Node) -> void:
	entity_manager.add_enemy_projectile(projectile)


func _spawn_pickup(amount: int, position: Vector2, kind := "xp") -> Node:
	return entity_manager.spawn_pickup(amount, position, kind)


func spawn_effect(position: Vector2, color: Color, radius: float, duration := 0.35, filled := false) -> void:
	entity_manager.spawn_effect(position, color, radius, duration, filled)


func _effect_visual_quality(radius: float, duration: float) -> int:
	return entity_manager.effect_visual_quality(radius, duration)


func spawn_weapon_flash(position: Vector2, atlas_frame: int, angle: float, scale_value: float, duration := 0.35, tint := Color.WHITE) -> void:
	entity_manager.spawn_weapon_flash(position, atlas_frame, angle, scale_value, duration, tint)


func spawn_lightning(chain_points: PackedVector2Array, color := Color("6eeaff")) -> void:
	entity_manager.spawn_lightning(chain_points, color)


func spawn_damage_number(position: Vector2, amount: float, critical := false, healing := false, custom_text := "") -> void:
	entity_manager.spawn_damage_number(position, amount, critical, healing, custom_text)


func on_enemy_hit(position: Vector2, amount: float, critical: bool, is_boss: bool) -> void:
	run_flow.on_enemy_hit(position, amount, critical, is_boss)


func on_weapon_evolved(title: String) -> void:
	run_flow.on_weapon_evolved(title)


func on_boss_phase_changed(enemy: Node, phase: int) -> void:
	run_flow.on_boss_phase_changed(enemy, phase)


func on_player_damaged() -> void:
	run_flow.on_player_damaged()


func on_player_revived() -> void:
	run_flow.on_player_revived()


func on_player_dash(direction: Vector2) -> void:
	run_flow.on_player_dash(direction)


func on_weapon_fired(weapon_id: String) -> void:
	run_flow.on_weapon_fired(weapon_id)


func activate_landmark(landmark: Node) -> void:
	run_flow.activate_landmark(landmark)


func record_damage(source_id: String, amount: float, target_is_boss := false) -> void:
	run_flow.record_damage(source_id, amount, target_is_boss)


func record_player_damage(amount: float) -> void:
	run_flow.record_player_damage(amount)


func shake_camera(strength: float, duration := 0.18) -> void:
	run_flow.shake_camera(strength, duration)


func _rebuild_spatial_grid() -> void:
	spatial_index.rebuild(enemies.get_children())


func _grid_cell(position: Vector2) -> Vector2i:
	return spatial_index.grid_cell(position)


func get_enemies_near(position: Vector2, radius: float) -> Array[Node]:
	if spatial_index.is_empty() and enemies.get_child_count() > 0:
		_rebuild_spatial_grid()
	return spatial_index.get_enemies_near(position, radius)


func get_nearest_enemy(position: Vector2, maximum_distance := 1500.0) -> Node2D:
	if spatial_index.is_empty() and enemies.get_child_count() > 0:
		_rebuild_spatial_grid()
	return spatial_index.get_nearest_enemy(position, maximum_distance)


func _on_level_up_requested() -> void:
	run_flow.on_level_up_requested()


func _show_next_upgrade() -> void:
	run_flow.show_next_upgrade()


func _present_upgrade_options(options: Array[Dictionary]) -> void:
	run_flow.present_upgrade_options(options)


func _on_upgrade_selected(upgrade_id: String, rarity: String) -> void:
	run_flow.on_upgrade_selected(upgrade_id, rarity)


func _on_reroll_requested() -> void:
	run_flow.on_reroll_requested()


func _on_banish_requested(upgrade_id: String) -> void:
	run_flow.on_banish_requested(upgrade_id)


func _on_skip_requested() -> void:
	run_flow.on_skip_requested()


func _advance_upgrade_queue() -> void:
	run_flow.advance_upgrade_queue()


func _on_player_died() -> void:
	run_flow.on_player_died()


func _end_run(victory: bool) -> void:
	run_flow.end_run(victory)


func _run_stats_text() -> String:
	return run_flow.run_stats_text()


func _weapon_title(source_id: String) -> String:
	return run_flow.weapon_title(source_id)


func _evaluate_achievements(victory: bool) -> Array[String]:
	return persistence.evaluate_achievements(victory)


func _save_record(victory: bool) -> void:
	persistence.save_record(victory)


func _load_progression() -> void:
	persistence.load_progression()


func _apply_biome() -> void:
	environment_builder.apply_biome()


func _restart_run() -> void:
	run_flow.restart_run()


func _return_to_menu() -> void:
	run_flow.return_to_menu()


func _resume_run() -> void:
	run_flow.resume_run()


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
		KEY_F10:
			_debug_gain_level()


func _debug_jump_to_next_boss() -> void:
	if boss_index >= BOSS_TIMES.size() or game_ended:
		return
	time_survived = maxf(time_survived, BOSS_TIMES[boss_index] - 0.02)
	spawn_timer = 0.5
	hud.show_stage_banner("TESTE · PRÓXIMO CHEFE EM INSTANTES")


func _debug_unlock_evolved_build() -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = player._upgrade_max(weapon_id)
	for weapon_id in player.WEAPON_IDS:
		var evolution := GameDefs.evolution_data(weapon_id)
		if not evolution.is_empty():
			player.passive_levels[str(evolution.passive)] = 5
	player._check_weapon_evolutions()
	hud.show_stage_banner("TESTE · NOVE EVOLUÇÕES LIBERADAS")


func _debug_defeat_active_boss() -> void:
	if is_instance_valid(active_boss) and not active_boss.dead:
		active_boss.take_damage(active_boss.max_hp * 2.0, Vector2.ZERO, true)


func _debug_gain_level() -> void:
	if game_ended or upgrade_active:
		return
	player.collect_xp(maxi(1, player.experience_needed - player.experience))


func _generate_environment() -> void:
	environment_builder.generate_environment()


func _generate_map_layout(rng: RandomNumberGenerator) -> void:
	environment_builder.generate_map_layout(rng)


func _find_free_map_position(rng: RandomNumberGenerator, maximum: float) -> Vector2:
	return environment_builder.find_free_map_position(rng, maximum)


func _point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	return environment_builder.point_segment_distance(point, start, finish)


func _generate_obstacles(rng: RandomNumberGenerator) -> void:
	environment_builder.generate_obstacles(rng)


func _generate_hazards(rng: RandomNumberGenerator) -> void:
	environment_builder.generate_hazards(rng)


func get_environment_effect(position: Vector2) -> Dictionary:
	return environment_builder.get_environment_effect(position)
