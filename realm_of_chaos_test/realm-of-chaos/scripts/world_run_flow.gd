extends RefCounted

const RewardChestScript = preload("res://scripts/reward_chest.gd")
const COMPLETE_BUILD_CHEST_CHANCE := 0.30

var world


func _init(owner_world) -> void:
	world = owner_world


func update_hud() -> void:
	var remaining := maxf(0.0, world.RUN_DURATION - world.time_survived)
	var environment: Dictionary = world.environment_builder.get_environment_effect(world.player.global_position)
	var passive_status := "%s · %ds" % [world.player.blessing_title, ceili(world.player.blessing_time)] if world.player.blessing_time > 0.0 else str(environment.get("name", ""))
	var status_title: String = world.current_event_title if not world.current_event_title.is_empty() else passive_status
	var stage_status := "%s · %s" % [world.last_stage, world.director.next_boss_status()]
	world.hud.update_run(
		world.player.hp, world.player.max_hp, world.player.experience, world.player.experience_needed,
		world.player.level, world.enemies_killed, remaining, stage_status,
		world.essence_earned, status_title
	)
	world.hud.update_navigation(
		world.player.dash_cooldown_progress(), world.player.character_id,
		world.player.character_skill_name
	)
	if is_instance_valid(world.active_boss) and not world.active_boss.dead:
		world.hud.update_boss(world.active_boss.hp, world.active_boss.max_hp)
	else:
		world.hud.hide_boss()


func handle_enemy_death(enemy: Node, xp_value: int, was_elite: bool, was_boss: bool) -> void:
	world.enemies_killed += 1
	var build_complete: bool = world.player.is_build_complete()
	if was_boss:
		world.essence_earned += 50 if enemy.final_boss else 18
	elif was_elite:
		world.essence_earned += 3
	elif world.enemies_killed % 7 == 0:
		world.essence_earned += 1
	if build_complete:
		world.player.collect_xp(xp_value)
	else:
		world._spawn_pickup(xp_value, enemy.global_position, "xp")
	var death_color: Color = GameDefs.enemy_data(enemy.enemy_type).color
	world.spawn_effect(enemy.global_position, death_color, enemy.hit_radius * 2.2, 0.32, true)
	if (was_elite and randf() < 0.35) or (not was_elite and randf() < 0.018):
		world._spawn_pickup(24 if not was_boss else 60, enemy.global_position + Vector2(18, 0), "heal")
	if not was_boss:
		return
	world.bosses_defeated += 1
	if world.active_boss == enemy:
		world.active_boss = null
		if is_instance_valid(world.active_boss_arena):
			world.active_boss_arena.finish()
			world.active_boss_arena = null
	var extra_xp_count := 10 if enemy.final_boss else 7
	var extra_xp_value := 18 if enemy.final_boss else 12
	if build_complete:
		world.player.collect_xp(extra_xp_count * extra_xp_value)
	else:
		for index in range(extra_xp_count):
			world._spawn_pickup(
				extra_xp_value,
				enemy.global_position + Vector2.RIGHT.rotated(TAU * index / 10.0) * randf_range(28.0, 92.0),
				"xp"
			)
	world.player.grant_boss_reward(enemy.final_boss)
	shake_camera(12.0, 0.55)
	if enemy.final_boss:
		world.hud.show_stage_banner("SOBERANO DERROTADO · PRÓXIMA FASE DESBLOQUEADA")
		world.call_deferred("_end_run", true)
	else:
		if should_spawn_reward_chest(build_complete):
			spawn_reward_chest(enemy.global_position, str(GameDefs.enemy_data(enemy.enemy_type).name))
			world.hud.show_stage_banner("MINI-CHEFE BANIDO · O BAÚ DO RITUAL SURGIU")
		else:
			world.hud.show_stage_banner("MINI-CHEFE BANIDO · O RITUAL CONTINUA")
		world.audio.set_music_stage(str(GameDefs.difficulty_data(world.time_survived).id))


func should_spawn_reward_chest(build_complete: bool, chance_roll := -1.0) -> bool:
	if not build_complete:
		return true
	var resolved_roll := randf() if chance_roll < 0.0 else chance_roll
	return resolved_roll < COMPLETE_BUILD_CHEST_CHANCE


func spawn_reward_chest(chest_position: Vector2, boss_name: String) -> Node:
	var chest = RewardChestScript.new()
	world.rewards.add_child(chest)
	chest.setup(world, chest_position, boss_name)
	world.spawn_effect(chest_position, Color("d99cff"), 125.0, 0.75, true)
	return chest


