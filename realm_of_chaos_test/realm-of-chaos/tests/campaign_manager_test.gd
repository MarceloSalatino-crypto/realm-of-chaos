extends SceneTree

const CampaignCatalogScript = preload("res://scripts/campaign_catalog.gd")
const CampaignManagerScript = preload("res://scripts/campaign_manager.gd")
const SaveStoreScript = preload("res://scripts/save_store.gd")
const TEST_SAVE_PATH := "user://campaign_manager_test.cfg"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CAMPAIGN MANAGER: " + message)


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".swap", ".corrupt", ".bak.corrupt"]:
		var path: String = TEST_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _load_raw() -> ConfigFile:
	var config := ConfigFile.new()
	_check(config.load(TEST_SAVE_PATH) == OK, "save de campanha não pôde ser relido")
	return config


func _run() -> void:
	_cleanup()
	var manager := CampaignManagerScript.new()
	_check(CampaignCatalogScript.all_maps().size() == 10, "catálogo não contém dez mapas")
	_check(str(CampaignCatalogScript.map_by_order(1).id) == "profaned_forest", "ordem do mapa 1 mudou")
	_check(str(CampaignCatalogScript.map_by_order(3).id) == "void_cathedral", "ordem do mapa 3 mudou")
	_check(not bool(CampaignCatalogScript.map_by_order(4).content_ready), "mapa 4 deixou de ser conteúdo futuro")

	var missing := manager.load_progress(TEST_SAVE_PATH, false)
	_check(bool(missing.migrated), "novo perfil não recebeu estado inicial em memória")
	_check(not FileAccess.file_exists(TEST_SAVE_PATH), "carga sem persistência criou arquivo")
	_check(manager.unlocked_maps == ["profaned_forest"], "novo perfil não iniciou apenas com mapa 1")
	_check(manager.completed_maps.is_empty(), "novo perfil iniciou com mapa concluído")
	_check(manager.map_status("frozen_ruins") == manager.STATUS_LOCKED, "mapa 2 iniciou desbloqueado")
	_check(not manager.persist_selection("frozen_ruins"), "mapa bloqueado foi selecionado")

	manager.load_progress(TEST_SAVE_PATH, true)
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH), "estado inicial não foi salvo com integridade")

	var legacy := ConfigFile.new()
	legacy.set_value("record", "victories", 9)
	legacy.set_value("meta", "essence", 77)
	legacy.set_value("achievements", "first_boss", true)
	legacy.set_value("settings", "music", 0.5)
	legacy.set_value("progress", "active_cycle", 1)
	legacy.set_value("progress", "highest_cycle", 1)
	_check(SaveStoreScript.save_config(legacy, TEST_SAVE_PATH) == OK, "save legado não foi preparado")
	var migrated := manager.load_progress(TEST_SAVE_PATH, true)
	_check(bool(migrated.migrated), "save legado não acionou migração")
	_check(manager.completed_maps == ["profaned_forest"], "ciclo 1 não migrou o mapa 1 como concluído")
	_check("frozen_ruins" in manager.unlocked_maps, "ciclo 1 não desbloqueou o mapa 2")
	_check(manager.can_start_map("frozen_ruins"), "mapa 2 migrado não pode iniciar")
	var migrated_config := _load_raw()
	_check(int(migrated_config.get_value("meta", "essence", 0)) == 77, "migração alterou Essência")
	_check(int(migrated_config.get_value("record", "victories", 0)) == 9, "migração alterou recordes")
	_check(bool(migrated_config.get_value("achievements", "first_boss", false)), "migração alterou conquistas")
	_check(float(migrated_config.get_value("settings", "music", 0.0)) == 0.5, "migração alterou opções")

	var skip_config := _load_raw()
	var skipped := manager.apply_completion(skip_config, "void_cathedral")
	_check(str(skipped.completed_map_id).is_empty(), "campanha permitiu pular o mapa 2")
	_check("void_cathedral" not in manager.completed_maps, "mapa 3 foi concluído fora de ordem")

	var completion := manager.apply_completion(skip_config, "frozen_ruins")
	_check(str(completion.unlocked_map_id) == "void_cathedral", "concluir mapa 2 não desbloqueou mapa 3")
	_check(SaveStoreScript.save_config(skip_config, TEST_SAVE_PATH) == OK, "conclusão do mapa 2 não foi persistida")
	manager.load_progress(TEST_SAVE_PATH, false)
	_check(manager.can_start_map("void_cathedral"), "mapa 3 não permaneceu desbloqueado após reinício")
	_check(manager.persist_selection("void_cathedral"), "mapa 3 desbloqueado não pôde ser selecionado")
	manager.load_progress(TEST_SAVE_PATH, false)
	_check(manager.selected_map_id == "void_cathedral", "mapa selecionado não persistiu após reinício")

	var replay_config := _load_raw()
	var replay := manager.apply_completion(replay_config, "frozen_ruins")
	_check(str(replay.unlocked_map_id).is_empty(), "repetir mapa concluído duplicou desbloqueio")
	_check(manager.can_start_map("frozen_ruins"), "mapa concluído deixou de poder ser repetido")

	var final_current := manager.apply_completion(replay_config, "void_cathedral")
	_check(str(final_current.unlocked_map_id) == "map_04", "concluir mapa 3 não atingiu o próximo nó da campanha")
	_check(manager.map_status("map_04") == manager.STATUS_COMING_SOON, "mapa 4 não aparece como EM BREVE")
	_check(not manager.can_start_map("map_04"), "mapa EM BREVE pôde iniciar")
	_check("map_05" not in manager.unlocked_maps, "mapa 5 foi desbloqueado antes do mapa 4")
	_check(SaveStoreScript.save_config(replay_config, TEST_SAVE_PATH) == OK, "progresso dos três mapas não foi salvo")

	_check(manager.reset_campaign_progress(TEST_SAVE_PATH) == OK, "reset da campanha falhou")
	var reset_config := _load_raw()
	_check(manager.unlocked_maps == ["profaned_forest"], "reset não restaurou apenas o mapa 1")
	_check(manager.completed_maps.is_empty(), "reset manteve mapas concluídos")
	_check(int(reset_config.get_value("meta", "essence", 0)) == 77, "reset apagou Essência")
	_check(int(reset_config.get_value("record", "victories", 0)) == 9, "reset apagou recordes")
	_check(bool(reset_config.get_value("achievements", "first_boss", false)), "reset apagou conquistas")
	_check(float(reset_config.get_value("settings", "music", 0.0)) == 0.5, "reset apagou opções")

	_cleanup()
	manager.free()
	if failures.is_empty():
		print("CAMPAIGN MANAGER OK: catálogo, novo perfil, migração, sequência, replay, EM BREVE e reset isolado validados")
		quit(0)
	else:
		quit(1)
