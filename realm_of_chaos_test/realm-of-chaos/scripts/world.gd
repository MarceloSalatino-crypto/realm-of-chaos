extends Node2D

const GameDefs = preload("res://scripts/game_defs.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const GemScene = preload("res://scenes/xp_gem.tscn")
const EffectScript = preload("res://scripts/effect.gd")

const RUN_DURATION := 600.0
const BOSS_TIMES := [180.0, 360.0, 540.0]
const SAVE_PATH := "user://realm_of_chaos.cfg"

var time_survived := 0.0
var enemies_killed := 0
var spawn_timer := 0.2
var boss_index := 0
var game_ended := false
var pending_upgrades := 0
var upgrade_active := false
var active_boss: Node
var last_stage := ""

@onready var player = $Player
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
	player.level_up_requested.connect(_on_level_up_requested)
	player.died.connect(_on_player_died)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.restart_requested.connect(_restart_run)
	hud.menu_requested.connect(_return_to_menu)
	hud.resume_requested.connect(_resume_run)
	_generate_environment()
	last_stage = GameDefs.stage_name(time_survived)
	hud.show_stage_banner(last_stage)


func _process(delta: float) -> void:
	if game_ended:
		return
	time_survived += delta
	if time_survived >= RUN_DURATION:
		_end_run(true)
		return

	_spawn_timer_update(delta)
	_update_boss_schedule()
	_update_stage()
	_update_hud()


func _spawn_timer_update(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var interval := maxf(0.22, 0.92 - time_survived / 950.0)
	spawn_timer += interval
	var enemy_cap := mini(190, 75 + int(time_survived / 6.0))
	if enemies.get_child_count() >= enemy_cap:
		return
	var batch := mini(7, 1 + int(time_survived / 95.0))
	for _index in range(batch):
		spawn_enemy(_pick_enemy_type(), false)


func _pick_enemy_type() -> String:
	var choices: Array[String] = ["prowler", "prowler", "prowler"]
	if time_survived >= 35.0:
		choices.append_array(["bat", "bat"])
	if time_survived >= 80.0:
		choices.append("mage")
	if time_survived >= 145.0:
		choices.append("brute")
	if time_survived >= 220.0:
		choices.append_array(["ember", "ember"])
	if time_survived >= 400.0:
		choices.append_array(["brute", "mage", "ember"])
	return choices.pick_random()


func spawn_enemy(kind: String, force_elite := false) -> Node:
	if game_ended or not is_instance_valid(player):
		return null
	var enemy = EnemyScene.instantiate()
	var difficulty := 1.0 + time_survived / 250.0
	var elite_chance := clampf(0.025 + time_survived / 6000.0, 0.025, 0.13)
	var is_elite := force_elite or (kind != "void_knight" and randf() < elite_chance)
	enemy.setup(kind, difficulty, is_elite, self)
	enemies.add_child(enemy)
	enemy.global_position = get_spawn_position()
	return enemy


func get_spawn_position(minimum := 610.0, maximum := 760.0) -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	var angle := randf() * TAU
	return player.global_position + Vector2.RIGHT.rotated(angle) * randf_range(minimum, maximum)


func _update_boss_schedule() -> void:
	if boss_index >= BOSS_TIMES.size() or time_survived < BOSS_TIMES[boss_index]:
		return
	active_boss = spawn_enemy("void_knight")
	if active_boss:
		active_boss.max_hp *= 1.0 + boss_index * 0.65
		active_boss.hp = active_boss.max_hp
		active_boss.health_bar.max_value = active_boss.max_hp
		active_boss.health_bar.value = active_boss.hp
		hud.show_boss("ARAUTO DO VAZIO · ECO %d" % (boss_index + 1), active_boss.hp, active_boss.max_hp)
		hud.show_stage_banner("UM CHEFE ATRAVESSOU O VÉU")
	boss_index += 1


func _update_stage() -> void:
	var current_stage := GameDefs.stage_name(time_survived)
	if current_stage != last_stage:
		last_stage = current_stage
		hud.show_stage_banner(current_stage)
		for _index in range(3):
			spawn_enemy("brute", true)


func _update_hud() -> void:
	var remaining := maxf(0.0, RUN_DURATION - time_survived)
	hud.update_run(
		player.hp, player.max_hp, player.experience, player.experience_needed,
		player.level, enemies_killed, remaining, last_stage, player.weapon_summary()
	)
	if is_instance_valid(active_boss) and not active_boss.dead:
		hud.update_boss(active_boss.hp, active_boss.max_hp)
	else:
		hud.hide_boss()


func handle_enemy_death(enemy: Node, xp_value: int, was_elite: bool, was_boss: bool) -> void:
	enemies_killed += 1
	var gem = GemScene.instantiate()
	pickups.add_child(gem)
	gem.setup(xp_value, enemy.global_position, "xp")
	var death_color: Color = GameDefs.enemy_data(enemy.enemy_type).color
	spawn_effect(enemy.global_position, death_color, enemy.hit_radius * 2.2, 0.32, true)
	if (was_elite and randf() < 0.35) or (not was_elite and randf() < 0.018):
		var heart = GemScene.instantiate()
		pickups.add_child(heart)
		heart.setup(24 if not was_boss else 60, enemy.global_position + Vector2(18, 0), "heal")
	if was_boss:
		active_boss = null
		for _index in range(8):
			var bonus = GemScene.instantiate()
			pickups.add_child(bonus)
			bonus.setup(12, enemy.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20.0, 80.0), "xp")
		hud.show_stage_banner("ARAUTO BANIDO · PODER LIBERADO")


func add_player_projectile(projectile: Node) -> void:
	projectiles.add_child(projectile)


func add_enemy_projectile(projectile: Node) -> void:
	enemy_projectiles.add_child(projectile)


func spawn_effect(position: Vector2, color: Color, radius: float, duration := 0.35, filled := false) -> void:
	var effect = EffectScript.new()
	effects.add_child(effect)
	effect.setup(position, color, radius, duration, filled)


func on_player_damaged() -> void:
	hud.flash_damage()
	var camera: Camera2D = player.get_node("Camera2D")
	var original := camera.offset
	camera.offset = Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))
	var tween := create_tween()
	tween.tween_property(camera, "offset", original, 0.18)


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
	_save_record(victory)
	hud.show_end_screen(victory, time_survived, enemies_killed, player.level)


