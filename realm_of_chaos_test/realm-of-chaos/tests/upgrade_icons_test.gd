extends SceneTree

const HUD_SCENE = preload("res://scenes/hud.tscn")
const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1024, 576),
	Vector2i(960, 540),
	Vector2i(800, 450),
	Vector2i(640, 360),
]
const DISPLAYED_IDS := ["chaos_bolt", "forbidden_grimoire", "regeneration"]
const EXPECTED_SYNERGIES := [
	[{"id": "critical", "required_level": 3}],
	[{"id": "magnet", "required_level": 3}],
	[
		{"id": "soul_orbit", "required_level": 0},
		{"id": "swarm_idol", "required_level": 0},
	],
]

var failures: Array[String] = []
var capture_dir := ""


func _initialize() -> void:
	capture_dir = OS.get_environment("ROC_UPGRADE_ICON_CAPTURE_DIR")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("UPGRADE ICONS: " + message)


func _run() -> void:
	for viewport_size in VIEWPORT_SIZES:
		await _validate_viewport(viewport_size)
	if failures.is_empty():
		print("UPGRADE ICONS OK: cartas compactas, selos e sinergias validados em 5 resoluções")
		quit(0)
	else:
		quit(1)


func _validate_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var hud = HUD_SCENE.instantiate()
	viewport.add_child(hud)
	await _settle()
	var options := _upgrade_options()
	hud.show_level_up(99, options)
	await _settle()

	_check(hud.upgrade_icon_rects.size() == 3, "HUD não criou três TextureRects")
	for index in range(DISPLAYED_IDS.size()):
		var icon_rect: TextureRect = hud.upgrade_icon_rects[index]
		var upgrade_id: String = DISPLAYED_IDS[index]
		var expected_path := "res://assets/ui/upgrade_icons/%s.png" % upgrade_id
		_check(icon_rect.texture != null, "%s ficou sem textura" % upgrade_id)
		if icon_rect.texture:
			_check(
				icon_rect.texture.resource_path == expected_path,
				"%s carregou caminho incorreto em %dx%d" % [
					upgrade_id, viewport_size.x, viewport_size.y
				]
			)
		_check(
			icon_rect.position.x >= -0.6
			and icon_rect.position.y >= -0.6
			and icon_rect.position.x + icon_rect.size.x <= hud.upgrade_buttons[index].size.x + 0.6
			and icon_rect.position.y + icon_rect.size.y <= hud.upgrade_buttons[index].size.y + 0.6,
			"%s saiu dos limites da carta em %dx%d" % [
				upgrade_id, viewport_size.x, viewport_size.y
			]
		)
		var summary_label: Label = hud.upgrade_summary_labels[index]
		var effect_label: Label = hud.upgrade_effect_labels[index]
		var rarity_label: Label = hud.upgrade_rarity_labels[index]
		_check(
			summary_label.text == "%s — %s · Nv 4/%d" % [
				options[index].title,
				"Passivo" if upgrade_id == "regeneration" else "Arma",
				int(options[index].max),
			],
			"%s exibiu resumo incorreto em %dx%d" % [
				upgrade_id, viewport_size.x, viewport_size.y
			]
		)
		_check(
			"\n" not in summary_label.text
			and effect_label.text == str(options[index].short_description)
			and "\n" not in effect_label.text,
			"%s não manteve as duas linhas compactas em %dx%d" % [
				upgrade_id, viewport_size.x, viewport_size.y
			]
		)
		_check(
			rarity_label.text == "LENDÁRIO"
			and hud.upgrade_rarity_badges[index].visible,
			"%s perdeu o selo de raridade" % upgrade_id
		)
		_check(
			hud.upgrade_buttons[index].text.is_empty()
			and "TEXTO LEGADO" not in summary_label.text
			and "TEXTO LEGADO" not in effect_label.text,
			"%s ainda exibiu o bloco textual antigo" % upgrade_id
		)
		_validate_synergy_row(
			hud.upgrade_synergy_rows[index],
			EXPECTED_SYNERGIES[index],
			viewport_size,
			upgrade_id
		)

	if not capture_dir.is_empty():
		RenderingServer.force_draw(false)
		await process_frame
		var image = viewport.get_texture().get_image()
		_check(image != null, "renderer não forneceu imagem em %dx%d" % [viewport_size.x, viewport_size.y])
		if image != null:
			_check(not image.is_empty(), "captura vazia em %dx%d" % [viewport_size.x, viewport_size.y])
		if image != null and not image.is_empty():
			var output_path := capture_dir.path_join(
				"level_up_icons_%dx%d.png" % [viewport_size.x, viewport_size.y]
			)
			_check(image.save_png(output_path) == OK, "falha ao salvar " + output_path)

	root.remove_child(viewport)
	viewport.queue_free()
	await process_frame


func _validate_synergy_row(
	row: HBoxContainer, expected_items: Array, viewport_size: Vector2i, upgrade_id: String
) -> void:
	_check(
		row.visible and row.get_child_count() == expected_items.size(),
		"%s exibiu %d sinergias, esperado %d em %dx%d" % [
			upgrade_id, row.get_child_count(), expected_items.size(),
			viewport_size.x, viewport_size.y,
		]
	)
	for index in range(mini(row.get_child_count(), expected_items.size())):
		var holder := row.get_child(index) as Control
		var expected: Dictionary = expected_items[index]
		var synergy_id := str(expected.id)
		var required_level := int(expected.required_level)
		var synergy_icon := holder.get_node("Icon") as TextureRect
		var required_label := holder.get_node("RequiredLevel") as Label
		_check(
			str(holder.get_meta("upgrade_id", "")) == synergy_id
			and int(holder.get_meta("required_level", -1)) == required_level,
			"%s entregou metadados incorretos para %s" % [upgrade_id, synergy_id]
		)
		_check(
			synergy_icon.texture != null
			and synergy_icon.texture.resource_path == (
				"res://assets/ui/upgrade_icons/%s.png" % synergy_id
			),
			"%s carregou ícone de sinergia incorreto" % synergy_id
		)
		_check(
			holder.tooltip_text.begins_with(GameDefs.upgrade_title(synergy_id)),
			"%s perdeu o tooltip com nome completo" % synergy_id
		)
		_check(
			holder.size.x >= 28.0 and holder.size.x <= 32.0
			and holder.size.y >= 28.0 and holder.size.y <= 32.0,
			"%s ficou fora de 28-32 px em %dx%d" % [
				synergy_id, viewport_size.x, viewport_size.y
			]
		)
		_check(
			required_label.visible == (required_level > 0)
			and (
				required_level == 0
				or required_label.text == "Nv %d" % required_level
			),
			"%s exibiu selo de nível incorreto" % synergy_id
		)


func _upgrade_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for index in range(DISPLAYED_IDS.size()):
		var upgrade_id: String = DISPLAYED_IDS[index]
		var option: Dictionary = _definition(upgrade_id).duplicate()
		option["current_level"] = 2
		option["level"] = 4
		option["levels_gained"] = 2
		option["rarity"] = "LENDÁRIO"
		option["category"] = "PASSIVO" if upgrade_id == "regeneration" else "ARMA"
		option["evolution_hint"] = "TEXTO LEGADO QUE NÃO DEVE APARECER"
		option["synergy_items"] = EXPECTED_SYNERGIES[index].duplicate(true)
		options.append(option)
	return options


func _definition(upgrade_id: String) -> Dictionary:
	for definition in GameDefs.upgrades():
		if str(definition.id) == upgrade_id:
			return definition
	return {}


func _settle(frame_count := 4) -> void:
	for _frame in range(frame_count):
		await process_frame
