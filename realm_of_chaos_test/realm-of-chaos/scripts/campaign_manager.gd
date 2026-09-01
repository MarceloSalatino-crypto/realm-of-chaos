extends Node

const CampaignCatalogScript = preload("res://scripts/campaign_catalog.gd")
const SaveStoreScript = preload("res://scripts/save_store.gd")
const SAVE_PATH := "user://realm_of_chaos.cfg"
const SCHEMA_VERSION := 1

const STATUS_LOCKED := "locked"
const STATUS_AVAILABLE := "available"
const STATUS_COMPLETED := "completed"
const STATUS_COMING_SOON := "coming_soon"

var selected_map_id := ""
var unlocked_maps: Array[String] = []
var completed_maps: Array[String] = []
var save_path := SAVE_PATH
var load_status := SaveStoreScript.STATUS_MISSING
var load_message := ""
var last_error := OK


func _ready() -> void:
	CampaignCatalogScript.assert_valid_catalog()
	# A carga é deliberadamente somente em memória. Menu/campanha decidem quando
	# uma migração pode ser persistida; testes e laboratórios nunca escrevem aqui.
	load_progress(save_path, false)


func load_progress(path := SAVE_PATH, persist_migration := false) -> Dictionary:
	save_path = path
	var result := SaveStoreScript.load_config(path, persist_migration)
	load_status = str(result.status)
	load_message = str(result.message)
	var config: ConfigFile = result.config
	var migrated := not config.has_section("campaign")
	if migrated:
		_migrate_legacy(config)
	else:
		_read_campaign(config)
	_normalize_progress()
	_write_campaign(config)
	last_error = OK
	if persist_migration and (migrated or str(result.status) == SaveStoreScript.STATUS_MISSING):
		last_error = SaveStoreScript.save_config(config, path)
	return {
		"config": config,
		"migrated": migrated,
		"status": load_status,
		"message": load_message,
		"error": last_error,
	}


func persist_selection(map_id: String) -> bool:
	if not can_start_map(map_id):
		return false
	var result := SaveStoreScript.load_config(save_path)
	var config: ConfigFile = result.config
	if not config.has_section("campaign"):
		_migrate_legacy(config)
	else:
		_read_campaign(config)
	selected_map_id = map_id
	_normalize_progress()
	_write_campaign(config)
	last_error = SaveStoreScript.save_config(config, save_path)
	if last_error != OK:
		load_progress(save_path, false)
	return last_error == OK


func select_map_in_memory(map_id: String, allow_unavailable := false) -> bool:
	if CampaignCatalogScript.map_data(map_id).is_empty():
		return false
	if not allow_unavailable and not can_start_map(map_id):
		return false
	selected_map_id = map_id
	return true


func selected_map() -> Dictionary:
	var definition := CampaignCatalogScript.map_data(selected_map_id)
	if definition.is_empty() or not bool(definition.get("content_ready", false)):
		definition = CampaignCatalogScript.map_data(CampaignCatalogScript.first_map_id())
	return definition


func map_status(map_id: String) -> String:
	var definition := CampaignCatalogScript.map_data(map_id)
	if definition.is_empty():
		return STATUS_LOCKED
	if not bool(definition.get("content_ready", false)):
		return STATUS_COMING_SOON
	if map_id in completed_maps:
		return STATUS_COMPLETED
	if map_id in unlocked_maps and _requirement_met(definition):
		return STATUS_AVAILABLE
	return STATUS_LOCKED


func can_start_map(map_id: String) -> bool:
	var status := map_status(map_id)
	return status == STATUS_AVAILABLE or status == STATUS_COMPLETED


