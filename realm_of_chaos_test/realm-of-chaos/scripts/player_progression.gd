extends RefCounted


const OFFER_HISTORY_LIMIT := 2
const RECENT_OFFER_MULTIPLIER := 0.32
const OWNED_OFFER_MULTIPLIER := 1.22
const SYNERGY_OFFER_MULTIPLIER := 1.12
const EARLY_DISCOVERY_LEVEL_END := 8
const MID_BUILD_LEVEL_END := 22
const REPEAT_REROLL_ATTEMPTS := 10

var player
var build_complete := false
var offer_rng := RandomNumberGenerator.new()
var offer_seed := 0
var offer_history: Array[Array] = []
var last_offer_signature := ""
var offer_weight_overrides: Dictionary = {}


func _init(owner_player) -> void:
	player = owner_player
	var catalog_errors := GameDefs.evolution_catalog_validation_errors()
	assert(catalog_errors.is_empty(), "Catálogo de evoluções inválido:\n%s" % "\n".join(catalog_errors))
	var instance_entropy := int(player.get_instance_id()) if is_instance_valid(player) else 0
	set_offer_seed(int(Time.get_ticks_usec()) ^ instance_entropy)


func collect_xp(amount: int) -> void:
	player.experience += amount
	while player.experience >= player.experience_needed:
		player.experience -= player.experience_needed
		player.level += 1
		player.experience_needed = int(round(10.0 + pow(player.level, 1.34) * 5.2))
		player.level_up_requested.emit()


func get_upgrade_options(count: int, excluded_ids: Array[String] = []) -> Array[Dictionary]:
	if count <= 0:
		return []
	var pool: Array[Dictionary] = []
	var fallback_pool: Array[Dictionary] = []
	var any_available := false
	for definition in GameDefs.upgrades():
		var upgrade_id := str(definition.id)
		if not upgrade_is_available(definition):
			continue
		any_available = true
		var candidate := definition.duplicate()
		if upgrade_id in excluded_ids:
			fallback_pool.append(candidate)
		else:
			pool.append(candidate)
	build_complete = not any_available
	if pool.size() < count:
		var fallback_needed := count - pool.size()
		pool.append_array(_draw_weighted_definitions(fallback_pool, fallback_needed))
	var option_count := mini(count, pool.size())
	var selected_definitions: Array[Dictionary] = []
	var selected_signature := ""
	for _attempt in range(REPEAT_REROLL_ATTEMPTS):
		selected_definitions = _draw_weighted_definitions(pool, option_count)
		selected_definitions = _ensure_relevant_option(selected_definitions, pool)
		selected_signature = _offer_signature(selected_definitions)
		if selected_signature != last_offer_signature or pool.size() <= option_count:
			break
	var options: Array[Dictionary] = []
	for definition in selected_definitions:
		var upgrade_id := str(definition.id)
		var current := get_upgrade_level(upgrade_id)
		var rarity := roll_rarity()
		var levels_gained := 2 if rarity == "LENDÁRIO" else 1
		definition["current_level"] = current
		definition["level"] = mini(int(definition.max), current + levels_gained)
		definition["levels_gained"] = mini(levels_gained, int(definition.max) - current)
		definition["rarity"] = rarity
		definition["category"] = "NOVA ARMA" if player.weapon_levels.has(upgrade_id) and current == 0 else ("ARMA" if player.weapon_levels.has(upgrade_id) else "PASSIVO")
		definition["offer_weight"] = float(definition.get("offer_weight", 1.0))
		definition["offer_tier"] = str(definition.get("offer_tier", "standard"))
		definition["evolution_hint"] = evolution_hint_for(upgrade_id)
		definition["synergy_items"] = synergy_items_for(upgrade_id)
		options.append(definition)
	if not selected_definitions.is_empty():
		_record_offer(selected_definitions, selected_signature)
	return options


func set_offer_seed(seed_value: int) -> void:
	offer_seed = seed_value
	offer_rng.seed = seed_value
	reset_offer_history()


