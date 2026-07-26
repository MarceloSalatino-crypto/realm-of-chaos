extends RefCounted

const GameDefs = preload("res://scripts/game_defs.gd")

var world
var save_path: String


func _init(owner_world, persistence_path: String) -> void:
	world = owner_world
	save_path = persistence_path


func evaluate_achievements(victory: bool) -> Array[String]:
	var earned_ids: Array[String] = []
	if world.bosses_defeated >= 1:
		earned_ids.append("first_boss")
	if world.bosses_defeated >= 5:
		earned_ids.append("boss_slayer")
	if victory:
		earned_ids.append("survivor")
	if world.enemies_killed >= 500:
		earned_ids.append("exterminator")
	if world.player.all_weapons_evolved():
		earned_ids.append("arsenal")
	if victory and world.damage_taken <= 100.0:
		earned_ids.append("untouchable")
	if world.shrines_activated >= 4:
		earned_ids.append("cartographer")
	var config := ConfigFile.new()
	config.load(save_path)
	var newly_unlocked: Array[String] = []
	for definition in GameDefs.achievements():
		var achievement_id := str(definition.id)
		if not achievement_id in earned_ids or bool(config.get_value("achievements", achievement_id, false)):
			continue
		newly_unlocked.append(str(definition.title))
		config.set_value("achievements", achievement_id, true)
	if not world.suppress_save:
		config.save(save_path)
	return newly_unlocked


func save_record(victory: bool) -> void:
	if world.suppress_save:
		return
	var config := ConfigFile.new()
	config.load(save_path)
	var best_time := float(config.get_value("record", "best_time", 0.0))
	var best_kills := int(config.get_value("record", "best_kills", 0))
	config.set_value("record", "best_time", maxf(best_time, world.time_survived))
	config.set_value("record", "best_kills", maxi(best_kills, world.enemies_killed))
	config.set_value("record", "victories", int(config.get_value("record", "victories", 0)) + (1 if victory else 0))
	config.set_value("meta", "essence", int(config.get_value("meta", "essence", 0)) + world.essence_earned)
	if victory:
		config.set_value("progress", "active_cycle", world.run_cycle + 1)
		config.set_value("progress", "highest_cycle", maxi(world.run_cycle + 1, int(config.get_value("progress", "highest_cycle", 0))))
	config.save(save_path)


func load_progression() -> void:
	var config := ConfigFile.new()
	config.load(save_path)
	world.run_cycle = int(config.get_value("progress", "active_cycle", 0))
	world.biome = GameDefs.biome_data(world.run_cycle)
	var meta := {
		"power": int(config.get_value("meta", "power", 0)),
		"vitality": int(config.get_value("meta", "vitality", 0)),
		"speed": int(config.get_value("meta", "speed", 0)),
		"fortune": int(config.get_value("meta", "fortune", 0))
	}
	world.player.apply_meta_bonuses(meta)
	world.player.apply_character(str(config.get_value("profile", "character", "eclipse_hunter")))
	world.accessibility_settings = GameDefs.default_settings()
	for setting_id in world.accessibility_settings:
		world.accessibility_settings[setting_id] = config.get_value("settings", setting_id, world.accessibility_settings[setting_id])
	world.audio.set_levels(float(world.accessibility_settings.music), float(world.accessibility_settings.sfx))
	world.hud.set_accessibility(float(world.accessibility_settings.flash))
