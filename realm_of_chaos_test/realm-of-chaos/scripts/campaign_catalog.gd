extends RefCounted

const MapEncounterCatalogScript = preload("res://scripts/map_encounter_catalog.gd")

const WORLD_SCENE := "res://scenes/world.tscn"
const PLACEHOLDER_PREVIEW := "res://assets/generated/corrupted_forest_ground.png"

const MAPS: Array[Dictionary] = [
	{
		"id": "profaned_forest",
		"name": "BOSQUE PROFANADO",
		"order": 1,
		"biome_id": "forest",
		"scene_path": WORLD_SCENE,
		"preview_path": "res://assets/generated/corrupted_forest_ground.png",
		"unlock_requirement": {},
		"content_ready": true,
		"seed_offset": 0,
		"enemy_power": 1.0,
		"boss_power": 1.0,
		"encounter_profile_id": MapEncounterCatalogScript.PROFANED_FOREST_PROFILE_ID,
	},
	{
		"id": "frozen_ruins",
		"name": "RUÍNAS GLACIAIS",
		"order": 2,
		"biome_id": "frozen",
		"scene_path": WORLD_SCENE,
		"preview_path": "res://assets/generated/frozen_ruins_ground.png",
		"unlock_requirement": {"type": "complete_map", "map_id": "profaned_forest"},
		"content_ready": true,
		"seed_offset": 1,
		"enemy_power": 1.22,
		"boss_power": 1.32,
		"encounter_profile_id": MapEncounterCatalogScript.LEGACY_PROFILE_ID,
	},
	{
		"id": "void_cathedral",
		"name": "CATEDRAL DO VAZIO",
		"order": 3,
		"biome_id": "cathedral",
		"scene_path": WORLD_SCENE,
		"preview_path": "res://assets/generated/void_cathedral_ground.png",
		"unlock_requirement": {"type": "complete_map", "map_id": "frozen_ruins"},
		"content_ready": true,
		"seed_offset": 2,
		"enemy_power": 1.48,
		"boss_power": 1.64,
		"encounter_profile_id": MapEncounterCatalogScript.LEGACY_PROFILE_ID,
	},
	{
		"id": "map_04", "name": "MAPA 04", "order": 4, "biome_id": "future_04",
		"scene_path": "", "preview_path": PLACEHOLDER_PREVIEW,
		"unlock_requirement": {"type": "complete_map", "map_id": "void_cathedral"},
		"content_ready": false, "seed_offset": 3, "enemy_power": 1.0, "boss_power": 1.0,
	},
	{
		"id": "map_05", "name": "MAPA 05", "order": 5, "biome_id": "future_05",
		"scene_path": "", "preview_path": PLACEHOLDER_PREVIEW,
		"unlock_requirement": {"type": "complete_map", "map_id": "map_04"},
		"content_ready": false, "seed_offset": 4, "enemy_power": 1.0, "boss_power": 1.0,
	},
	{
		"id": "map_06", "name": "MAPA 06", "order": 6, "biome_id": "future_06",
		"scene_path": "", "preview_path": PLACEHOLDER_PREVIEW,
		"unlock_requirement": {"type": "complete_map", "map_id": "map_05"},
		"content_ready": false, "seed_offset": 5, "enemy_power": 1.0, "boss_power": 1.0,
	},
	{
		"id": "map_07", "name": "MAPA 07", "order": 7, "biome_id": "future_07",
		"scene_path": "", "preview_path": PLACEHOLDER_PREVIEW,
		"unlock_requirement": {"type": "complete_map", "map_id": "map_06"},
		"content_ready": false, "seed_offset": 6, "enemy_power": 1.0, "boss_power": 1.0,
	},
	{
		"id": "map_08", "name": "MAPA 08", "order": 8, "biome_id": "future_08",
		"scene_path": "", "preview_path": PLACEHOLDER_PREVIEW,
		"unlock_requirement": {"type": "complete_map", "map_id": "map_07"},
		"content_ready": false, "seed_offset": 7, "enemy_power": 1.0, "boss_power": 1.0,
	},
	{
		"id": "map_09", "name": "MAPA 09", "order": 9, "biome_id": "future_09",
		"scene_path": "", "preview_path": PLACEHOLDER_PREVIEW,
		"unlock_requirement": {"type": "complete_map", "map_id": "map_08"},
		"content_ready": false, "seed_offset": 8, "enemy_power": 1.0, "boss_power": 1.0,
	},
	{
		"id": "map_10", "name": "MAPA 10", "order": 10, "biome_id": "future_10",
		"scene_path": "", "preview_path": PLACEHOLDER_PREVIEW,
		"unlock_requirement": {"type": "complete_map", "map_id": "map_09"},
		"content_ready": false, "seed_offset": 9, "enemy_power": 1.0, "boss_power": 1.0,
	},
]


static func all_maps() -> Array[Dictionary]:
	return MAPS.duplicate(true)


static func first_map_id() -> String:
	return str(MAPS[0].id)


static func map_data(map_id: String) -> Dictionary:
	for definition in MAPS:
		if str(definition.id) == map_id:
			return definition.duplicate(true)
	return {}


static func map_by_order(order: int) -> Dictionary:
	for definition in MAPS:
		if int(definition.order) == order:
			return definition.duplicate(true)
	return {}


static func next_map_id(map_id: String) -> String:
	var definition := map_data(map_id)
	if definition.is_empty():
		return ""
	var following := map_by_order(int(definition.order) + 1)
	return "" if following.is_empty() else str(following.id)


static func requirement_map_id(map_id: String) -> String:
	var definition := map_data(map_id)
	var requirement: Dictionary = definition.get("unlock_requirement", {})
	if str(requirement.get("type", "")) != "complete_map":
		return ""
	return str(requirement.get("map_id", ""))


