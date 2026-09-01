class_name MapEncounterProfile
extends Resource


var profile_id := ""
var duration := 1500.0
var difficulty_phases: Array[Dictionary] = []
var enemy_phases: Array[Dictionary] = []
var boss_schedule: Array[Dictionary] = []
var world_events: Array[Dictionary] = []
var elite_surges: Array[Dictionary] = []
var hazard_profile: Dictionary = {}
var landmark_profile: Dictionary = {}
var music_profile: Dictionary = {}


func _init(source: Dictionary = {}) -> void:
	profile_id = str(source.get("id", ""))
	duration = float(source.get("duration", 1500.0))
	difficulty_phases = _dictionary_array(source.get("difficulty_phases", []))
	enemy_phases = _dictionary_array(source.get("enemy_phases", []))
	boss_schedule = _dictionary_array(source.get("boss_schedule", []))
	world_events = _dictionary_array(source.get("world_events", []))
	elite_surges = _dictionary_array(source.get("elite_surges", []))
	hazard_profile = Dictionary(source.get("hazard_profile", {})).duplicate(true)
	landmark_profile = Dictionary(source.get("landmark_profile", {})).duplicate(true)
	music_profile = Dictionary(source.get("music_profile", {})).duplicate(true)


func difficulty_at(elapsed: float) -> Dictionary:
	if difficulty_phases.is_empty():
		return {}
	var selected: Dictionary = difficulty_phases[-1]
	for phase in difficulty_phases:
		if elapsed < float(phase.get("end", duration)):
			selected = phase
			break
	var start := float(selected.get("start", 0.0))
	var finish := float(selected.get("end", duration))
	var progress := clampf((elapsed - start) / maxf(finish - start, 0.001), 0.0, 1.0)
	return {
		"id": str(selected.get("id", "normal")),
		"name": str(selected.get("name", "")),
		"color": Color(selected.get("color", Color.WHITE)),
		"interval": lerpf(float(selected.get("interval_start", 1.0)), float(selected.get("interval_end", 1.0)), progress),
		"batch": int(selected.get("batch_base", 1)) + int(progress * float(selected.get("batch_growth", 0))),
		"cap": roundi(lerpf(float(selected.get("cap_start", 60)), float(selected.get("cap_end", 60)), progress)),
		"power": lerpf(float(selected.get("power_start", 1.0)), float(selected.get("power_end", 1.0)), progress),
		"elite_chance": lerpf(float(selected.get("elite_start", 0.0)), float(selected.get("elite_end", 0.0)), progress),
	}


func stage_name(elapsed: float) -> String:
	return str(difficulty_at(elapsed).get("name", ""))


func enemy_choices_at(elapsed: float) -> Array[String]:
	if enemy_phases.is_empty():
		return ["prowler"]
	var selected: Dictionary = enemy_phases[-1]
	for phase in enemy_phases:
		if elapsed >= float(phase.get("start", 0.0)) and elapsed < float(phase.get("end", duration + 0.001)):
			selected = phase
			break
	var choices: Array[String] = []
	for enemy_id in Array(selected.get("choices", [])):
		choices.append(str(enemy_id))
	return choices if not choices.is_empty() else ["prowler"]


func event_at(index: int) -> Dictionary:
	if index < 0 or index >= world_events.size():
		return {}
	return world_events[index].duplicate(true)


func event_by_id(event_id: String) -> Dictionary:
	for entry in world_events:
		if str(entry.get("id", "")) == event_id:
			return entry.duplicate(true)
	return {}


func elite_surge_for_phase(phase_id: String) -> Dictionary:
	for surge in elite_surges:
		if str(surge.get("phase_id", "")) == phase_id:
			return surge.duplicate(true)
	return {}


func hazard_kind_for_biome(biome_id: String) -> String:
	var kinds: Dictionary = hazard_profile.get("kind_by_biome", {})
	return str(kinds.get(biome_id, hazard_profile.get("default_kind", "")))


func music_stage_for(phase_id: String) -> String:
	var stages: Dictionary = music_profile.get("stages", {})
	return str(stages.get(phase_id, phase_id))


func validate() -> Array[String]:
	var errors: Array[String] = []
	if profile_id.is_empty():
		errors.append("[missing_id] O perfil não possui id.")
	if duration <= 0.0:
		errors.append("[invalid_duration] A duração deve ser positiva.")
	if difficulty_phases.is_empty():
		errors.append("[missing_difficulty] O perfil não possui fases de dificuldade.")
	if enemy_phases.is_empty():
		errors.append("[missing_enemy_phases] O perfil não possui fases de inimigos.")
	if boss_schedule.is_empty():
		errors.append("[missing_bosses] O perfil não possui agenda de bosses.")
	var final_count := 0
	var previous_boss_time := -1.0
	for entry in boss_schedule:
		var boss_time := float(entry.get("time", -1.0))
		if boss_time <= previous_boss_time or boss_time > duration:
			errors.append("[invalid_boss_time] A agenda de bosses não é crescente ou excede a duração.")
		previous_boss_time = boss_time
		if bool(entry.get("final", false)):
			final_count += 1
	if final_count != 1:
		errors.append("[invalid_final_boss] O perfil deve possuir exatamente um boss final.")
	var previous_event_time := -1.0
	for entry in world_events:
		var event_time := float(entry.get("time", -1.0))
		if event_time <= previous_event_time or event_time > duration:
			errors.append("[invalid_event_time] A agenda de eventos não é crescente ou excede a duração.")
		previous_event_time = event_time
	return errors


static func _dictionary_array(value) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in Array(value):
		result.append(Dictionary(entry).duplicate(true))
	return result
