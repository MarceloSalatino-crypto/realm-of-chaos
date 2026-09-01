extends Node

const WORLD_SCENE := preload("res://scenes/world.tscn")
const FOREST_SLICE_SCRIPT := preload("res://scripts/forest_vertical_slice.gd")
const FROZEN_SLICE_SCRIPT := preload("res://scripts/frozen_vertical_slice.gd")
const COLLISION_DEBUG_OVERLAY_SCRIPT := preload("res://scripts/environment_collision_debug_overlay.gd")

const SLICE_DEFINITIONS := {
	"forest_production": {
		"title": "BOSQUE PROFANADO · PRODUÇÃO",
		"subtitle": "world.tscn real · campanha completa em memória · save protegido",
		"script": null,
		"mode": "production",
	},
	"forest": {
		"title": "BOSQUE PROFANADO",
		"subtitle": "Baseline artístico aprovado · orgânico, enraizado e corrompido",
		"script": FOREST_SLICE_SCRIPT,
		"mode": "slice",
	},
	"frozen": {
		"title": "RUÍNAS GLACIAIS",
		"subtitle": "Vertical slice em aprovação · mineral, arquitetônica e soterrada",
		"script": FROZEN_SLICE_SCRIPT,
		"mode": "slice",
	},
}
const REGION_ORDER := [
	"OPEN_ARENA", "NATURAL_CORRIDOR", "DENSE_REGION", "LANDMARK_REGION", "TRANSITION",
]
const REGION_TITLES := {
	"OPEN_ARENA": "ARENA ABERTA",
	"NATURAL_CORRIDOR": "CORREDOR NATURAL",
	"DENSE_REGION": "REGIÃO DENSA",
	"LANDMARK_REGION": "LANDMARK",
	"TRANSITION": "TRANSIÇÃO",
}

var current_world: Node
var current_slice: Node
var current_slice_id := ""
var current_region_id := "OPEN_ARENA"
var _transitioning := false

var _ui_layer: CanvasLayer
var _selector_backdrop: ColorRect
var _selector_status: Label
var _toolbar: PanelContainer
var _toolbar_title: Label
var _toolbar_region: Label
var _save_protection_badge: PanelContainer
var _save_protection_label: Label
var _collision_overlay: Node2D


func _ready() -> void:
	get_tree().paused = false
	_build_interface()
	var requested_slice := _requested_slice_from_command_line()
	if requested_slice in SLICE_DEFINITIONS:
		load_slice(requested_slice)
	else:
		show_selector()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or _transitioning:
		return
	match key_event.keycode:
		KEY_TAB:
			if _selector_backdrop.visible:
				hide_selector()
			else:
				show_selector()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if is_instance_valid(current_world):
				if _selector_backdrop.visible:
					hide_selector()
				else:
					show_selector()
			else:
				get_tree().quit()
			get_viewport().set_input_as_handled()
		KEY_F1:
			_toolbar.visible = not _toolbar.visible
			get_viewport().set_input_as_handled()
		KEY_F2:
			if current_slice_id == "forest_production" and is_instance_valid(current_world):
				toggle_collision_debug()
				get_viewport().set_input_as_handled()
		KEY_1, KEY_KP_1:
			focus_region(REGION_ORDER[0])
		KEY_2, KEY_KP_2:
			focus_region(REGION_ORDER[1])
		KEY_3, KEY_KP_3:
			focus_region(REGION_ORDER[2])
		KEY_4, KEY_KP_4:
			focus_region(REGION_ORDER[3])
		KEY_5, KEY_KP_5:
			focus_region(REGION_ORDER[4])


