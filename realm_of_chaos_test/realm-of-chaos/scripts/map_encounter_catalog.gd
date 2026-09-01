extends RefCounted

const MapEncounterProfileScript = preload("res://scripts/map_encounter_profile.gd")
const LEGACY_PROFILE_ID := "legacy_25m"
const PROFANED_FOREST_PROFILE_ID := "profaned_forest_no_roots"

const PROFILES := {
	LEGACY_PROFILE_ID: {
		"id": LEGACY_PROFILE_ID,
		"duration": 1500.0,
		"difficulty_phases": [
			{"id": "normal", "name": "I · NORMAL", "color": Color("b995e8"), "start": 0.0, "end": 300.0, "interval_start": 0.95, "interval_end": 0.52, "batch_base": 1, "batch_growth": 2, "cap_start": 60, "cap_end": 70, "power_start": 1.0, "power_end": 1.9, "elite_start": 0.02, "elite_end": 0.055},
			{"id": "hard", "name": "II · DIFÍCIL", "color": Color("ffb454"), "start": 300.0, "end": 600.0, "interval_start": 0.42, "interval_end": 0.28, "batch_base": 4, "batch_growth": 2, "cap_start": 70, "cap_end": 78, "power_start": 2.0, "power_end": 3.1, "elite_start": 0.07, "elite_end": 0.12},
			{"id": "chaos", "name": "III · CAOS", "color": Color("df63ff"), "start": 600.0, "end": 900.0, "interval_start": 0.20, "interval_end": 0.11, "batch_base": 7, "batch_growth": 5, "cap_start": 78, "cap_end": 84, "power_start": 3.3, "power_end": 5.0, "elite_start": 0.14, "elite_end": 0.21},
			{"id": "inferno", "name": "IV · MODO INFERNO", "color": Color("ff4b52"), "start": 900.0, "end": 1500.0, "interval_start": 0.085, "interval_end": 0.05, "batch_base": 14, "batch_growth": 6, "cap_start": 84, "cap_end": 90, "power_start": 5.5, "power_end": 10.0, "elite_start": 0.23, "elite_end": 0.34},
		],
		"enemy_phases": [
			{"start": 0.0, "end": 18.0, "choices": ["prowler", "prowler", "prowler"]},
			{"start": 18.0, "end": 52.0, "choices": ["prowler", "prowler", "prowler", "bat", "bat", "swarm"]},
			{"start": 52.0, "end": 115.0, "choices": ["prowler", "prowler", "prowler", "bat", "bat", "swarm", "mage", "archer"]},
			{"start": 115.0, "end": 205.0, "choices": ["prowler", "prowler", "prowler", "bat", "bat", "swarm", "mage", "archer", "brute"]},
			{"start": 205.0, "end": 300.0, "choices": ["prowler", "prowler", "prowler", "bat", "bat", "swarm", "mage", "archer", "brute", "ember", "bomber"]},
			{"start": 300.0, "end": 600.0, "choices": ["prowler", "bat", "bat", "mage", "archer", "brute", "bomber", "swarm"]},
			{"start": 600.0, "end": 900.0, "choices": ["bat", "mage", "archer", "brute", "brute", "ember", "bomber", "assassin", "necromancer", "swarm"]},
			{"start": 900.0, "end": 1500.001, "choices": ["mage", "archer", "brute", "brute", "ember", "bomber", "assassin", "necromancer", "guardian", "swarm", "swarm"]},
		],
		"boss_schedule": [
			{"time": 300.0, "kind": "ossuary_colossus", "name": "COLOSSO DO OSSUÁRIO", "final": false},
			{"time": 600.0, "kind": "glacial_archon", "name": "ARCONTE GLACIAL", "final": false},
			{"time": 900.0, "kind": "infernal_reaper", "name": "CEIFADOR INFERNAL", "final": false},
			{"time": 1200.0, "kind": "void_titan", "name": "TITÃ DO VAZIO", "final": false},
			{"time": 1500.0, "kind": "chaos_sovereign", "name": "SOBERANO DO CAOS", "final": true},
		],
		"world_events": [
			{"time": 150.0, "id": "blood_moon", "title": "EVENTO · LUA DE SANGUE", "duration": 22.0, "spawn_multiplier": 1.65, "ground_modulate": Color("dd7a82"), "burst_sequence": ["assassin", "swarm", "swarm", "assassin", "swarm", "swarm", "assassin", "swarm", "swarm", "assassin"]},
			{"time": 450.0, "id": "soul_storm", "title": "EVENTO · TEMPESTADE DE ALMAS", "duration": 22.0, "pickup_multiplier": 1.8, "ground_modulate": Color("aa8ee0")},
			{"time": 750.0, "id": "eclipse", "title": "EVENTO · ECLIPSE", "duration": 22.0, "enemy_speed_multiplier": 1.28, "ground_modulate": Color("9a75b7")},
			{"time": 1050.0, "id": "blood_moon", "title": "EVENTO · LUA DE SANGUE", "duration": 22.0, "spawn_multiplier": 1.65, "ground_modulate": Color("dd7a82"), "burst_sequence": ["assassin", "swarm", "swarm", "assassin", "swarm", "swarm", "assassin", "swarm", "swarm", "assassin"]},
			{"time": 1350.0, "id": "void_rain", "title": "EVENTO · CHUVA DO VAZIO", "duration": 22.0, "nearby_enemy_damage_ratio": 0.08, "nearby_enemy_damage_radius": 900.0, "ground_modulate": Color("8e72b9")},
		],
		"elite_surges": [
			{"phase_id": "hard", "sequence": ["guardian", "assassin", "bomber", "guardian"]},
			{"phase_id": "chaos", "sequence": ["guardian", "assassin", "bomber", "guardian", "bomber", "assassin", "guardian", "assassin"]},
			{"phase_id": "inferno", "sequence": ["guardian", "assassin", "bomber", "guardian", "bomber", "assassin", "guardian", "assassin", "bomber", "guardian", "bomber", "assassin"]},
		],
		"hazard_profile": {
			"count": 18, "radius_min": 82.0, "radius_max": 138.0, "default_kind": "",
			"kind_by_biome": {"frozen": "ice", "cathedral": "void"},
		},
		"landmark_profile": {
			"kinds": ["altar", "obelisk", "tree", "portal"], "jitter": 130.0,
			"base_positions": [Vector2(1280.0, -920.0), Vector2(-1760.0, -1080.0), Vector2(1580.0, 1710.0), Vector2(-2200.0, 1470.0)],
		},
		"music_profile": {"stages": {"normal": "normal", "hard": "hard", "chaos": "chaos", "inferno": "inferno", "boss": "boss"}},
	},
}

