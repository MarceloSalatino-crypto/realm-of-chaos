extends RefCounted

const CampaignCatalogScript = preload("res://scripts/campaign_catalog.gd")
const CampaignManagerScript = preload("res://scripts/campaign_manager.gd")
const SaveStoreScript = preload("res://scripts/save_store.gd")

var world
var save_path: String
var load_status := SaveStoreScript.STATUS_OK
var load_warning := ""
var write_failed := false
var last_write_error := OK
var campaign_manager: Node


func _init(owner_world, persistence_path: String) -> void:
	world = owner_world
	save_path = persistence_path
	campaign_manager = world.get_node_or_null("/root/CampaignManager")
	if campaign_manager == null:
		# Permite executar testes de script fora da árvore principal sem depender
		# do registro dos autoloads do ProjectSettings.
		campaign_manager = CampaignManagerScript.new()


func evaluate_achievements(victory: bool) -> Array[String]:
	var config := _load_config()
	var newly_unlocked := _apply_achievements(config, victory)
	if world.suppress_save or newly_unlocked.is_empty():
		return newly_unlocked
	if _save_config(config) != OK:
		return []
	var verified := SaveStoreScript.load_config(save_path, false)
	if str(verified.status) != SaveStoreScript.STATUS_OK:
		return []
	return _confirmed_achievement_titles(verified.config, newly_unlocked)


func _apply_achievements(config: ConfigFile, victory: bool) -> Array[String]:
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
	var newly_unlocked: Array[String] = []
	for definition in GameDefs.achievements():
		var achievement_id := str(definition.id)
		if not achievement_id in earned_ids or bool(config.get_value("achievements", achievement_id, false)):
			continue
		newly_unlocked.append(str(definition.title))
		config.set_value("achievements", achievement_id, true)
	return newly_unlocked


func save_record(victory: bool) -> Dictionary:
	var campaign_result := _empty_campaign_result()
	if world.suppress_save:
		return campaign_result
	var config := _load_config()
	var previous_unlocked: Array[String] = []
	if victory:
		campaign_manager.load_progress(save_path, false)
		previous_unlocked = campaign_manager.unlocked_maps.duplicate()
		campaign_manager.apply_completion(config, world.campaign_map_id)
	_apply_run_record(config, victory)
	var save_error := _save_config(config)
	if save_error != OK:
		campaign_manager.load_progress(save_path, false)
		return campaign_result
	var verified := SaveStoreScript.load_config(save_path, false)
	if str(verified.status) != SaveStoreScript.STATUS_OK:
		_mark_verification_failure(int(verified.error))
		campaign_manager.load_progress(save_path, false)
		return campaign_result
	campaign_manager.load_progress(save_path, false)
	return _confirmed_campaign_result(victory, previous_unlocked)


func finalize_run(victory: bool) -> Dictionary:
	var result := {
		"saved": false,
		"save_error": OK,
		"new_achievements": Array([], TYPE_STRING, "", null),
		"campaign_result": _empty_campaign_result(),
		"confirmed_essence_earned": 0,
		"confirmed_record": {},
	}
	if world.suppress_save:
		# Laboratórios e testes isolados pulam persistência por design; isso não é
		# uma falha de gravação e não deve produzir um falso aviso para o jogador.
		result.saved = true
		return result
	write_failed = false
	last_write_error = OK
	var config := _load_config()
	var previous_essence := int(config.get_value("meta", "essence", 0))
	campaign_manager.load_progress(save_path, false)
	var previous_unlocked: Array[String] = campaign_manager.unlocked_maps.duplicate()
	var candidate_achievements := _apply_achievements(config, victory)
	_apply_run_record(config, victory)
	if victory:
		campaign_manager.apply_completion(config, world.campaign_map_id)
	var save_error := _save_config(config)
	if save_error != OK:
		result.save_error = save_error
		campaign_manager.load_progress(save_path, false)
		return result
	var verified := SaveStoreScript.load_config(save_path, false)
	if str(verified.status) != SaveStoreScript.STATUS_OK:
		var verification_error := int(verified.error)
		_mark_verification_failure(verification_error)
		result.save_error = verification_error
		campaign_manager.load_progress(save_path, false)
		return result
	campaign_manager.load_progress(save_path, false)
	var confirmed_campaign := _confirmed_campaign_result(victory, previous_unlocked)
	result.saved = true
	result.new_achievements = _confirmed_achievement_titles(verified.config, candidate_achievements)
	result.campaign_result = confirmed_campaign
	result.confirmed_essence_earned = maxi(
		0, int(verified.config.get_value("meta", "essence", previous_essence)) - previous_essence
	)
	result.confirmed_record = {
		"best_time": float(verified.config.get_value("record", "best_time", 0.0)),
		"best_kills": int(verified.config.get_value("record", "best_kills", 0)),
		"victories": int(verified.config.get_value("record", "victories", 0)),
		"total_essence": int(verified.config.get_value("meta", "essence", previous_essence)),
	}
	return result