func load_slice(slice_id: String) -> void:
	if _transitioning or not SLICE_DEFINITIONS.has(slice_id):
		return
	_transitioning = true
	_set_selector_status("Carregando %s..." % str(SLICE_DEFINITIONS[slice_id].title))
	if is_instance_valid(current_world):
		_collision_overlay = null
		current_world.queue_free()
		current_world = null
		current_slice = null
		await get_tree().process_frame

	var world_instance = WORLD_SCENE.instantiate()
	world_instance.suppress_save = true
	if str(SLICE_DEFINITIONS[slice_id].get("mode", "slice")) == "production":
		world_instance.campaign_map_override_id = "profaned_forest"
	add_child(world_instance)
	current_world = world_instance
	current_slice_id = slice_id
	current_region_id = "OPEN_ARENA"
	if str(SLICE_DEFINITIONS[slice_id].get("mode", "slice")) == "production":
		await _configure_production_forest()
		current_slice = null
		focus_region(current_region_id)
	else:
		_configure_isolated_world()
		var slice_script: Script = SLICE_DEFINITIONS[slice_id].script
		current_slice = slice_script.new()
		current_world.add_child(current_slice)
		current_slice.setup(current_world)
		_disable_hidden_environment_interactions()
		current_slice.focus_region(current_region_id)
	_update_toolbar()
	_save_protection_badge.visible = slice_id == "forest_production"
	if slice_id == "forest_production":
		_toolbar.hide()
	else:
		_toolbar.show()
	_transitioning = false
	hide_selector()
	await get_tree().process_frame


func focus_region(region_id: String) -> void:
	if not is_instance_valid(current_world) or region_id not in REGION_ORDER:
		return
	current_region_id = region_id
	if current_slice_id == "forest_production":
		var composer = current_world.environment_builder.terrain_composer
		var target_position := Vector2(composer.capture_point(region_id))
		current_world.player.global_position = target_position
		current_world.camera.reset_smoothing()
		current_world.camera.force_update_scroll()
	elif is_instance_valid(current_slice):
		if region_id not in current_slice.get_semantic_region_ids():
			return
		current_slice.focus_region(region_id)
	else:
		return
	_update_toolbar()
	if is_instance_valid(current_world) and not _selector_backdrop.visible:
		current_world.player.disabled = false


func show_selector() -> void:
	_selector_backdrop.show()
	if is_instance_valid(current_world):
		current_world.player.disabled = true
		current_world.process_mode = Node.PROCESS_MODE_DISABLED
		_set_selector_status(
			"Ativo: %s · %s" % [
				str(SLICE_DEFINITIONS[current_slice_id].title),
				str(REGION_TITLES.get(current_region_id, current_region_id)),
			]
		)
	else:
		_set_selector_status("Escolha uma vertical slice isolada para começar.")


func hide_selector() -> void:
	if not is_instance_valid(current_world):
		return
	_selector_backdrop.hide()
	current_world.process_mode = Node.PROCESS_MODE_INHERIT
	current_world.player.disabled = false


func _configure_production_forest() -> void:
	# O world.tscn conclui a inicialização normal e lê o save apenas para obter o
	# caçador/meta atuais. A troca para o ciclo 0 ocorre somente nesta instância.
	current_world.set_process(false)
	current_world.set_process_unhandled_input(false)
	current_world.player.disabled = true
	current_world.suppress_save = true
	current_world.environment_builder.visual_batcher.reset()
	for container in [current_world.obstacles, current_world.hazards, current_world.landmarks]:
		for child in container.get_children():
			child.queue_free()
	await get_tree().process_frame
	current_world.campaign_map_override_id = "profaned_forest"
	current_world.campaign_map_id = "profaned_forest"
	current_world.map_seed_offset = 0
	current_world.map_boss_power = 1.0
	current_world.run_cycle = 0
	current_world.biome = GameDefs.biome_data_by_id("forest")
	current_world._apply_biome()
	current_world._generate_environment()
	current_world._refresh_visual_bounds()
	current_world._rebuild_spatial_grid()
	_install_collision_overlay()
	current_world.suppress_save = true
	current_world.hud.show()
	current_world.player.disabled = false
	current_world.camera.position_smoothing_enabled = true
	current_world.camera.position_smoothing_speed = 9.0
	current_world.set_process(true)
	current_world.set_process_unhandled_input(true)
	current_world.hud.show_stage_banner("BOSQUE PROFANADO · TESTE SEM SAVE")
	await get_tree().process_frame