const PROFILE_OVERRIDES := {
	PROFANED_FOREST_PROFILE_ID: {
		"base": LEGACY_PROFILE_ID,
		"data": {
			"id": PROFANED_FOREST_PROFILE_ID,
			"hazard_profile": {
				"count": 0,
				"radius_min": 0.0,
				"radius_max": 0.0,
				"default_kind": "",
				"kind_by_biome": {},
			},
		},
	},
}


static func has_profile(profile_id: String) -> bool:
	return PROFILES.has(profile_id) or PROFILE_OVERRIDES.has(profile_id)


static func profile(profile_id: String) -> Resource:
	var resolved_id := profile_id if has_profile(profile_id) else LEGACY_PROFILE_ID
	if PROFILES.has(resolved_id):
		return MapEncounterProfileScript.new(Dictionary(PROFILES[resolved_id]).duplicate(true))
	var override_definition: Dictionary = PROFILE_OVERRIDES[resolved_id]
	var base_id := str(override_definition.get("base", LEGACY_PROFILE_ID))
	var source: Dictionary = Dictionary(PROFILES[base_id]).duplicate(true)
	source.merge(Dictionary(override_definition.get("data", {})), true)
	return MapEncounterProfileScript.new(source)


static func validate_profile(profile_id: String) -> Array[String]:
	if not has_profile(profile_id):
		return ["[missing_profile] Perfil de encontros inexistente: %s." % profile_id]
	return profile(profile_id).validate()
