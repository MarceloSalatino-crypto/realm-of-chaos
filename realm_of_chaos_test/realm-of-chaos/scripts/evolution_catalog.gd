extends RefCounted


const SLOT_POLICY_UPGRADE_BASE := "upgrade_base"
const SUPPORTED_REQUIREMENT_KINDS: Array[String] = ["weapon", "passive"]
const SUPPORTED_SLOT_POLICIES: Array[String] = [SLOT_POLICY_UPGRADE_BASE]

const RECIPES: Array[Dictionary] = [
	{
		"id": "abyssal_ballista",
		"title": "BALISTA ABISSAL",
		"base_weapon": "chaos_bolt",
		"slot_policy": SLOT_POLICY_UPGRADE_BASE,
		"requirements": [
			{"kind": "weapon", "id": "chaos_bolt", "level": 8},
			{"kind": "passive", "id": "critical", "level": 3},
		],
	},
	{
		"id": "shadow_dance",
		"title": "DANÇA DAS SOMBRAS",
		"base_weapon": "shadow_blades",
		"slot_policy": SLOT_POLICY_UPGRADE_BASE,
		"requirements": [
			{"kind": "weapon", "id": "shadow_blades", "level": 6},
			{"kind": "passive", "id": "swiftness", "level": 3},
		],
	},
	{
		"id": "soul_devourer",
		"title": "DEVORADOR DE ESPÍRITOS",
		"base_weapon": "soul_orbit",
		"slot_policy": SLOT_POLICY_UPGRADE_BASE,
		"requirements": [
			{"kind": "weapon", "id": "soul_orbit", "level": 6},
			{"kind": "passive", "id": "regeneration", "level": 3},
		],
	},
	{
		"id": "void_collapse",
		"title": "COLAPSO DO VAZIO",
		"base_weapon": "chaos_nova",
		"slot_policy": SLOT_POLICY_UPGRADE_BASE,
		"requirements": [
			{"kind": "weapon", "id": "chaos_nova", "level": 6},
			{"kind": "passive", "id": "might", "level": 3},
		],
	},
	{
		"id": "crimson_reaper",
		"title": "CEIFADORA CARMESIM",
		"base_weapon": "blood_scythe",
		"slot_policy": SLOT_POLICY_UPGRADE_BASE,
		"requirements": [
			{"kind": "weapon", "id": "blood_scythe", "level": 6},
			{"kind": "passive", "id": "vitality", "level": 3},
		],
	},
	{
		"id": "codex_of_the_end",
		"title": "CÓDICE DO FIM",
		"base_weapon": "forbidden_grimoire",
		"slot_policy": SLOT_POLICY_UPGRADE_BASE,
		"requirements": [
			{"kind": "weapon", "id": "forbidden_grimoire", "level": 6},
			{"kind": "passive", "id": "magnet", "level": 3},
		],
	},
	{
		"id": "cataclysm_hammer",
		"title": "MARTELO DO CATACLISMO",
		"base_weapon": "rune_hammer",
		"slot_policy": SLOT_POLICY_UPGRADE_BASE,
		"requirements": [
			{"kind": "weapon", "id": "rune_hammer", "level": 6},
			{"kind": "passive", "id": "armor", "level": 3},
		],
	},
	{
		"id": "eternal_storm",
		"title": "TEMPESTADE ETERNA",
		"base_weapon": "storm_relic",
		"slot_policy": SLOT_POLICY_UPGRADE_BASE,
		"requirements": [
			{"kind": "weapon", "id": "storm_relic", "level": 6},
			{"kind": "passive", "id": "haste", "level": 3},
		],
	},
	{
		"id": "eye_of_the_legion",
		"title": "OLHO DA LEGIÃO",
		"base_weapon": "swarm_idol",
		"slot_policy": SLOT_POLICY_UPGRADE_BASE,
		"requirements": [
			{"kind": "weapon", "id": "swarm_idol", "level": 6},
			{"kind": "passive", "id": "regeneration", "level": 3},
		],
	},
]


static func recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe in RECIPES:
		result.append(recipe.duplicate(true))
	return result


static func recipe_for_weapon(weapon_id: String) -> Dictionary:
	for recipe in RECIPES:
		if str(recipe.get("base_weapon", "")) == weapon_id:
			return recipe.duplicate(true)
	return {}


static func required_level(recipe: Dictionary, kind: String, item_id: String) -> int:
	for requirement_value in recipe.get("requirements", []):
		var requirement := Dictionary(requirement_value)
		if str(requirement.get("kind", "")) == kind and str(requirement.get("id", "")) == item_id:
			return int(requirement.get("level", 0))
	return 0