func toggle_collision_debug() -> bool:
	if current_slice_id != "forest_production" or not is_instance_valid(_collision_overlay):
		return false
	var enabled: bool = bool(_collision_overlay.toggle())
	_update_save_protection_badge()
	return enabled


func collision_debug_enabled() -> bool:
	return is_instance_valid(_collision_overlay) and _collision_overlay.overlay_enabled


func _install_collision_overlay() -> void:
	_collision_overlay = COLLISION_DEBUG_OVERLAY_SCRIPT.new()
	_collision_overlay.setup(current_world)
	current_world.add_child(_collision_overlay)
	_update_save_protection_badge()


func _configure_isolated_world() -> void:
	current_world.set_process(false)
	current_world.set_physics_process(false)
	current_world.set_process_input(false)
	current_world.set_process_unhandled_input(false)
	current_world.suppress_save = true
	current_world.hud.hide()
	current_world.player.disabled = false
	current_world.player.collision_mask = 0
	current_world.camera.position_smoothing_enabled = true
	current_world.camera.position_smoothing_speed = 9.0
	if is_instance_valid(current_world.audio):
		current_world.audio.enabled = false
		current_world.audio.process_mode = Node.PROCESS_MODE_DISABLED
		for player in current_world.audio.music_players:
			if is_instance_valid(player):
				player.stop()


func _disable_hidden_environment_interactions() -> void:
	for root_node in [current_world.obstacles, current_world.landmarks, current_world.hazards]:
		if not is_instance_valid(root_node):
			continue
		for collision_object in root_node.find_children("*", "CollisionObject2D", true, false):
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0
		for collision_shape in root_node.find_children("*", "CollisionShape2D", true, false):
			collision_shape.disabled = true
	for hazard in get_tree().get_nodes_in_group("arena_hazards"):
		if is_instance_valid(hazard) and current_world.is_ancestor_of(hazard):
			hazard.remove_from_group("arena_hazards")


func _requested_slice_from_command_line() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--slice="):
			return argument.trim_prefix("--slice=").to_lower()
	return ""


func _build_interface() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "VisualTestInterface"
	_ui_layer.layer = 100
	add_child(_ui_layer)
	_build_selector()
	_build_toolbar()
	_build_save_protection_badge()


func _build_selector() -> void:
	_selector_backdrop = ColorRect.new()
	_selector_backdrop.name = "SliceSelector"
	_selector_backdrop.color = Color(0.012, 0.017, 0.030, 0.965)
	_selector_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_selector_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selector_backdrop.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760.0, 610.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("171529"), Color("7651a8"), 2, 14))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "REALM OF CHAOS · FERRAMENTA DE DESENVOLVIMENTO"
	eyebrow.add_theme_color_override("font_color", Color("9f82cb"))
	eyebrow.add_theme_font_size_override("font_size", 15)
	content.add_child(eyebrow)
	var title := Label.new()
	title.text = "LABORATÓRIO DE VERTICAL SLICES"
	title.add_theme_color_override("font_color", Color("eee9f7"))
	title.add_theme_font_size_override("font_size", 28)
	content.add_child(title)
	var explanation := Label.new()
	explanation.text = "Abra o mapa de produção com a campanha ativa e save protegido, ou explore vertical slices artísticas isoladas."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_color_override("font_color", Color("aaa5b9"))
	explanation.add_theme_font_size_override("font_size", 16)
	content.add_child(explanation)

	content.add_child(_slice_button("forest_production"))
	content.add_child(_slice_button("forest"))
	content.add_child(_slice_button("frozen"))
	var cathedral := Button.new()
	cathedral.text = "CATEDRAL DO VAZIO\nAguardando direção artística"
	cathedral.disabled = true
	cathedral.custom_minimum_size = Vector2(0.0, 66.0)
	content.add_child(cathedral)

	_selector_status = Label.new()
	_selector_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selector_status.add_theme_color_override("font_color", Color("c2accf"))
	_selector_status.add_theme_font_size_override("font_size", 14)
	content.add_child(_selector_status)
	var shortcuts := Label.new()
	shortcuts.text = "TAB/ESC: seletor · 1–5: regiões · F1: instruções · F2: colisões no Bosque real · WASD/SETAS: mover"
	shortcuts.add_theme_color_override("font_color", Color("747081"))
	shortcuts.add_theme_font_size_override("font_size", 13)
	content.add_child(shortcuts)