static func requirement_text(map_id: String) -> String:
	var requirement_id := requirement_map_id(map_id)
	if requirement_id.is_empty():
		return ""
	var requirement := map_data(requirement_id)
	if requirement.is_empty():
		return "Requisito de campanha indisponível."
	return "Conclua %s para desbloquear." % str(requirement.name)


static func known_map_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition in MAPS:
		ids.append(str(definition.id))
	return ids


static func validate_catalog(catalog: Array[Dictionary] = MAPS) -> Array[String]:
	var errors: Array[String] = []
	if catalog.is_empty():
		return ["[empty_catalog] O catálogo não possui mapas."]

	var definitions_by_id: Dictionary = {}
	var ids_by_order: Dictionary = {}
	for definition in catalog:
		var map_id := str(definition.get("id", "")).strip_edges()
		var order_value = definition.get("order", 0)
		if map_id.is_empty():
			errors.append("[invalid_id] Existe um mapa sem map_id.")
		elif definitions_by_id.has(map_id):
			errors.append("[duplicate_id] map_id duplicado: %s." % map_id)
		else:
			definitions_by_id[map_id] = definition
		if typeof(order_value) != TYPE_INT or int(order_value) < 1:
			errors.append("[invalid_order] Ordem inválida no mapa %s: %s." % [map_id, order_value])
			continue
		var order := int(order_value)
		if ids_by_order.has(order):
			errors.append(
				"[duplicate_order] Ordem %d usada por %s e %s."
				% [order, str(ids_by_order[order]), map_id]
			)
		else:
			ids_by_order[order] = map_id

	for expected_order in range(1, catalog.size() + 1):
		if not ids_by_order.has(expected_order):
			errors.append("[non_contiguous_order] A campanha não possui a ordem %d." % expected_order)

	var first_id := str(ids_by_order.get(1, ""))
	for map_id_value in definitions_by_id:
		var map_id := str(map_id_value)
		var definition: Dictionary = definitions_by_id[map_id]
		var order := int(definition.get("order", 0))
		var requirement: Dictionary = definition.get("unlock_requirement", {})
		var requirement_type := str(requirement.get("type", ""))
		var required_id := str(requirement.get("map_id", ""))

		if order == 1:
			if not requirement.is_empty():
				errors.append("[first_map_locked] O primeiro mapa não pode ter requisito.")
		elif requirement_type != "complete_map" or required_id.is_empty():
			errors.append("[missing_unlock_path] %s não possui requisito complete_map válido." % map_id)
		elif not definitions_by_id.has(required_id):
			errors.append("[missing_requirement] %s depende de um mapa inexistente: %s." % [map_id, required_id])
		else:
			var expected_previous_id := str(ids_by_order.get(order - 1, ""))
			if required_id != expected_previous_id:
				errors.append(
					"[skipped_stage] %s (ordem %d) deve depender de %s, não de %s."
					% [map_id, order, expected_previous_id, required_id]
				)
				errors.append(
					"[next_mismatch] A sequência ordem/map_id está inconsistente antes de %s."
					% map_id
				)

		var scene_path := str(definition.get("scene_path", ""))
		var content_ready := bool(definition.get("content_ready", false))
		if content_ready:
			if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
				errors.append("[missing_scene] Mapa jogável %s aponta para uma cena inexistente: %s." % [map_id, scene_path])
			var encounter_profile_id := str(definition.get("encounter_profile_id", ""))
			if encounter_profile_id.is_empty() or not MapEncounterCatalogScript.has_profile(encounter_profile_id):
				errors.append("[missing_encounter_profile] Mapa jogável %s não possui perfil de encontros válido: %s." % [map_id, encounter_profile_id])
		elif not scene_path.is_empty():
			errors.append("[coming_soon_has_scene] %s está EM BREVE, mas possui cena jogável configurada." % map_id)

	for start_id_value in definitions_by_id:
		var start_id := str(start_id_value)
		var dependency_chain: Array[String] = []
		var current_id := start_id
		while not current_id.is_empty() and definitions_by_id.has(current_id):
			if current_id in dependency_chain:
				errors.append("[circular_dependency] Dependência circular detectada a partir de %s." % start_id)
				break
			dependency_chain.append(current_id)
			var current_definition: Dictionary = definitions_by_id[current_id]
			var current_requirement: Dictionary = current_definition.get("unlock_requirement", {})
			if str(current_requirement.get("type", "")) != "complete_map":
				break
			current_id = str(current_requirement.get("map_id", ""))

		if start_id == first_id:
			continue
		var reaches_first := false
		var reachability_chain: Array[String] = []
		current_id = start_id
		while not current_id.is_empty() and definitions_by_id.has(current_id):
			if current_id == first_id:
				reaches_first = true
				break
			if current_id in reachability_chain:
				break
			reachability_chain.append(current_id)
			var current_definition: Dictionary = definitions_by_id[current_id]
			var current_requirement: Dictionary = current_definition.get("unlock_requirement", {})
			if str(current_requirement.get("type", "")) != "complete_map":
				break
			current_id = str(current_requirement.get("map_id", ""))
		if not reaches_first:
			errors.append("[unreachable_map] %s não possui caminho válido até o primeiro mapa." % start_id)

	return _unique_errors(errors)


static func assert_valid_catalog(catalog: Array[Dictionary] = MAPS) -> void:
	var errors := validate_catalog(catalog)
	assert(errors.is_empty(), "Catálogo de campanha inválido:\n%s" % "\n".join(errors))


static func _unique_errors(errors: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for error in errors:
		if error not in unique:
			unique.append(error)
	return unique