static func requirements_met(recipe: Dictionary, weapon_levels: Dictionary, passive_levels: Dictionary) -> bool:
	if recipe.is_empty():
		return false
	for requirement_value in recipe.get("requirements", []):
		var requirement := Dictionary(requirement_value)
		var item_id := str(requirement.get("id", ""))
		var required := int(requirement.get("level", 0))
		match str(requirement.get("kind", "")):
			"weapon":
				if int(weapon_levels.get(item_id, 0)) < required:
					return false
			"passive":
				if int(passive_levels.get(item_id, 0)) < required:
					return false
			_:
				return false
	return true


static func legacy_data(weapon_id: String) -> Dictionary:
	var recipe := recipe_for_weapon(weapon_id)
	if recipe.is_empty():
		return {}
	var passive_requirement: Dictionary = {}
	for requirement_value in recipe.requirements:
		var requirement := Dictionary(requirement_value)
		if str(requirement.get("kind", "")) == "passive":
			passive_requirement = requirement
			break
	if passive_requirement.is_empty():
		return {}
	return {
		"title": str(recipe.title),
		"passive": str(passive_requirement.id),
		"weapon_level": required_level(recipe, "weapon", weapon_id),
		"passive_level": int(passive_requirement.level),
	}


static func validation_errors(
	recipes_to_validate: Array,
	weapon_ids: Array[String],
	passive_ids: Array[String],
	max_levels: Dictionary,
	require_all_weapons := false
) -> Array[String]:
	var errors: Array[String] = []
	var recipe_ids: Dictionary = {}
	var base_weapons: Dictionary = {}
	for recipe_index in range(recipes_to_validate.size()):
		var value = recipes_to_validate[recipe_index]
		if not value is Dictionary:
			errors.append("Receita %d não é um Dictionary." % recipe_index)
			continue
		var recipe := Dictionary(value)
		var context := "Receita %d" % recipe_index
		var recipe_id := str(recipe.get("id", ""))
		var title := str(recipe.get("title", ""))
		var base_weapon := str(recipe.get("base_weapon", ""))
		var slot_policy := str(recipe.get("slot_policy", ""))
		if recipe_id.is_empty():
			errors.append("%s não possui id." % context)
		elif recipe_ids.has(recipe_id):
			errors.append("ID de receita duplicado: %s." % recipe_id)
		else:
			recipe_ids[recipe_id] = true
		if title.is_empty():
			errors.append("%s não possui título." % context)
		if base_weapon not in weapon_ids:
			errors.append("%s aponta para arma-base inexistente: %s." % [context, base_weapon])
		elif base_weapons.has(base_weapon):
			errors.append("Arma-base possui mais de uma receita: %s." % base_weapon)
		else:
			base_weapons[base_weapon] = true
		if slot_policy not in SUPPORTED_SLOT_POLICIES:
			errors.append("%s usa política de slot inválida: %s." % [context, slot_policy])
		var requirements = recipe.get("requirements", [])
		if not requirements is Array or requirements.is_empty():
			errors.append("%s não possui requisitos válidos." % context)
			continue
		var requirement_keys: Dictionary = {}
		var has_base_requirement := false
		for requirement_index in range(requirements.size()):
			var requirement_value = requirements[requirement_index]
			if not requirement_value is Dictionary:
				errors.append("%s possui requisito %d inválido." % [context, requirement_index])
				continue
			var requirement := Dictionary(requirement_value)
			var kind := str(requirement.get("kind", ""))
			var item_id := str(requirement.get("id", ""))
			var level := int(requirement.get("level", 0))
			var key := "%s:%s" % [kind, item_id]
			if kind not in SUPPORTED_REQUIREMENT_KINDS:
				errors.append("%s possui tipo de requisito inválido: %s." % [context, kind])
				continue
			if requirement_keys.has(key):
				errors.append("%s repete o requisito %s." % [context, key])
			else:
				requirement_keys[key] = true
			var valid_ids := weapon_ids if kind == "weapon" else passive_ids
			if item_id not in valid_ids:
				errors.append("%s aponta para %s inexistente: %s." % [context, kind, item_id])
			if level <= 0:
				errors.append("%s possui nível inválido para %s: %d." % [context, key, level])
			elif max_levels.has(item_id) and level > int(max_levels[item_id]):
				errors.append("%s exige %s acima do máximo: %d > %d." % [context, key, level, int(max_levels[item_id])])
			if kind == "weapon" and item_id == base_weapon:
				has_base_requirement = true
		if not has_base_requirement:
			errors.append("%s não exige a própria arma-base %s." % [context, base_weapon])
	if require_all_weapons:
		for weapon_id in weapon_ids:
			if not base_weapons.has(weapon_id):
				errors.append("Arma sem receita de evolução: %s." % weapon_id)
	return errors
