class_name SaveStore
extends RefCounted

const FORMAT_VERSION := 1
const INTEGRITY_SECTION := "_save_integrity"
const STATUS_OK := "ok"
const STATUS_MISSING := "missing"
const STATUS_RECOVERED := "recovered"
const STATUS_FAILED := "failed"


static func backup_path(save_path: String) -> String:
	return save_path + ".bak"


static func load_config(save_path: String, repair_primary := true) -> Dictionary:
	var primary := _inspect_file(save_path)
	if bool(primary.valid):
		return _load_result(primary.config, STATUS_OK)

	var backup := _inspect_file(backup_path(save_path))
	if bool(backup.valid):
		var repair_error := OK
		if repair_primary:
			repair_error = _restore_primary(backup.config, save_path)
		var message := "Seu progresso foi recuperado automaticamente a partir do backup."
		if repair_error != OK:
			message += "\nO jogo conseguiu carregar o backup, mas não pôde restaurar o arquivo principal."
		return _load_result(backup.config, STATUS_RECOVERED, message, repair_error)

	if not bool(primary.exists) and not bool(backup.exists):
		return _load_result(ConfigFile.new(), STATUS_MISSING)

	return _load_result(
		ConfigFile.new(),
		STATUS_FAILED,
		"Não foi possível carregar seu progresso anterior.\nUm novo perfil será usado. Os arquivos anteriores foram preservados.",
		ERR_FILE_CORRUPT
	)


static func save_config(config: ConfigFile, save_path: String) -> Error:
	_stamp_integrity(config)
	var temporary_path := save_path + ".tmp"
	var cleanup_error := _remove_file(temporary_path)
	if cleanup_error != OK:
		return cleanup_error

	var save_error := config.save(temporary_path)
	if save_error != OK:
		return save_error
	# ConfigFile normaliza a precisão de floats ao escrever texto. O checksum
	# precisa ser calculado sobre essa representação serializada, não sobre o
	# double original em memória, ou alguns tempos de partida seriam recusados
	# como corrompidos logo após a gravação.
	var canonical_config := ConfigFile.new()
	var canonical_load_error := canonical_config.load(temporary_path)
	if canonical_load_error != OK:
		_remove_file(temporary_path)
		return canonical_load_error
	_stamp_integrity(canonical_config)
	var canonical_save_error := canonical_config.save(temporary_path)
	if canonical_save_error != OK:
		_remove_file(temporary_path)
		return canonical_save_error
	config.set_value(
		INTEGRITY_SECTION, "checksum",
		canonical_config.get_value(INTEGRITY_SECTION, "checksum", "")
	)
	var temporary := _inspect_file(temporary_path, false)
	if not bool(temporary.valid):
		_remove_file(temporary_path)
		return ERR_FILE_CORRUPT

	var primary := _inspect_file(save_path)
	var backup_save_path := backup_path(save_path)
	var backup := _inspect_file(backup_save_path)
	if bool(primary.exists) and not bool(primary.valid):
		var preserve_primary_error := _preserve_corrupt_file(save_path)
		if preserve_primary_error != OK:
			_remove_file(temporary_path)
			return preserve_primary_error
	if bool(backup.exists) and not bool(backup.valid):
		var preserve_backup_error := _preserve_corrupt_file(backup_save_path)
		if preserve_backup_error != OK:
			_remove_file(temporary_path)
			return preserve_backup_error

	if bool(primary.valid):
		var rotate_error := _replace_backup_from(save_path, backup_save_path)
		if rotate_error != OK:
			_remove_file(temporary_path)
			return rotate_error
	var created_initial_backup := false
	if not bool(primary.valid) and not bool(backup.valid):
		var initial_backup_error := _replace_backup_from(temporary_path, backup_save_path)
		if initial_backup_error != OK:
			_remove_file(temporary_path)
			return initial_backup_error
		created_initial_backup = true

	var promote_error := _promote_file(temporary_path, save_path)
	if promote_error != OK:
		if created_initial_backup:
			_remove_file(backup_save_path)
		return promote_error
	return OK


static func is_valid_file(path: String) -> bool:
	return bool(_inspect_file(path).valid)


