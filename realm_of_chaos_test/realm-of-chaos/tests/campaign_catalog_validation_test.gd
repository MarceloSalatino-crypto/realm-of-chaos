extends SceneTree

const CampaignCatalogScript = preload("res://scripts/campaign_catalog.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CAMPAIGN CATALOG VALIDATION: " + message)


func _has_code(errors: Array[String], code: String) -> bool:
	for error in errors:
		if error.begins_with("[%s]" % code):
			return true
	return false


func _variant() -> Array[Dictionary]:
	return CampaignCatalogScript.all_maps()


func _run() -> void:
	_check(CampaignCatalogScript.validate_catalog().is_empty(), "catálogo real foi considerado inválido")

	var duplicate_id := _variant()
	duplicate_id[1].id = duplicate_id[0].id
	_check(_has_code(CampaignCatalogScript.validate_catalog(duplicate_id), "duplicate_id"), "map_id duplicado não foi detectado")

	var duplicate_order := _variant()
	duplicate_order[1].order = duplicate_order[0].order
	_check(_has_code(CampaignCatalogScript.validate_catalog(duplicate_order), "duplicate_order"), "ordem duplicada não foi detectada")

	var invalid_order := _variant()
	invalid_order[0].order = 0
	_check(_has_code(CampaignCatalogScript.validate_catalog(invalid_order), "invalid_order"), "ordem inválida não foi detectada")

	var missing_requirement := _variant()
	missing_requirement[1].unlock_requirement = {"type": "complete_map", "map_id": "ghost_map"}
	_check(_has_code(CampaignCatalogScript.validate_catalog(missing_requirement), "missing_requirement"), "requisito inexistente não foi detectado")

	var circular := _variant()
	circular[0].unlock_requirement = {"type": "complete_map", "map_id": "frozen_ruins"}
	_check(_has_code(CampaignCatalogScript.validate_catalog(circular), "circular_dependency"), "dependência circular não foi detectada")

	var skipped := _variant()
	skipped[2].unlock_requirement = {"type": "complete_map", "map_id": "profaned_forest"}
	var skipped_errors := CampaignCatalogScript.validate_catalog(skipped)
	_check(_has_code(skipped_errors, "skipped_stage"), "salto de etapa não foi detectado")
	_check(_has_code(skipped_errors, "next_mismatch"), "inconsistência entre ordem e próximo mapa não foi detectada")

	var missing_scene := _variant()
	missing_scene[0].scene_path = "res://scenes/does_not_exist.tscn"
	_check(_has_code(CampaignCatalogScript.validate_catalog(missing_scene), "missing_scene"), "cena inexistente não foi detectada")

	var missing_encounter_profile := _variant()
	missing_encounter_profile[0].encounter_profile_id = "ghost_profile"
	_check(_has_code(CampaignCatalogScript.validate_catalog(missing_encounter_profile), "missing_encounter_profile"), "perfil de encontros inexistente não foi detectado")

	var coming_soon_scene := _variant()
	coming_soon_scene[3].scene_path = CampaignCatalogScript.WORLD_SCENE
	_check(_has_code(CampaignCatalogScript.validate_catalog(coming_soon_scene), "coming_soon_has_scene"), "mapa jogável marcado EM BREVE não foi detectado")

	var no_unlock_path := _variant()
	no_unlock_path[1].unlock_requirement = {}
	var no_path_errors := CampaignCatalogScript.validate_catalog(no_unlock_path)
	_check(_has_code(no_path_errors, "missing_unlock_path"), "mapa sem requisito não foi detectado")
	_check(_has_code(no_path_errors, "unreachable_map"), "mapa inalcançável não foi detectado")

	if failures.is_empty():
		print("CAMPAIGN CATALOG VALIDATION OK: 10 mapas válidos e 10 classes de erro detectadas")
		quit(0)
	else:
		quit(1)