func open_reward_chest(chest: Node) -> void:
	if world.game_ended or world.pending_chest != null or not is_instance_valid(chest):
		return
	world.pending_chest = chest
	var options: Array[Dictionary] = world.player.get_relic_options(3)
	if options.is_empty():
		world.player.grant_boss_reward(false)
		chest.queue_free()
		world.pending_chest = null
		return
	world.get_tree().paused = true
	world.hud.show_relic_choice(options, str(chest.source_boss))
	world.audio.play_reward()


func on_relic_selected(relic_id: String) -> void:
	if world.pending_chest == null:
		return
	var selected_title := relic_id
	for definition in GameDefs.relics():
		if str(definition.id) == relic_id:
			selected_title = str(definition.title)
			break
	world.player.apply_relic(relic_id)
	world.hud.hide_relic_choice()
	world.hud.show_stage_banner("RELÍQUIA ABSORVIDA · %s" % selected_title)
	world.spawn_effect(world.player.global_position, Color("ffd36b"), 180.0, 0.70, true)
	if is_instance_valid(world.pending_chest):
		world.pending_chest.queue_free()
	world.pending_chest = null
	world.get_tree().paused = false


func on_enemy_hit(position: Vector2, amount: float, critical: bool, is_boss: bool) -> void:
	world.spawn_damage_number(position, amount, critical)
	world.audio.play_hit(critical)
	if critical:
		world.spawn_effect(position, Color("ffd86b"), 30.0, 0.16, true)
	if critical and is_boss:
		shake_camera(3.5, 0.10)


func on_weapon_evolved(title: String) -> void:
	world.hud.show_stage_banner("EVOLUÇÃO · %s" % title)
	world.audio.play_evolution()
	shake_camera(7.0, 0.32)
	world.spawn_effect(world.player.global_position, Color("ffd36b"), 210.0, 0.72, true)


func on_boss_phase_changed(enemy: Node, phase: int) -> void:
	if world.active_boss == enemy:
		world.hud.show_stage_banner("%s · FASE %d" % [str(GameDefs.enemy_data(enemy.enemy_type).name), phase])
		world.hud.set_boss_phase(phase)
		shake_camera(8.0, 0.28)
		if is_instance_valid(world.active_boss_arena):
			world.active_boss_arena.set_phase(phase)


func on_player_damaged() -> void:
	world.hud.flash_damage(float(world.accessibility_settings.get("flash", 0.7)))
	world.audio.play_player_hurt()
	shake_camera(7.0, 0.18)


func on_player_revived() -> void:
	world.hud.show_stage_banner("PLUMA DA FÊNIX · VOCÊ RETORNOU")
	world.spawn_effect(world.player.global_position, Color("ffb35a"), 240.0, 1.0, true)
	world.audio.play_player_revive()


func on_player_dash(direction: Vector2) -> void:
	world.spawn_effect(world.player.global_position - direction * 18.0, Color("9d72ff"), 58.0, 0.22, true)
	world.audio.play_dash()
	shake_camera(1.8, 0.10)


func on_weapon_fired(weapon_id: String) -> void:
	if is_instance_valid(world.audio) and world.audio.has_method("play_weapon_attack"):
		world.audio.play_weapon_attack(weapon_id)


func activate_landmark(landmark: Node) -> void:
	if not is_instance_valid(landmark) or landmark.activated or world.game_ended:
		return
	var landmark_color: Color = landmark.minimap_color()
	landmark.mark_activated()
	world.shrines_activated += 1
	world.essence_earned += 4
	var blessing_name: String = world.player.apply_landmark_blessing(str(landmark.landmark_kind), 40.0)
	if str(landmark.landmark_kind) == "tree":
		for pickup in world.pickups.get_children():
			if is_instance_valid(pickup) and pickup.global_position.distance_to(world.player.global_position) <= 1450.0:
				pickup.attracted = true
	world.hud.show_stage_banner("SANTUÁRIO ATIVADO · %s · 40 SEGUNDOS" % blessing_name)
	world.spawn_effect(landmark.global_position, landmark_color, 225.0, 0.90, true)
	world.audio.play_shrine_activate()
	shake_camera(4.0, 0.22)