func apply_completion(config: ConfigFile, map_id: String) -> Dictionary:
	if not config.has_section("campaign"):
		_migrate_legacy(config)
	else:
		_read_campaign(config)
	var definition := CampaignCatalogScript.map_data(map_id)
	if (
		definition.is_empty()
		or not bool(definition.get("content_ready", false))
		or map_id not in unlocked_maps
		or not _requirement_met(definition)
	):
		_normalize_progress()
		_write_campaign(config)
		return {"completed_map_id": "", "unlocked_map_id": "", "next_coming_soon": false}
	if map_id not in completed_maps:
		completed_maps.append(map_id)
	if map_id not in unlocked_maps:
		unlocked_maps.append(map_id)
	var next_id := CampaignCatalogScript.next_map_id(map_id)
	var newly_unlocked := ""
	if not next_id.is_empty() and next_id not in unlocked_maps:
		unlocked_maps.append(next_id)
		newly_unlocked = next_id
	_normalize_progress()
	_write_campaign(config)
	var next_definition := CampaignCatalogScript.map_data(next_id)
	return {
		"completed_map_id": map_id,
		"unlocked_map_id": newly_unlocked,
		"next_map_id": next_id,
		"next_coming_soon": not next_definition.is_empty() and not bool(next_definition.get("content_ready", false)),
	}


func reset_campaign_progress(path := SAVE_PATH) -> Error:
	save_path = path
	var result := SaveStoreScript.load_config(path)
	var config: ConfigFile = result.config
	selected_map_id = CampaignCatalogScript.first_map_id()
	unlocked_maps = [selected_map_id]
	completed_maps.clear()
	_write_campaign(config)
	last_error = SaveStoreScript.save_config(config, path)
	return last_error


func _migrate_legacy(config: ConfigFile) -> void:
	var legacy_cycle := maxi(
		int(config.get_value("progress", "active_cycle", 0)),
		int(config.get_value("progress", "highest_cycle", 0))
	)
	completed_maps.clear()
	for order in range(1, mini(legacy_cycle, 3) + 1):
		var definition := CampaignCatalogScript.map_by_order(order)
		if not definition.is_empty():
			completed_maps.append(str(definition.id))
	unlocked_maps = completed_maps.duplicate()
	var next_order := mini(completed_maps.size() + 1, CampaignCatalogScript.MAPS.size())
	var next_definition := CampaignCatalogScript.map_by_order(next_order)
	if not next_definition.is_empty():
		unlocked_maps.append(str(next_definition.id))
	var selected_order := clampi(legacy_cycle + 1, 1, 3)
	selected_map_id = str(CampaignCatalogScript.map_by_order(selected_order).id)


func _read_campaign(config: ConfigFile) -> void:
	selected_map_id = str(config.get_value("campaign", "selected_map_id", CampaignCatalogScript.first_map_id()))
	unlocked_maps = _string_array(config.get_value("campaign", "unlocked_maps", PackedStringArray()))
	completed_maps = _string_array(config.get_value("campaign", "completed_maps", PackedStringArray()))


func _write_campaign(config: ConfigFile) -> void:
	config.set_value("campaign", "schema_version", SCHEMA_VERSION)
	config.set_value("campaign", "selected_map_id", selected_map_id)
	config.set_value("campaign", "unlocked_maps", PackedStringArray(unlocked_maps))
	config.set_value("campaign", "completed_maps", PackedStringArray(completed_maps))


func _normalize_progress() -> void:
	var known_ids := CampaignCatalogScript.known_map_ids()
	var requested_completed := _unique_known(completed_maps, known_ids)
	completed_maps.clear()
	for definition in CampaignCatalogScript.MAPS:
		var map_id := str(definition.id)
		if map_id in requested_completed and _requirement_met(definition):
			completed_maps.append(map_id)
	var first_id := CampaignCatalogScript.first_map_id()
	unlocked_maps = [first_id]
	for definition in CampaignCatalogScript.MAPS:
		var map_id := str(definition.id)
		if map_id == first_id:
			continue
		if _requirement_met(definition):
			unlocked_maps.append(map_id)
	if selected_map_id not in known_ids:
		selected_map_id = first_id
	if selected_map_id not in unlocked_maps:
		selected_map_id = first_id


func _requirement_met(definition: Dictionary) -> bool:
	var requirement: Dictionary = definition.get("unlock_requirement", {})
	if requirement.is_empty():
		return true
	if str(requirement.get("type", "")) == "complete_map":
		return str(requirement.get("map_id", "")) in completed_maps
	return false


func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is PackedStringArray or value is Array:
		for entry in value:
			result.append(str(entry))
	return result


func _unique_known(values: Array[String], known_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for map_id in values:
		if map_id in known_ids and map_id not in result:
			result.append(map_id)
	return result