func _apply_run_record(config: ConfigFile, victory: bool) -> void:
	var best_time := float(config.get_value("record", "best_time", 0.0))
	var best_kills := int(config.get_value("record", "best_kills", 0))
	config.set_value("record", "best_time", maxf(best_time, world.time_survived))
	config.set_value("record", "best_kills", maxi(best_kills, world.enemies_killed))
	config.set_value("record", "victories", int(config.get_value("record", "victories", 0)) + (1 if victory else 0))
	config.set_value("meta", "essence", int(config.get_value("meta", "essence", 0)) + world.essence_earned)


func _confirmed_campaign_result(victory: bool, previous_unlocked: Array[String]) -> Dictionary:
	var result := _empty_campaign_result()
	result.saved = true
	if not victory or world.campaign_map_id not in campaign_manager.completed_maps:
		return result
	result.completed_map_id = world.campaign_map_id
	var next_id := CampaignCatalogScript.next_map_id(world.campaign_map_id)
	result.next_map_id = next_id
	if not next_id.is_empty() and next_id in campaign_manager.unlocked_maps and next_id not in previous_unlocked:
		result.unlocked_map_id = next_id
	var next_definition := CampaignCatalogScript.map_data(next_id)
	result.next_coming_soon = (
		not next_definition.is_empty()
		and not bool(next_definition.get("content_ready", false))
	)
	return result


func _confirmed_achievement_titles(config: ConfigFile, candidate_titles: Array[String]) -> Array[String]:
	var confirmed: Array[String] = []
	for definition in GameDefs.achievements():
		var title := str(definition.title)
		if title in candidate_titles and bool(config.get_value("achievements", str(definition.id), false)):
			confirmed.append(title)
	return confirmed


func _empty_campaign_result() -> Dictionary:
	return {
		"completed_map_id": "",
		"unlocked_map_id": "",
		"next_map_id": CampaignCatalogScript.next_map_id(world.campaign_map_id),
		"next_coming_soon": false,
		"saved": false,
	}


func _mark_verification_failure(error: int) -> void:
	write_failed = true
	last_write_error = error if error != OK else ERR_FILE_CORRUPT
	push_warning("O save gravado não pôde ser confirmado (erro %d)." % last_write_error)


func load_progression() -> void:
	var config := _load_config()
	campaign_manager.load_progress(save_path, false)
	var map_definition: Dictionary
	if not world.campaign_map_override_id.is_empty():
		map_definition = CampaignCatalogScript.map_data(world.campaign_map_override_id)
	else:
		map_definition = campaign_manager.selected_map()
	if map_definition.is_empty() or not bool(map_definition.get("content_ready", false)):
		map_definition = CampaignCatalogScript.map_data(CampaignCatalogScript.first_map_id())
	world.campaign_map = map_definition
	world.campaign_map_id = str(map_definition.id)
	world.map_seed_offset = int(map_definition.get("seed_offset", 0))
	world.map_boss_power = float(map_definition.get("boss_power", 1.0))
	world.run_cycle = world.map_seed_offset
	world.biome = GameDefs.biome_data_by_id(str(map_definition.biome_id))
	world.biome.enemy_power = float(map_definition.get("enemy_power", world.biome.enemy_power))
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


func _load_config() -> ConfigFile:
	var result := SaveStoreScript.load_config(save_path, not world.suppress_save)
	var status := str(result.status)
	if status in [SaveStoreScript.STATUS_RECOVERED, SaveStoreScript.STATUS_FAILED]:
		load_status = status
		load_warning = str(result.message)
		push_warning(load_warning)
	return result.config


func _save_config(config: ConfigFile) -> Error:
	var save_error := SaveStoreScript.save_config(config, save_path)
	if save_error != OK:
		write_failed = true
		last_write_error = save_error
		push_warning("Não foi possível salvar o progresso (erro %d)." % save_error)
	return save_error