func record_damage(source_id: String, amount: float, target_is_boss := false) -> void:
	world.damage_by_source[source_id] = float(world.damage_by_source.get(source_id, 0.0)) + amount
	if is_instance_valid(world.player):
		world.player.on_damage_dealt(amount, target_is_boss)


func record_player_damage(amount: float) -> void:
	world.damage_taken += amount


func shake_camera(strength: float, duration := 0.18) -> void:
	if not is_instance_valid(world.player):
		return
	strength *= float(world.accessibility_settings.get("shake", 0.75))
	if strength <= 0.01:
		return
	var player_camera: Camera2D = world.player.get_node("Camera2D")
	var original := Vector2.ZERO
	player_camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	var tween: Tween = world.create_tween()
	tween.tween_property(player_camera, "offset", original, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func on_level_up_requested() -> void:
	world.pending_upgrades += 1
	if not world.upgrade_active:
		world.call_deferred("_show_next_upgrade")


func show_next_upgrade() -> void:
	if world.pending_upgrades <= 0 or world.game_ended:
		return
	world.upgrade_active = true
	world.get_tree().paused = true
	present_upgrade_options(world.player.get_upgrade_options(3))


func present_upgrade_options(options: Array[Dictionary]) -> void:
	if not options.is_empty():
		world.hud.show_level_up(world.player.level, options)
		return
	world.player.heal(world.player.max_hp * 0.15)
	world.essence_earned += 2
	world.hud.hide_level_up()
	world.hud.show_stage_banner("ASCENSÃO COMPLETA · VIDA RESTAURADA · +2 ESSÊNCIAS")
	advance_upgrade_queue()


func on_upgrade_selected(upgrade_id: String, rarity: String) -> void:
	if not world.upgrade_active or world.pending_upgrades <= 0:
		return
	world.player.apply_upgrade(upgrade_id, rarity)
	advance_upgrade_queue()


func advance_upgrade_queue() -> void:
	world.pending_upgrades -= 1
	if world.pending_upgrades > 0:
		present_upgrade_options(world.player.get_upgrade_options(3))
	else:
		world.upgrade_active = false
		world.hud.hide_level_up()
		world.get_tree().paused = false


func on_player_died() -> void:
	end_run(false)


func end_run(victory: bool) -> void:
	if world.game_ended:
		return
	world.game_ended = true
	world.get_tree().paused = true
	var new_achievements: Array[String] = world._evaluate_achievements(victory)
	world._save_record(victory)
	var next_biome := str(GameDefs.biome_data(world.run_cycle + 1).name) if victory else str(world.biome.name)
	var final_stats := run_stats_text()
	if world.persistence.write_failed:
		final_stats += "\n\nAVISO · NÃO FOI POSSÍVEL SALVAR O PROGRESSO.\nSeu save anterior e o backup foram mantidos."
	world.hud.show_end_screen(
		victory, world.time_survived, world.enemies_killed, world.player.level,
		world.essence_earned, next_biome, final_stats, new_achievements
	)


func run_stats_text() -> String:
	var total_damage := 0.0
	var top_source := ""
	var top_damage := 0.0
	for source_id in world.damage_by_source:
		var amount := float(world.damage_by_source[source_id])
		total_damage += amount
		if amount > top_damage:
			top_damage = amount
			top_source = str(source_id)
	var top_title := weapon_title(top_source) if not top_source.is_empty() else "Nenhuma"
	return "Dano causado  %d\nMaior fonte  %s (%d)\nDano recebido  %d\nChefes derrotados  %d/5 · Santuários  %d/4\nRelíquias  %s" % [
		ceili(total_damage), top_title, ceili(top_damage), ceili(world.damage_taken),
		world.bosses_defeated, world.shrines_activated, world.player.relic_summary()
	]


func weapon_title(source_id: String) -> String:
	var special_titles := {
		"hunter_skill": "Rajada do Eclipse", "oracle_skill": "Pulso Glacial",
		"knight_skill": "Contra-ataque Rubro", "automaton_skill": "Sobrecarga Arcana"
	}
	if special_titles.has(source_id):
		return str(special_titles[source_id])
	for definition in GameDefs.upgrades():
		if str(definition.id) == source_id:
			return str(definition.title)
	return source_id.capitalize()


func restart_run() -> void:
	world.get_tree().paused = false
	world.get_tree().reload_current_scene()


func return_to_menu() -> void:
	world.get_tree().paused = false
	world.get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func resume_run() -> void:
	if not world.upgrade_active and not world.game_ended:
		world.get_tree().paused = false