static func _load_result(
	config: ConfigFile,
	status: String,
	message := "",
	error := OK
) -> Dictionary:
	return {
		"config": config,
		"status": status,
		"message": message,
		"error": error,
	}


static func _inspect_file(path: String, allow_legacy := true) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {
			"config": ConfigFile.new(),
			"exists": false,
			"valid": false,
			"legacy": false,
			"error": ERR_FILE_NOT_FOUND,
		}
	if FileAccess.get_size(path) <= 0:
		return {
			"config": ConfigFile.new(),
			"exists": true,
			"valid": false,
			"legacy": false,
			"error": ERR_FILE_CORRUPT,
		}
	var config := ConfigFile.new()
	var load_error := config.load(path)
	if load_error != OK:
		return {
			"config": config,
			"exists": true,
			"valid": false,
			"legacy": false,
			"error": load_error,
		}
	var integrity := _validate_integrity(config, allow_legacy)
	return {
		"config": config,
		"exists": true,
		"valid": bool(integrity.valid),
		"legacy": bool(integrity.legacy),
		"error": int(integrity.error),
	}


static func _validate_integrity(config: ConfigFile, allow_legacy: bool) -> Dictionary:
	if not _has_payload(config) or not _known_values_are_sane(config):
		return {"valid": false, "legacy": false, "error": ERR_FILE_CORRUPT}
	if not config.has_section(INTEGRITY_SECTION):
		return {
			"valid": allow_legacy,
			"legacy": allow_legacy,
			"error": OK if allow_legacy else ERR_FILE_CORRUPT,
		}
	if (
		not config.has_section_key(INTEGRITY_SECTION, "format_version")
		or not config.has_section_key(INTEGRITY_SECTION, "complete")
		or not config.has_section_key(INTEGRITY_SECTION, "checksum")
	):
		return {"valid": false, "legacy": false, "error": ERR_FILE_CORRUPT}
	var version = config.get_value(INTEGRITY_SECTION, "format_version")
	var complete = config.get_value(INTEGRITY_SECTION, "complete")
	var checksum = config.get_value(INTEGRITY_SECTION, "checksum")
	if typeof(version) != TYPE_INT or int(version) != FORMAT_VERSION:
		return {"valid": false, "legacy": false, "error": ERR_FILE_CORRUPT}
	if typeof(complete) != TYPE_BOOL or not bool(complete):
		return {"valid": false, "legacy": false, "error": ERR_FILE_CORRUPT}
	if typeof(checksum) != TYPE_STRING or str(checksum) != _calculate_checksum(config):
		return {"valid": false, "legacy": false, "error": ERR_FILE_CORRUPT}
	return {"valid": true, "legacy": false, "error": OK}


static func _has_payload(config: ConfigFile) -> bool:
	for section in ["record", "progress", "campaign", "meta", "achievements", "profile", "settings"]:
		if config.has_section(section) and not config.get_section_keys(section).is_empty():
			return true
	return false


static func _known_values_are_sane(config: ConfigFile) -> bool:
	for section in ["record", "progress", "meta"]:
		if not config.has_section(section):
			continue
		for key in config.get_section_keys(section):
			var value = config.get_value(section, key)
			if not _is_non_negative_number(value):
				return false
	if config.has_section("achievements"):
		for key in config.get_section_keys("achievements"):
			if typeof(config.get_value("achievements", key)) != TYPE_BOOL:
				return false
	if config.has_section("campaign") and not _campaign_values_are_sane(config):
		return false
	if config.has_section_key("profile", "version"):
		if not _is_non_negative_number(config.get_value("profile", "version")):
			return false
	if config.has_section_key("profile", "character"):
		var character = config.get_value("profile", "character")
		if typeof(character) != TYPE_STRING or str(character).is_empty():
			return false
	if config.has_section("settings"):
		for key in config.get_section_keys("settings"):
			var setting = config.get_value("settings", key)
			if key == "fullscreen":
				if typeof(setting) != TYPE_BOOL:
					return false
			elif not _is_number(setting) or float(setting) < 0.0 or float(setting) > 1.0:
				return false
	return true


