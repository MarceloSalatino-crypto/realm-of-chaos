extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")

const RARITIES := ["COMUM", "RARO", "LENDÁRIO"]
const PASSIVE_CASES := [
	{
		"id": "might", "property": "damage_multiplier", "mode": "multiply",
		"base": 1.0, "common": 1.15, "rare": 1.22,
	},
	{
		"id": "haste", "property": "cooldown_multiplier", "mode": "multiply",
		"base": 1.0, "common": 0.90, "rare": 0.84,
	},
	{
		"id": "vitality", "property": "max_hp", "mode": "add",
		"base": 125.0, "common": 25.0, "rare": 40.0,
	},
	{
		"id": "swiftness", "property": "move_speed", "mode": "multiply",
		"base": 235.0, "common": 1.08, "rare": 1.13,
	},
	{
		"id": "magnet", "property": "pickup_radius", "mode": "multiply",
		"base": 105.0, "common": 1.35, "rare": 1.55,
	},
	{
		"id": "armor", "property": "armor", "mode": "add",
		"base": 0.0, "common": 2.0, "rare": 3.0,
	},
	{
		"id": "regeneration", "property": "regeneration", "mode": "add",
		"base": 0.0, "common": 0.65, "rare": 1.0,
	},
	{
		"id": "critical", "property": "crit_chance", "mode": "add",
		"base": 0.05, "common": 0.07, "rare": 0.11,
	},
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("UPGRADE RARITY: " + message)


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	var player = world.player
	player.set_process(false)
	player.set_physics_process(false)
	var hud = world.hud

	_test_passive_rarities(player, hud)
	_test_passive_level_cap(player, hud)
	_test_weapon_equivalence(player)
	_test_weapon_card_icons(player, hud)

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("UPGRADE RARITY OK: 8 passivos, 3 raridades, limite de nível e 9 armas validados")
		quit(0)
	else:
		quit(1)


func _test_passive_rarities(player: Node, hud: CanvasLayer) -> void:
	for passive_case in PASSIVE_CASES:
		for rarity in RARITIES:
			_reset_player_state(player)
			var passive_id := str(passive_case.id)
			player.apply_upgrade(passive_id, rarity)
			var expected_levels := 2 if rarity == "LENDÁRIO" else 1
			_check(
				int(player.passive_levels[passive_id]) == expected_levels,
				"%s %s registrou nível incorreto" % [passive_id, rarity]
			)
			var expected_value := _expected_passive_value(passive_case, rarity, expected_levels)
			var actual_value := float(player.get(str(passive_case.property)))
			_check(
				is_equal_approx(actual_value, expected_value),
				"%s %s aplicou %.6f; esperado %.6f" % [
					passive_id, rarity, actual_value, expected_value
				]
			)
			if passive_id == "vitality":
				var expected_hp := 50.0 + _passive_addition(passive_case, rarity, expected_levels)
				_check(
					is_equal_approx(float(player.hp), expected_hp),
					"vitality %s curou %.2f; esperado %.2f" % [rarity, player.hp, expected_hp]
				)
			_validate_upgrade_card(hud, passive_id, rarity, expected_levels, expected_levels)


func _test_passive_level_cap(player: Node, hud: CanvasLayer) -> void:
	for passive_case in PASSIVE_CASES:
		_reset_player_state(player)
		var passive_id := str(passive_case.id)
		player.passive_levels[passive_id] = 4
		player.apply_upgrade(passive_id, "LENDÁRIO")
		_check(
			int(player.passive_levels[passive_id]) == 5,
			"%s lendário ultrapassou ou não alcançou o limite 5" % passive_id
		)
		var expected_value := _expected_passive_value(passive_case, "COMUM", 1)
		var actual_value := float(player.get(str(passive_case.property)))
		_check(
			is_equal_approx(actual_value, expected_value),
			"%s 4→5 não aplicou exatamente um nível comum" % passive_id
		)
		if passive_id == "vitality":
			_check(is_equal_approx(float(player.hp), 75.0), "vitality 4→5 não curou 25")
		_validate_upgrade_card(hud, passive_id, "LENDÁRIO", 5, 1)
		var capped_value := actual_value
		var capped_hp := float(player.hp)
		player.apply_upgrade(passive_id, "LENDÁRIO")
		_check(
			int(player.passive_levels[passive_id]) == 5,
			"%s aceitou nível acima do máximo" % passive_id
		)
		_check(
			is_equal_approx(float(player.get(str(passive_case.property))), capped_value),
			"%s reaplicou atributo já estando no máximo" % passive_id
		)
		if passive_id == "vitality":
			_check(is_equal_approx(float(player.hp), capped_hp), "vitality curou novamente no máximo")


func _test_weapon_equivalence(player: Node) -> void:
	for weapon_id in player.WEAPON_IDS:
		_prepare_weapon_state(player, weapon_id, 0, false)
		player.apply_upgrade(weapon_id, "LENDÁRIO")
		var legendary_low_level := int(player.weapon_levels[weapon_id])
		var legendary_low_evolved := bool(player.evolved_weapons[weapon_id])
		_prepare_weapon_state(player, weapon_id, 0, false)
		player.apply_upgrade(weapon_id, "COMUM")
		player.apply_upgrade(weapon_id, "COMUM")
		_check(
			int(player.weapon_levels[weapon_id]) == legendary_low_level
			and bool(player.evolved_weapons[weapon_id]) == legendary_low_evolved,
			"%s lendária divergiu de duas comuns no nível inicial" % weapon_id
		)

		var maximum_level: int = player._upgrade_max(weapon_id)
		_prepare_weapon_state(player, weapon_id, maximum_level - 2, true)
		player.apply_upgrade(weapon_id, "LENDÁRIO")
		var legendary_max_level := int(player.weapon_levels[weapon_id])
		var legendary_max_evolved := bool(player.evolved_weapons[weapon_id])
		_prepare_weapon_state(player, weapon_id, maximum_level - 2, true)
		player.apply_upgrade(weapon_id, "COMUM")
		player.apply_upgrade(weapon_id, "COMUM")
		_check(
			int(player.weapon_levels[weapon_id]) == legendary_max_level
			and bool(player.evolved_weapons[weapon_id]) == legendary_max_evolved,
			"%s lendária divergiu de duas comuns no nível máximo/evolução" % weapon_id
		)
		_check(
			legendary_max_level == maximum_level and legendary_max_evolved,
			"%s não atingiu nível máximo e evolução no teste lendário" % weapon_id
		)


func _test_weapon_card_icons(player: Node, hud: CanvasLayer) -> void:
	for weapon_id in player.WEAPON_IDS:
		var option := _upgrade_definition(weapon_id).duplicate()
		option["current_level"] = 0
		option["level"] = 1
		option["levels_gained"] = 1
		option["rarity"] = "COMUM"
		option["category"] = "NOVA ARMA"
		option["evolution_hint"] = ""
		option["synergy_items"] = []
		var options: Array[Dictionary] = [option]
		hud.show_level_up(2, options)
		_check_upgrade_icon(hud, weapon_id)
		hud.hide_level_up()


func _prepare_weapon_state(player: Node, weapon_id: String, weapon_level: int, unlock_evolution: bool) -> void:
	_reset_player_state(player)
	player.weapon_levels[weapon_id] = weapon_level
	if not unlock_evolution:
		return
	var evolution: Dictionary = GameDefs.evolution_data(weapon_id)
	player.passive_levels[str(evolution.passive)] = int(evolution.passive_level)


func _validate_upgrade_card(
	hud: CanvasLayer, passive_id: String, rarity: String, resulting_level: int, levels_gained: int
) -> void:
	var option := _upgrade_definition(passive_id).duplicate()
	option["current_level"] = resulting_level - levels_gained
	option["level"] = resulting_level
	option["levels_gained"] = levels_gained
	option["rarity"] = rarity
	option["category"] = "PASSIVO"
	option["evolution_hint"] = ""
	option["synergy_items"] = []
	var options: Array[Dictionary] = [option]
	hud.show_level_up(2, options)
	_check_upgrade_icon(hud, passive_id)
	var summary_text := str(hud.upgrade_summary_labels[0].text)
	var effect_text := str(hud.upgrade_effect_labels[0].text)
	var rarity_text := str(hud.upgrade_rarity_labels[0].text)
	_check(
		effect_text == str(option.short_description),
		"%s %s não exibiu a descrição curta cadastrada" % [passive_id, rarity]
	)
	_check(
		("Nv %d/%d" % [resulting_level, int(option.max)]) in summary_text,
		"%s %s exibiu nível incorreto na carta" % [passive_id, rarity]
	)
	_check(
		rarity_text == rarity and hud.upgrade_rarity_badges[0].visible,
		"%s %s não exibiu o selo de raridade" % [passive_id, rarity]
	)
	_check(
		"+2" not in summary_text and hud.upgrade_buttons[0].text.is_empty(),
		"%s %s manteve informação repetida na carta compacta" % [passive_id, rarity]
	)
	hud.hide_level_up()


func _check_upgrade_icon(hud: CanvasLayer, upgrade_id: String) -> void:
	var icon_rect: TextureRect = hud.upgrade_icon_rects[0]
	var expected_path := "res://assets/ui/upgrade_icons/%s.png" % upgrade_id
	_check(icon_rect.texture != null, "%s não exibiu ícone" % upgrade_id)
	if icon_rect.texture:
		_check(
			icon_rect.texture.resource_path == expected_path,
			"%s exibiu %s em vez de %s" % [
				upgrade_id, icon_rect.texture.resource_path, expected_path
			]
		)


func _upgrade_definition(upgrade_id: String) -> Dictionary:
	for definition in GameDefs.upgrades():
		if str(definition.id) == upgrade_id:
			return definition
	return {}


func _expected_passive_value(passive_case: Dictionary, rarity: String, applied_levels: int) -> float:
	var base := float(passive_case.base)
	if str(passive_case.mode) == "multiply":
		var factor := (
			float(passive_case.rare)
			if rarity == "RARO"
			else pow(float(passive_case.common), applied_levels)
		)
		return base * factor
	return base + _passive_addition(passive_case, rarity, applied_levels)


func _passive_addition(passive_case: Dictionary, rarity: String, applied_levels: int) -> float:
	return (
		float(passive_case.rare)
		if rarity == "RARO"
		else float(passive_case.common) * applied_levels
	)


func _reset_player_state(player: Node) -> void:
	player.damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.max_hp = 125.0
	player.hp = 50.0
	player.move_speed = 235.0
	player.pickup_radius = 105.0
	player.armor = 0.0
	player.regeneration = 0.0
	player.crit_chance = 0.05
	for passive_id in player.passive_levels:
		player.passive_levels[passive_id] = 0
	for weapon_id in player.weapon_levels:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