func _slice_button(slice_id: String) -> Button:
	var definition: Dictionary = SLICE_DEFINITIONS[slice_id]
	var button := Button.new()
	button.name = "%sSliceButton" % slice_id.capitalize()
	button.text = "%s\n%s" % [str(definition.title), str(definition.subtitle)]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 76.0)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(load_slice.bind(slice_id))
	return button


func _build_toolbar() -> void:
	_toolbar = PanelContainer.new()
	_toolbar.name = "DevelopmentToolbar"
	_toolbar.position = Vector2(18.0, 18.0)
	_toolbar.custom_minimum_size = Vector2(690.0, 132.0)
	_toolbar.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.030, 0.065, 0.92), Color("604487"), 1, 10))
	_ui_layer.add_child(_toolbar)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	_toolbar.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	_toolbar_title = Label.new()
	_toolbar_title.add_theme_color_override("font_color", Color("e7ddf2"))
	_toolbar_title.add_theme_font_size_override("font_size", 18)
	content.add_child(_toolbar_title)
	_toolbar_region = Label.new()
	_toolbar_region.add_theme_color_override("font_color", Color("9dc3d6"))
	_toolbar_region.add_theme_font_size_override("font_size", 14)
	content.add_child(_toolbar_region)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	content.add_child(buttons)
	for index in range(REGION_ORDER.size()):
		var region_id: String = REGION_ORDER[index]
		var button := Button.new()
		button.text = "%d · %s" % [index + 1, str(REGION_TITLES[region_id])]
		button.pressed.connect(focus_region.bind(region_id))
		buttons.add_child(button)
	var switch_button := Button.new()
	switch_button.text = "TAB · TROCAR BIOMA"
	switch_button.pressed.connect(show_selector)
	buttons.add_child(switch_button)
	_toolbar.hide()


func _build_save_protection_badge() -> void:
	_save_protection_badge = PanelContainer.new()
	_save_protection_badge.name = "SaveProtectionBadge"
	_save_protection_badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_save_protection_badge.offset_left = -225.0
	_save_protection_badge.offset_top = -48.0
	_save_protection_badge.offset_right = 225.0
	_save_protection_badge.offset_bottom = -12.0
	_save_protection_badge.add_theme_stylebox_override(
		"panel", _panel_style(Color(0.025, 0.020, 0.045, 0.90), Color("7e58a8"), 1, 8)
	)
	_ui_layer.add_child(_save_protection_badge)
	_save_protection_label = Label.new()
	_save_protection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_protection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_protection_label.add_theme_color_override("font_color", Color("d8c5eb"))
	_save_protection_label.add_theme_font_size_override("font_size", 13)
	_save_protection_badge.add_child(_save_protection_label)
	_update_save_protection_badge()
	_save_protection_badge.hide()


func _update_save_protection_badge() -> void:
	if not is_instance_valid(_save_protection_label):
		return
	var collision_status := "VISÍVEIS" if collision_debug_enabled() else "OCULTAS"
	_save_protection_label.text = (
		"TESTE DE PRODUÇÃO · SAVE PROTEGIDO · F2: COLISÕES %s · TAB: SELETOR"
		% collision_status
	)


func _update_toolbar() -> void:
	if current_slice_id.is_empty():
		return
	_toolbar_title.text = "MODO DE TESTE · %s" % str(SLICE_DEFINITIONS[current_slice_id].title)
	var mode_status := "Campanha real em memória · SAVE PROTEGIDO" if current_slice_id == "forest_production" else "Progresso e spawns desativados"
	_toolbar_region.text = "REGIÃO: %s · %s" % [str(REGION_TITLES.get(current_region_id, current_region_id)), mode_status]


func _set_selector_status(message: String) -> void:
	if is_instance_valid(_selector_status):
		_selector_status.text = message


func _panel_style(background: Color, border: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style