func _save_record(victory: bool) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var best_time := float(config.get_value("record", "best_time", 0.0))
	var best_kills := int(config.get_value("record", "best_kills", 0))
	config.set_value("record", "best_time", maxf(best_time, time_survived))
	config.set_value("record", "best_kills", maxi(best_kills, enemies_killed))
	config.set_value("record", "victories", int(config.get_value("record", "victories", 0)) + (1 if victory else 0))
	config.save(SAVE_PATH)


func _restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _resume_run() -> void:
	if not upgrade_active and not game_ended:
		get_tree().paused = false


func _generate_environment() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 864210
	var texture_paths := [
		"res://assets/environment/Tree/Tree_1.png",
		"res://assets/environment/Tree/Tree_2.png",
		"res://assets/environment/Tree/Tree_3.png",
		"res://assets/environment/props/bush/bush_01.png",
		"res://assets/environment/props/bush/bush_02.png",
		"res://assets/environment/props/Mushroom/Mushroom_03.png",
		"res://assets/environment/props/little stone/little stone_03.png"
	]
	var textures: Array[Texture2D] = []
	for path in texture_paths:
		textures.append(load(path))
	for index in range(310):
		var sprite := Sprite2D.new()
		sprite.texture = textures[rng.randi_range(0, textures.size() - 1)]
		var position := Vector2(rng.randf_range(-5400.0, 5400.0), rng.randf_range(-5400.0, 5400.0))
		if position.length() < 310.0:
			position = position.normalized() * rng.randf_range(340.0, 700.0)
		sprite.position = position
		var scale_value := rng.randf_range(0.65, 1.15)
		sprite.scale = Vector2.ONE * scale_value
		sprite.flip_h = rng.randf() < 0.5
		sprite.modulate = Color(0.70, 0.78, 0.74, rng.randf_range(0.42, 0.82))
		sprite.z_index = -4
		decorations.add_child(sprite)
