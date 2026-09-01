extends SceneTree

const MapEncounterCatalogScript = preload("res://scripts/map_encounter_catalog.gd")
const MapEncounterProfileScript = preload("res://scripts/map_encounter_profile.gd")
const CampaignCatalogScript = preload("res://scripts/campaign_catalog.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("MAP ENCOUNTER PROFILE: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.6f, obtido %.6f)" % [message, expected, actual])


func _run() -> void:
	var profile = MapEncounterCatalogScript.profile(MapEncounterCatalogScript.LEGACY_PROFILE_ID)
	_check(profile.profile_id == "legacy_25m", "perfil legado não foi resolvido")
	_check(profile.validate().is_empty(), "perfil legado foi considerado inválido")
	_check_close(profile.duration, 1500.0, "duração legada mudou")

	for elapsed in [0.0, 17.9, 18.0, 51.9, 52.0, 114.9, 115.0, 204.9, 205.0, 299.9, 300.0, 450.0, 599.9, 600.0, 750.0, 899.9, 900.0, 1200.0, 1499.9, 1500.0]:
		var actual: Dictionary = profile.difficulty_at(elapsed)
		var expected: Dictionary = GameDefs.difficulty_data(elapsed)
		_check(str(actual.id) == str(expected.id), "fase divergiu em %.1fs" % elapsed)
		_check(str(actual.name) == str(expected.name), "nome da fase divergiu em %.1fs" % elapsed)
		_check(int(actual.batch) == int(expected.batch), "lote divergiu em %.1fs" % elapsed)
		_check(int(actual.cap) == int(expected.cap), "teto divergiu em %.1fs" % elapsed)
		_check_close(float(actual.interval), float(expected.interval), "intervalo divergiu em %.1fs" % elapsed)
		_check_close(float(actual.power), float(expected.power), "poder divergiu em %.1fs" % elapsed)
		_check_close(float(actual.elite_chance), float(expected.elite_chance), "chance elite divergiu em %.1fs" % elapsed)

	var expected_choices := {
		0.0: ["prowler", "prowler", "prowler"],
		18.0: ["prowler", "prowler", "prowler", "bat", "bat", "swarm"],
		52.0: ["prowler", "prowler", "prowler", "bat", "bat", "swarm", "mage", "archer"],
		115.0: ["prowler", "prowler", "prowler", "bat", "bat", "swarm", "mage", "archer", "brute"],
		205.0: ["prowler", "prowler", "prowler", "bat", "bat", "swarm", "mage", "archer", "brute", "ember", "bomber"],
		300.0: ["prowler", "bat", "bat", "mage", "archer", "brute", "bomber", "swarm"],
		600.0: ["bat", "mage", "archer", "brute", "brute", "ember", "bomber", "assassin", "necromancer", "swarm"],
		900.0: ["mage", "archer", "brute", "brute", "ember", "bomber", "assassin", "necromancer", "guardian", "swarm", "swarm"],
	}
	for elapsed_value in expected_choices:
		var elapsed := float(elapsed_value)
		_check(profile.enemy_choices_at(elapsed) == expected_choices[elapsed_value], "pool legado divergiu em %.1fs" % elapsed)

	_check(profile.boss_schedule == GameDefs.boss_schedule(), "agenda legada de bosses mudou")
	_check(profile.world_events.size() == 5, "agenda legada não possui cinco eventos")
	_check([profile.world_events[0].id, profile.world_events[1].id, profile.world_events[2].id, profile.world_events[3].id, profile.world_events[4].id] == ["blood_moon", "soul_storm", "eclipse", "blood_moon", "void_rain"], "ordem legada dos eventos mudou")
	_check(Array(profile.elite_surge_for_phase("hard").sequence).size() == 4, "surge Difícil mudou")
	_check(Array(profile.elite_surge_for_phase("chaos").sequence).size() == 8, "surge Caos mudou")
	_check(Array(profile.elite_surge_for_phase("inferno").sequence).size() == 12, "surge Inferno mudou")
	_check(profile.hazard_kind_for_biome("forest").is_empty(), "perfil legado ainda referencia Raízes Profanadas")
	_check(profile.hazard_kind_for_biome("frozen") == "ice", "hazard das Ruínas mudou")
	_check(profile.hazard_kind_for_biome("cathedral") == "void", "hazard da Catedral mudou")
	_check(Array(profile.landmark_profile.kinds) == ["altar", "obelisk", "tree", "portal"], "landmarks legados mudaram")
	_check(int(profile.hazard_profile.count) == 18, "quantidade legada de hazards mudou")

	var forest_profile = MapEncounterCatalogScript.profile(MapEncounterCatalogScript.PROFANED_FOREST_PROFILE_ID)
	_check(forest_profile.validate().is_empty(), "perfil do Bosque sem raízes foi considerado inválido")
	_check(int(forest_profile.hazard_profile.count) == 0, "perfil do Bosque ainda gera hazards")
	_check(forest_profile.hazard_kind_for_biome("forest").is_empty(), "perfil do Bosque ainda referencia Raízes Profanadas")
	_check(str(CampaignCatalogScript.map_data("profaned_forest").encounter_profile_id) == MapEncounterCatalogScript.PROFANED_FOREST_PROFILE_ID, "Bosque não referencia o perfil sem raízes")
	for map_id in ["frozen_ruins", "void_cathedral"]:
		_check(str(CampaignCatalogScript.map_data(map_id).encounter_profile_id) == "legacy_25m", "%s deixou de referenciar o perfil legado" % map_id)

	var invalid_profile = MapEncounterProfileScript.new({"id": "invalid", "duration": 0.0})
	var invalid_errors: Array[String] = invalid_profile.validate()
	_check(invalid_errors.size() >= 4, "validador não rejeitou perfil estruturalmente incompleto")
	_check(not MapEncounterCatalogScript.validate_profile("missing").is_empty(), "catálogo aceitou perfil inexistente")

	if failures.is_empty():
		print("MAP ENCOUNTER PROFILE OK: legado equivale a GameDefs, agendas e perfis ambientais atuais")
		quit(0)
	else:
		quit(1)