static func _campaign_values_are_sane(config: ConfigFile) -> bool:
	if config.has_section_key("campaign", "schema_version"):
		var version = config.get_value("campaign", "schema_version")
		if typeof(version) != TYPE_INT or int(version) < 1:
			return false
	if config.has_section_key("campaign", "selected_map_id"):
		var selected = config.get_value("campaign", "selected_map_id")
		if typeof(selected) != TYPE_STRING or str(selected).is_empty():
			return false
	for key in ["unlocked_maps", "completed_maps"]:
		if not config.has_section_key("campaign", key):
			continue
		var values = config.get_value("campaign", key)
		if not (values is PackedStringArray) and not (values is Array):
			return false
		for value in values:
			if typeof(value) != TYPE_STRING or str(value).is_empty():
				return false
	return true


static func _is_non_negative_number(value) -> bool:
	return _is_number(value) and float(value) >= 0.0


static func _is_number(value) -> bool:
	var value_type := typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		return false
	return is_finite(float(value))


static func _stamp_integrity(config: ConfigFile) -> void:
	config.set_value(INTEGRITY_SECTION, "format_version", FORMAT_VERSION)
	config.set_value(INTEGRITY_SECTION, "complete", true)
	config.set_value(INTEGRITY_SECTION, "checksum", _calculate_checksum(config))


static func _calculate_checksum(config: ConfigFile) -> String:
	var canonical := ConfigFile.new()
	var sections: Array = Array(config.get_sections())
	sections.sort()
	for section_value in sections:
		var section := str(section_value)
		if section == INTEGRITY_SECTION:
			continue
		var keys: Array = Array(config.get_section_keys(section))
		keys.sort()
		for key_value in keys:
			var key := str(key_value)
			canonical.set_value(section, key, config.get_value(section, key))
	return canonical.encode_to_text().sha256_text()


static func _restore_primary(config: ConfigFile, save_path: String) -> Error:
	_stamp_integrity(config)
	var temporary_path := save_path + ".tmp"
	var cleanup_error := _remove_file(temporary_path)
	if cleanup_error != OK:
		return cleanup_error
	var save_error := config.save(temporary_path)
	if save_error != OK:
		return save_error
	if not bool(_inspect_file(temporary_path, false).valid):
		_remove_file(temporary_path)
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(save_path):
		var preserve_error := _preserve_corrupt_file(save_path)
		if preserve_error != OK:
			_remove_file(temporary_path)
			return preserve_error
	return _promote_file(temporary_path, save_path)


static func _replace_backup_from(source_path: String, backup_save_path: String) -> Error:
	var temporary_backup_path := backup_save_path + ".tmp"
	var cleanup_error := _remove_file(temporary_backup_path)
	if cleanup_error != OK:
		return cleanup_error
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(temporary_backup_path)
	)
	if copy_error != OK:
		return copy_error
	if not bool(_inspect_file(temporary_backup_path).valid):
		_remove_file(temporary_backup_path)
		return ERR_FILE_CORRUPT
	return _promote_file(temporary_backup_path, backup_save_path)


static func _promote_file(source_path: String, target_path: String) -> Error:
	var holding_path := target_path + ".swap"
	var cleanup_error := _remove_file(holding_path)
	if cleanup_error != OK:
		return cleanup_error
	var source_absolute := ProjectSettings.globalize_path(source_path)
	var target_absolute := ProjectSettings.globalize_path(target_path)
	var holding_absolute := ProjectSettings.globalize_path(holding_path)
	var moved_previous := false
	if FileAccess.file_exists(target_path):
		var hold_error := DirAccess.rename_absolute(target_absolute, holding_absolute)
		if hold_error != OK:
			return hold_error
		moved_previous = true
	var promote_error := DirAccess.rename_absolute(source_absolute, target_absolute)
	if promote_error != OK:
		if moved_previous:
			DirAccess.rename_absolute(holding_absolute, target_absolute)
		return promote_error
	if moved_previous:
		_remove_file(holding_path)
	return OK


static func _preserve_corrupt_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	var preserved_path := path + ".corrupt"
	var suffix := 1
	while FileAccess.file_exists(preserved_path):
		preserved_path = "%s.corrupt.%d" % [path, suffix]
		suffix += 1
	return DirAccess.copy_absolute(
		ProjectSettings.globalize_path(path),
		ProjectSettings.globalize_path(preserved_path)
	)


static func _remove_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
