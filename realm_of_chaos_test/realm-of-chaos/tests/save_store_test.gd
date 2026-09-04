extends SceneTree

const SaveStoreScript = preload("res://scripts/save_store.gd")
const TEST_SAVE_PATH := "user://save_store_test.cfg"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SAVE STORE: " + message)


func _config_with_essence(amount: int) -> ConfigFile:
	var config := ConfigFile.new()
	config.set_value("meta", "essence", amount)
	config.set_value("settings", "music", 0.75)
	return config


func _load_raw(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	_check(config.load(path) == OK, "arquivo de teste valido nao pode ser relido: " + path)
	return config


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "nao foi possivel preparar arquivo de teste: " + path)
	if file:
		file.store_string(content)
		file.close()


func _write_corrupt_config(path: String) -> void:
	var config := _config_with_essence(999)
	config.set_value("_save_integrity", "format_version", 1)
	config.set_value("_save_integrity", "complete", true)
	config.set_value("_save_integrity", "checksum", "checksum_invalido")
	_check(config.save(path) == OK, "nao foi possivel preparar save corrompido: " + path)


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _remove_path(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute(absolute)


func _clean_artifacts() -> void:
	for path in [
		TEST_SAVE_PATH,
		TEST_SAVE_PATH + ".bak",
		TEST_SAVE_PATH + ".tmp",
		TEST_SAVE_PATH + ".swap",
		TEST_SAVE_PATH + ".bak.tmp",
		TEST_SAVE_PATH + ".bak.swap",
		TEST_SAVE_PATH + ".corrupt",
		TEST_SAVE_PATH + ".bak.corrupt",
	]:
		_remove_path(path)
	for index in range(1, 8):
		_remove_path("%s.corrupt.%d" % [TEST_SAVE_PATH, index])
		_remove_path("%s.bak.corrupt.%d" % [TEST_SAVE_PATH, index])


func _run() -> void:
	_clean_artifacts()

	var first_use := SaveStoreScript.load_config(TEST_SAVE_PATH)
	_check(str(first_use.status) == SaveStoreScript.STATUS_MISSING, "primeiro uso gerou falha ou aviso")
	_check(str(first_use.message).is_empty(), "primeiro uso exibiria aviso indevido")

	var legacy := _config_with_essence(17)
	_check(legacy.save(TEST_SAVE_PATH) == OK, "save legado de teste nao foi criado")
	var legacy_result := SaveStoreScript.load_config(TEST_SAVE_PATH)
	_check(str(legacy_result.status) == SaveStoreScript.STATUS_OK, "save legado sem checksum foi rejeitado")
	_check(int(legacy_result.config.get_value("meta", "essence", 0)) == 17, "save legado perdeu dados")

	legacy.set_value("meta", "essence", 18)
	_check(SaveStoreScript.save_config(legacy, TEST_SAVE_PATH) == OK, "primeiro save protegido falhou")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH), "principal protegido nao passou na validacao")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".bak"), "backup nao foi criado")
	var protected_main := _load_raw(TEST_SAVE_PATH)
	_check(protected_main.has_section("_save_integrity"), "save legado nao ganhou checksum")
	_check(int(_load_raw(TEST_SAVE_PATH + ".bak").get_value("meta", "essence", 0)) == 17, "backup nao preservou a geracao anterior")

	_write_corrupt_config(TEST_SAVE_PATH)
	var recovered := SaveStoreScript.load_config(TEST_SAVE_PATH)
	_check(str(recovered.status) == SaveStoreScript.STATUS_RECOVERED, "principal corrompido nao recuperou o backup")
	_check(int(recovered.config.get_value("meta", "essence", 0)) == 17, "recuperacao nao usou o backup")
	_check("recuperado automaticamente" in str(recovered.message), "recuperacao nao gerou aviso claro")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH), "principal nao foi restaurado depois da recuperacao")
	_check(FileAccess.file_exists(TEST_SAVE_PATH + ".corrupt"), "principal corrompido nao foi preservado")

	var healthy_main: ConfigFile = recovered.config
	healthy_main.set_value("meta", "essence", 21)
	_check(SaveStoreScript.save_config(healthy_main, TEST_SAVE_PATH) == OK, "save depois da recuperacao falhou")
	_write_corrupt_config(TEST_SAVE_PATH + ".bak")
	var healthy_result := SaveStoreScript.load_config(TEST_SAVE_PATH)
	_check(str(healthy_result.status) == SaveStoreScript.STATUS_OK, "backup corrompido invalidou principal saudavel")
	_check(int(healthy_result.config.get_value("meta", "essence", 0)) == 21, "principal saudavel nao foi mantido")

	_write_corrupt_config(TEST_SAVE_PATH)
	_write_corrupt_config(TEST_SAVE_PATH + ".bak")
	var corrupt_main_bytes := _bytes(TEST_SAVE_PATH)
	var corrupt_backup_bytes := _bytes(TEST_SAVE_PATH + ".bak")
	var failed_load := SaveStoreScript.load_config(TEST_SAVE_PATH)
	_check(str(failed_load.status) == SaveStoreScript.STATUS_FAILED, "dois arquivos corrompidos nao geraram falha")
	_check("novo perfil" in str(failed_load.message) and "preservados" in str(failed_load.message), "falha dupla nao gerou aviso claro")
	_check(_bytes(TEST_SAVE_PATH) == corrupt_main_bytes and _bytes(TEST_SAVE_PATH + ".bak") == corrupt_backup_bytes, "carga destruiu arquivos corrompidos")
	var replacement := _config_with_essence(3)
	_check(SaveStoreScript.save_config(replacement, TEST_SAVE_PATH) == OK, "novo save depois da falha dupla nao foi criado")
	_check(FileAccess.file_exists(TEST_SAVE_PATH + ".corrupt"), "principal da falha dupla nao foi preservado")
	_check(FileAccess.file_exists(TEST_SAVE_PATH + ".bak.corrupt"), "backup da falha dupla nao foi preservado")

	_clean_artifacts()
	_write_text(TEST_SAVE_PATH, "")
	var empty_result := SaveStoreScript.load_config(TEST_SAVE_PATH)
	_check(str(empty_result.status) == SaveStoreScript.STATUS_FAILED, "arquivo vazio foi aceito como save valido")

	_clean_artifacts()
	var precision_config := _config_with_essence(29)
	precision_config.set_value("record", "best_time", 0.12032866666666667)
	_check(SaveStoreScript.save_config(precision_config, TEST_SAVE_PATH) == OK, "float de alta precisão invalidou a gravação")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH), "float normalizado não passou pelo checksum serializado")
	var precision_result := SaveStoreScript.load_config(TEST_SAVE_PATH)
	_check(str(precision_result.status) == SaveStoreScript.STATUS_OK, "save com float normalizado não pôde ser recarregado")

	_clean_artifacts()
	var checksum_config := _config_with_essence(30)
	_check(SaveStoreScript.save_config(checksum_config, TEST_SAVE_PATH) == OK, "save para teste de checksum falhou")
	var tampered := _load_raw(TEST_SAVE_PATH)
	tampered.set_value("meta", "essence", 999)
	_check(tampered.save(TEST_SAVE_PATH) == OK, "nao foi possivel adulterar o checksum no teste")
	var checksum_result := SaveStoreScript.load_config(TEST_SAVE_PATH)
	_check(str(checksum_result.status) == SaveStoreScript.STATUS_RECOVERED, "checksum adulterado nao acionou o backup")
	_check(int(checksum_result.config.get_value("meta", "essence", 0)) == 30, "checksum adulterado contaminou a recuperacao")

	var main_before_failure := _bytes(TEST_SAVE_PATH)
	var backup_before_failure := _bytes(TEST_SAVE_PATH + ".bak")
	var temporary_directory := ProjectSettings.globalize_path(TEST_SAVE_PATH + ".tmp")
	_check(DirAccess.make_dir_absolute(temporary_directory) == OK, "bloqueio de escrita do teste nao foi criado")
	checksum_result.config.set_value("meta", "essence", 31)
	var write_error := SaveStoreScript.save_config(checksum_result.config, TEST_SAVE_PATH)
	_check(write_error != OK, "falha de escrita simulada foi tratada como sucesso")
	_check(_bytes(TEST_SAVE_PATH) == main_before_failure, "falha de escrita alterou o principal")
	_check(_bytes(TEST_SAVE_PATH + ".bak") == backup_before_failure, "falha de escrita alterou o backup")
	DirAccess.remove_absolute(temporary_directory)

	_clean_artifacts()
	var blocked_backup_temporary := ProjectSettings.globalize_path(TEST_SAVE_PATH + ".bak.tmp")
	_check(DirAccess.make_dir_absolute(blocked_backup_temporary) == OK, "bloqueio do primeiro backup nao foi criado")
	var first_generation := _config_with_essence(41)
	var first_generation_error := SaveStoreScript.save_config(first_generation, TEST_SAVE_PATH)
	_check(first_generation_error != OK, "falha do primeiro backup foi tratada como sucesso")
	_check(not FileAccess.file_exists(TEST_SAVE_PATH), "falha do primeiro backup promoveu estado parcial ao principal")
	_check(not SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".bak"), "falha do primeiro backup deixou backup candidato valido")
	DirAccess.remove_absolute(blocked_backup_temporary)
	_check(SaveStoreScript.save_config(first_generation, TEST_SAVE_PATH) == OK, "primeiro save nao se recuperou apos liberar o backup")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH), "principal nao foi criado apos recuperar a escrita")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".bak"), "backup nao foi criado apos recuperar a escrita")

	_clean_artifacts()
	var blocked_first_primary := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	_check(DirAccess.make_dir_absolute(blocked_first_primary) == OK, "bloqueio da primeira promocao nao foi criado")
	var first_promotion_candidate := _config_with_essence(51)
	var first_promotion_error := SaveStoreScript.save_config(first_promotion_candidate, TEST_SAVE_PATH)
	_check(first_promotion_error != OK, "falha da primeira promocao foi tratada como sucesso")
	_check(not FileAccess.file_exists(TEST_SAVE_PATH), "falha da primeira promocao criou principal parcial")
	_check(not SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".bak"), "falha da primeira promocao manteve backup inicial como progresso confirmado")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".tmp"), "candidato temporario valido nao permaneceu disponivel para retry")
	_check(int(_load_raw(TEST_SAVE_PATH + ".tmp").get_value("meta", "essence", 0)) == 51, "temporario residual nao contem o candidato completo")
	var first_promotion_load := SaveStoreScript.load_config(TEST_SAVE_PATH, false)
	_check(str(first_promotion_load.status) == SaveStoreScript.STATUS_MISSING, "load interpretou temporario do primeiro save como progresso")
	_remove_path(TEST_SAVE_PATH)
	_check(SaveStoreScript.save_config(first_promotion_candidate, TEST_SAVE_PATH) == OK, "retry do primeiro save falhou depois de liberar a promocao")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH), "retry do primeiro save nao criou principal valido")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".bak"), "retry do primeiro save nao criou backup valido")
	_check(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "retry do primeiro save deixou temporario residual")

	_clean_artifacts()
	_check(SaveStoreScript.save_config(_config_with_essence(60), TEST_SAVE_PATH) == OK, "geracao inicial do save existente falhou")
	_check(SaveStoreScript.save_config(_config_with_essence(61), TEST_SAVE_PATH) == OK, "segunda geracao do save existente falhou")
	var existing_main_before := _bytes(TEST_SAVE_PATH)
	var blocked_existing_swap := ProjectSettings.globalize_path(TEST_SAVE_PATH + ".swap")
	_check(DirAccess.make_dir_absolute(blocked_existing_swap) == OK, "bloqueio da promocao com save existente nao foi criado")
	var existing_promotion_candidate := _config_with_essence(62)
	var existing_promotion_error := SaveStoreScript.save_config(existing_promotion_candidate, TEST_SAVE_PATH)
	_check(existing_promotion_error != OK, "falha da promocao com save existente foi tratada como sucesso")
	_check(_bytes(TEST_SAVE_PATH) == existing_main_before, "falha da promocao alterou o principal existente")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".bak"), "falha da promocao invalidou o backup existente")
	_check(int(_load_raw(TEST_SAVE_PATH + ".bak").get_value("meta", "essence", 0)) == 61, "backup nao preservou a ultima geracao confirmada")
	_check(SaveStoreScript.is_valid_file(TEST_SAVE_PATH + ".tmp"), "falha da promocao existente descartou o candidato antes do retry")
	_check(int(_load_raw(TEST_SAVE_PATH + ".tmp").get_value("meta", "essence", 0)) == 62, "temporario do save existente perdeu o candidato completo")
	var existing_restart := SaveStoreScript.load_config(TEST_SAVE_PATH, false)
	_check(str(existing_restart.status) == SaveStoreScript.STATUS_OK, "reinicio apos falha nao carregou o principal anterior")
	_check(int(existing_restart.config.get_value("meta", "essence", 0)) == 61, "reinicio carregou progresso temporario nao confirmado")
	_remove_path(TEST_SAVE_PATH + ".swap")
	_check(SaveStoreScript.save_config(existing_promotion_candidate, TEST_SAVE_PATH) == OK, "retry do save existente falhou")
	_check(int(_load_raw(TEST_SAVE_PATH).get_value("meta", "essence", 0)) == 62, "retry nao promoveu a nova geracao")
	_check(int(_load_raw(TEST_SAVE_PATH + ".bak").get_value("meta", "essence", 0)) == 61, "retry nao manteve a geracao anterior no backup")
	_check(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "retry do save existente deixou temporario residual")
	_check(not FileAccess.file_exists(TEST_SAVE_PATH + ".swap"), "retry do save existente deixou arquivo de rollback")

	_clean_artifacts()
	if failures.is_empty():
		print("SAVE STORE OK: legado, checksum canônico, backup, recuperação, preservação e falhas de escrita validados")
		quit(0)
	else:
		quit(1)
