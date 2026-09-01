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


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
		_remove_file(path)
	for index in range(1, 8):
		_remove_file("%s.corrupt.%d" % [TEST_SAVE_PATH, index])
		_remove_file("%s.bak.corrupt.%d" % [TEST_SAVE_PATH, index])
	var temporary_absolute := ProjectSettings.globalize_path(TEST_SAVE_PATH + ".tmp")
	if DirAccess.dir_exists_absolute(temporary_absolute):
		DirAccess.remove_absolute(temporary_absolute)


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
	if failures.is_empty():
		print("SAVE STORE OK: legado, checksum canônico, backup, recuperação, preservação e falhas de escrita validados")
		quit(0)
	else:
		quit(1)