func reset_offer_history() -> void:
	offer_history.clear()
	last_offer_signature = ""


func set_offer_weight_overrides(overrides: Dictionary) -> void:
	offer_weight_overrides = overrides.duplicate(true)


func _draw_weighted_definitions(source: Array[Dictionary], count: int) -> Array[Dictionary]:
	var available: Array[Dictionary] = source.duplicate()
	var selected: Array[Dictionary] = []
	while not available.is_empty() and selected.size() < count:
		var selected_index := _weighted_definition_index(available)
		selected.append(available[selected_index].duplicate())
		available.remove_at(selected_index)
	return selected


func _weighted_definition_index(definitions: Array[Dictionary]) -> int:
	var weights: Array[float] = []
	var total_weight := 0.0
	for definition in definitions:
		var weight := _candidate_offer_weight(definition)
		weights.append(weight)
		total_weight += weight
	if total_weight <= 0.0:
		return offer_rng.randi_range(0, definitions.size() - 1)
	var roll := offer_rng.randf() * total_weight
	for index in range(definitions.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return index
	return definitions.size() - 1


func _candidate_offer_weight(definition: Dictionary) -> float:
	var upgrade_id := str(definition.id)
	var base_weight := float(offer_weight_overrides.get(upgrade_id, definition.get("offer_weight", 1.0)))
	var weight := maxf(base_weight, 0.0)
	var current_level := get_upgrade_level(upgrade_id)
	var is_owned := current_level > 0
	if is_owned:
		weight *= OWNED_OFFER_MULTIPLIER
	else:
		weight *= _new_item_phase_multiplier()
	if _is_synergy_relevant(upgrade_id):
		weight *= SYNERGY_OFFER_MULTIPLIER
	var recent_count := _recent_offer_count(upgrade_id)
	if recent_count > 0:
		weight *= pow(RECENT_OFFER_MULTIPLIER, recent_count)
	return weight


func _new_item_phase_multiplier() -> float:
	if player.level <= EARLY_DISCOVERY_LEVEL_END:
		return 1.35
	if player.level <= MID_BUILD_LEVEL_END:
		return 0.82
	return 0.48


func _recent_offer_count(upgrade_id: String) -> int:
	var count := 0
	for offered_ids in offer_history:
		if upgrade_id in offered_ids:
			count += 1
	return count


func _is_relevant_option(upgrade_id: String) -> bool:
	return get_upgrade_level(upgrade_id) > 0 or _is_synergy_relevant(upgrade_id)


func _is_synergy_relevant(upgrade_id: String) -> bool:
	if player.weapon_levels.has(upgrade_id):
		var own_recipe := GameDefs.evolution_recipe(upgrade_id)
		for requirement_value in own_recipe.get("requirements", []):
			var requirement := Dictionary(requirement_value)
			if str(requirement.get("kind", "")) == "weapon" and str(requirement.get("id", "")) == upgrade_id:
				continue
			if _requirement_current_level(requirement) > 0:
				return true
	for recipe in GameDefs.evolution_recipes():
		var base_weapon := str(recipe.get("base_weapon", ""))
		if base_weapon == upgrade_id:
			continue
		if int(player.weapon_levels.get(base_weapon, 0)) <= 0 or bool(player.evolved_weapons.get(base_weapon, false)):
			continue
		for requirement_value in recipe.get("requirements", []):
			var requirement := Dictionary(requirement_value)
			if str(requirement.get("id", "")) == upgrade_id:
				return true
	return false


func _ensure_relevant_option(selected: Array[Dictionary], source: Array[Dictionary]) -> Array[Dictionary]:
	if selected.is_empty():
		return selected
	for definition in selected:
		if _is_relevant_option(str(definition.id)):
			return selected
	var selected_ids: Array[String] = []
	for definition in selected:
		selected_ids.append(str(definition.id))
	var relevant_candidates: Array[Dictionary] = []
	for definition in source:
		var upgrade_id := str(definition.id)
		if upgrade_id not in selected_ids and _is_relevant_option(upgrade_id):
			relevant_candidates.append(definition)
	if relevant_candidates.is_empty():
		return selected
	selected[selected.size() - 1] = _draw_weighted_definitions(relevant_candidates, 1)[0]
	return selected


func _offer_signature(definitions: Array[Dictionary]) -> String:
	var ids: Array[String] = []
	for definition in definitions:
		ids.append(str(definition.id))
	ids.sort()
	return "|".join(ids)


func _record_offer(definitions: Array[Dictionary], signature: String) -> void:
	var ids: Array[String] = []
	for definition in definitions:
		ids.append(str(definition.id))
	offer_history.append(ids)
	while offer_history.size() > OFFER_HISTORY_LIMIT:
		offer_history.pop_front()
	last_offer_signature = signature


func evolution_hint_for(upgrade_id: String) -> String:
	var synergy_items := synergy_items_for(upgrade_id)
	if player.weapon_levels.has(upgrade_id):
		if synergy_items.is_empty():
			return ""
		var item: Dictionary = synergy_items[0]
		return "EVOLUI COM %s NV.%d" % [
			GameDefs.upgrade_title(str(item.id)).to_upper(),
			int(item.required_level),
		]
	var synergies: Array[String] = []
	for item in synergy_items:
		synergies.append(GameDefs.upgrade_title(str(item.id)).capitalize())
	if synergies.is_empty():
		return ""
	return "COMBINA COM %s" % ", ".join(synergies)


func synergy_items_for(upgrade_id: String) -> Array[Dictionary]:
	var synergy_items: Array[Dictionary] = []
	var added_ids: Dictionary = {}
	for recipe in GameDefs.evolution_recipes():
		var base_weapon := str(recipe.get("base_weapon", ""))
		if base_weapon == upgrade_id:
			for requirement_value in recipe.get("requirements", []):
				var requirement := Dictionary(requirement_value)
				var requirement_id := str(requirement.get("id", ""))
				if str(requirement.get("kind", "")) == "weapon" and requirement_id == base_weapon:
					continue
				if not added_ids.has(requirement_id):
					synergy_items.append({
						"id": requirement_id,
						"required_level": int(requirement.get("level", 0)),
					})
					added_ids[requirement_id] = true
			continue
		if int(player.weapon_levels.get(base_weapon, 0)) <= 0 or bool(player.evolved_weapons.get(base_weapon, false)):
			continue
		for requirement_value in recipe.get("requirements", []):
			var requirement := Dictionary(requirement_value)
			if str(requirement.get("id", "")) != upgrade_id or added_ids.has(base_weapon):
				continue
			synergy_items.append({
				"id": base_weapon,
				"required_level": 0,
			})
			added_ids[base_weapon] = true
	return synergy_items


func _requirement_current_level(requirement: Dictionary) -> int:
	var item_id := str(requirement.get("id", ""))
	match str(requirement.get("kind", "")):
		"weapon":
			return int(player.weapon_levels.get(item_id, 0))
		"passive":
			return int(player.passive_levels.get(item_id, 0))
	return 0


func active_weapon_count() -> int:
	var count := 0
	for weapon_id in player.WEAPON_IDS:
		if int(player.weapon_levels.get(weapon_id, 0)) > 0:
			count += 1
	return count


func active_passive_count() -> int:
	var count := 0
	for passive_id in player.passive_levels:
		if int(player.passive_levels.get(passive_id, 0)) > 0:
			count += 1
	return count


func is_build_complete() -> bool:
	return build_complete


func refresh_build_complete() -> bool:
	build_complete = not has_available_upgrades()
	return build_complete


func has_available_upgrades() -> bool:
	for definition in GameDefs.upgrades():
		if upgrade_is_available(definition):
			return true
	return false


func upgrade_is_available(definition: Dictionary) -> bool:
	var upgrade_id := str(definition.id)
	if player.banished_upgrades.has(upgrade_id):
		return false
	if (
		player.weapon_levels.has(upgrade_id)
		and int(player.weapon_levels[upgrade_id]) <= 0
		and active_weapon_count() >= player.MAX_WEAPONS
	):
		return false
	if (
		player.passive_levels.has(upgrade_id)
		and int(player.passive_levels[upgrade_id]) <= 0
		and active_passive_count() >= player.MAX_PASSIVES
	):
		return false
	return get_upgrade_level(upgrade_id) < int(definition.max)


func banish_upgrade(upgrade_id: String) -> void:
	player.banished_upgrades[upgrade_id] = true
	refresh_build_complete()


func roll_rarity() -> String:
	var roll := offer_rng.randf()
	if roll < 0.08:
		return "LENDÁRIO"
	if roll < 0.28:
		return "RARO"
	return "COMUM"


func get_upgrade_level(upgrade_id: String) -> int:
	if player.weapon_levels.has(upgrade_id):
		return int(player.weapon_levels[upgrade_id])
	return int(player.passive_levels.get(upgrade_id, 0))


func apply_upgrade(upgrade_id: String, rarity := "COMUM") -> void:
	var bonus := 2 if rarity == "LENDÁRIO" else 1
	if player.weapon_levels.has(upgrade_id):
		if int(player.weapon_levels[upgrade_id]) <= 0 and active_weapon_count() >= player.MAX_WEAPONS:
			return
		player.weapon_levels[upgrade_id] = mini(upgrade_max(upgrade_id), int(player.weapon_levels[upgrade_id]) + bonus)
		check_weapon_evolutions()
		refresh_build_complete()
		return
	var previous_level := int(player.passive_levels.get(upgrade_id, 0))
	if previous_level <= 0 and player.passive_levels.has(upgrade_id) and active_passive_count() >= player.MAX_PASSIVES:
		return
	var new_level := mini(upgrade_max(upgrade_id), previous_level + bonus)
	var applied_levels := new_level - previous_level
	if applied_levels <= 0:
		return
	player.passive_levels[upgrade_id] = new_level
	var rare_upgrade := rarity == "RARO"
	match upgrade_id:
		"might":
			player.damage_multiplier *= 1.22 if rare_upgrade else pow(1.15, applied_levels)
		"haste":
			player.cooldown_multiplier *= 0.84 if rare_upgrade else pow(0.90, applied_levels)
		"vitality":
			var gain := 40.0 if rare_upgrade else 25.0 * applied_levels
			player.max_hp += gain
			player.heal(gain)
		"swiftness":
			player.move_speed *= 1.13 if rare_upgrade else pow(1.08, applied_levels)
		"magnet":
			player.pickup_radius *= 1.55 if rare_upgrade else pow(1.35, applied_levels)
		"armor":
			player.armor += 3.0 if rare_upgrade else 2.0 * applied_levels
		"regeneration":
			player.regeneration += 1.0 if rare_upgrade else 0.65 * applied_levels
		"critical":
			player.crit_chance += 0.11 if rare_upgrade else 0.07 * applied_levels
	check_weapon_evolutions()
	refresh_build_complete()


func upgrade_max(upgrade_id: String) -> int:
	for definition in GameDefs.upgrades():
		if str(definition.id) == upgrade_id:
			return int(definition.max)
	return 8


func check_weapon_evolutions() -> void:
	for weapon_id in player.WEAPON_IDS:
		if bool(player.evolved_weapons[weapon_id]):
			continue
		var recipe := GameDefs.evolution_recipe(weapon_id)
		if recipe.is_empty():
			continue
		if not GameDefs.evolution_requirements_met(recipe, player.weapon_levels, player.passive_levels):
			continue
		player.evolved_weapons[weapon_id] = true
		var world: Node = player.get_tree().get_first_node_in_group("world")
		if world:
			world.on_weapon_evolved(str(recipe.title))


func apply_meta_bonuses(meta: Dictionary) -> void:
	var power_level := int(meta.get("power", 0))
	var vitality_level := int(meta.get("vitality", 0))
	var speed_level := int(meta.get("speed", 0))
	var fortune_level := int(meta.get("fortune", 0))
	player.damage_multiplier *= 1.0 + power_level * 0.05
	player.max_hp += vitality_level * 10.0
	player.hp = player.max_hp
	player.move_speed *= 1.0 + speed_level * 0.03
	player.crit_chance += fortune_level * 0.015


func apply_landmark_blessing(kind: String, duration := 40.0) -> String:
	player.blessing_time = duration
	player.blessing_kind = kind
	player.temporary_damage_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.temporary_move_multiplier = 1.0
	player.temporary_pickup_multiplier = 1.0
	player.temporary_crit_bonus = 0.0
	player.temporary_armor = 0.0
	match kind:
		"altar":
			player.blessing_title = "FÚRIA RUBRA"
			player.temporary_damage_multiplier = 1.32
			player.heal(player.max_hp * 0.25)
		"obelisk":
			player.blessing_title = "FLUXO CRONAL"
			player.temporary_cooldown_multiplier = 0.72
			player.temporary_crit_bonus = 0.12
		"tree":
			player.blessing_title = "CHAMADO DAS ALMAS"
			player.temporary_move_multiplier = 1.24
			player.temporary_pickup_multiplier = 2.6
			player.heal(player.max_hp * 0.12)
		"portal":
			player.blessing_title = "PELE DO VAZIO"
			player.temporary_armor = 7.0
			player.temporary_move_multiplier = 1.12
		_:
			player.blessing_title = "BÊNÇÃO DO MAPA"
	return player.blessing_title


func active_landmark_buffs() -> Array[Dictionary]:
	if player.blessing_time <= 0.0 or player.blessing_title.is_empty():
		return []
	var effect_text := "Bênção temporária"
	match player.blessing_kind:
		"altar":
			effect_text = "+32% dano"
		"obelisk":
			effect_text = "-28% recarga · +12% crítico"
		"tree":
			effect_text = "+24% movimento · ×2,6 coleta"
		"portal":
			effect_text = "+7 armadura · +12% movimento"
	return [{
		"id": player.blessing_kind,
		"name": player.blessing_title,
		"effect": effect_text,
		"remaining": player.blessing_time,
		"permanent": false,
	}]


func apply_character(selected_id: String) -> void:
	if player.character_applied:
		return
	var definition := GameDefs.character_data(selected_id)
	player.character_applied = true
	player.character_id = str(definition.id)
	player.character_color = definition.color
	player.character_skill_name = str(definition.get("skill", "HABILIDADE DO CAÇADOR"))
	player._equip_starting_weapon(str(definition.get("starting_weapon", "chaos_bolt")))
	player._apply_character_visual()
	match player.character_id:
		"glacial_oracle":
			player.armor += 3.0
			player.cooldown_multiplier *= 0.90
		"crimson_knight":
			player.max_hp += 35.0
			player.life_steal += 0.004
		"void_automaton":
			player.damage_multiplier *= 1.18
			player.move_speed *= 1.08
			player.max_hp -= 15.0
		_:
			player.damage_multiplier *= 1.08
			player.crit_chance += 0.05
	player.hp = player.max_hp


func get_relic_options(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for definition in GameDefs.relics():
		if int(player.relic_levels.get(str(definition.id), 0)) < int(definition.max):
			var option := definition.duplicate()
			option["level"] = int(player.relic_levels.get(str(definition.id), 0)) + 1
			pool.append(option)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func apply_relic(relic_id: String) -> void:
	var current := int(player.relic_levels.get(relic_id, 0))
	var maximum := 1
	for definition in GameDefs.relics():
		if str(definition.id) == relic_id:
			maximum = int(definition.max)
			break
	if current >= maximum:
		return
	player.relic_levels[relic_id] = current + 1
	match relic_id:
		"glass_cannon":
			player.damage_multiplier *= 1.30
			player.max_hp *= 0.88
			player.hp = minf(player.hp, player.max_hp)
		"blood_fang":
			player.life_steal += 0.0045
		"storm_crown":
			player.projectile_bonus += 1
			player.damage_multiplier *= 1.08
		"void_boots":
			player.move_speed *= 1.12
			player.dodge_chance += 0.06
		"magnet_core":
			player.pickup_radius *= 1.55
			player.move_speed *= 1.08
		"boss_hunter":
			player.boss_damage_multiplier *= 1.25
		"phoenix_feather":
			player.revive_charges += 1
		"chrono_shard":
			player.cooldown_multiplier *= 0.88
		"iron_heart":
			player.max_hp += 30.0
			player.armor += 2.0
			player.heal(30.0)
		"soul_lens":
			player.crit_chance += 0.10
			player.critical_multiplier += 0.20


func all_weapons_evolved() -> bool:
	var owned_weapons := 0
	for weapon_id in player.WEAPON_IDS:
		if int(player.weapon_levels.get(weapon_id, 0)) <= 0:
			continue
		owned_weapons += 1
		if not bool(player.evolved_weapons.get(weapon_id, false)):
			return false
	return owned_weapons >= player.MAX_WEAPONS


func relic_summary() -> String:
	var names: Array[String] = []
	for definition in GameDefs.relics():
		var relic_level := int(player.relic_levels.get(str(definition.id), 0))
		if relic_level > 0:
			names.append("%s %d" % [str(definition.title).capitalize(), relic_level])
	return "Nenhuma" if names.is_empty() else ", ".join(names)


func grant_boss_reward(final_reward := false) -> void:
	player.damage_multiplier *= 1.08 if final_reward else 1.045
	player.max_hp += 12.0 if final_reward else 5.0
	player.heal(player.max_hp * (0.35 if final_reward else 0.18))


func weapon_summary() -> String:
	var names: Array[String] = []
	if player.weapon_levels.chaos_bolt > 0:
		names.append("BALISTA ✦" if player.evolved_weapons.chaos_bolt else "Besta %d" % player.weapon_levels.chaos_bolt)
	if player.weapon_levels.shadow_blades > 0:
		names.append("DANÇA ◆" if player.evolved_weapons.shadow_blades else "Lâmina %d" % player.weapon_levels.shadow_blades)
	if player.weapon_levels.soul_orbit > 0:
		names.append("DEVORADOR ◉" if player.evolved_weapons.soul_orbit else "Cetro %d" % player.weapon_levels.soul_orbit)
	if player.weapon_levels.chaos_nova > 0:
		names.append("COLAPSO ☼" if player.evolved_weapons.chaos_nova else "Cajado %d" % player.weapon_levels.chaos_nova)
	if player.weapon_levels.blood_scythe > 0:
		names.append("CEIFADORA ☾" if player.evolved_weapons.blood_scythe else "Foice %d" % player.weapon_levels.blood_scythe)
	if player.weapon_levels.forbidden_grimoire > 0:
		names.append("CÓDICE ▤" if player.evolved_weapons.forbidden_grimoire else "Grimório %d" % player.weapon_levels.forbidden_grimoire)
	if player.weapon_levels.rune_hammer > 0:
		names.append("CATACLISMO ◆" if player.evolved_weapons.rune_hammer else "Martelo %d" % player.weapon_levels.rune_hammer)
	if player.weapon_levels.storm_relic > 0:
		names.append("TEMPESTADE ϟ" if player.evolved_weapons.storm_relic else "Relíquia %d" % player.weapon_levels.storm_relic)
	if player.weapon_levels.swarm_idol > 0:
		names.append("LEGIÃO ◉" if player.evolved_weapons.swarm_idol else "Ídolo %d" % player.weapon_levels.swarm_idol)
	if names.size() <= 3:
		return "  ·  ".join(names)
	return "%s\n%s" % ["  ·  ".join(names.slice(0, 3)), "  ·  ".join(names.slice(3))]
