extends Control

const CampaignCatalogScript = preload("res://scripts/campaign_catalog.gd")
const SAVE_PATH := "user://realm_of_chaos.cfg"

var save_path := ""
var selected_map_id := ""
var campaign_manager: Node
var map_cards: Dictionary = {}
var preview_controls: Dictionary = {}
var path_row: HBoxContainer
var map_scroll: ScrollContainer
var title_label: Label
var subtitle_label: Label
var status_label: Label
var start_button: Button
var back_button: Button
var reset_button: Button
var reset_dialog: ConfirmationDialog
var transitioning := false
var transition_fade: ColorRect


func _ready() -> void:
	get_tree().paused = false
	campaign_manager = get_node_or_null("/root/CampaignManager")
	if campaign_manager == null:
		push_error("CampaignManager não está disponível.")
		return
	if save_path.is_empty():
		save_path = str(campaign_manager.save_path) if not str(campaign_manager.save_path).is_empty() else SAVE_PATH
	var load_result: Dictionary = campaign_manager.load_progress(save_path, true)
	_build_interface()
	selected_map_id = str(campaign_manager.selected_map_id)
	if not campaign_manager.can_start_map(selected_map_id):
		selected_map_id = CampaignCatalogScript.first_map_id()
	_refresh_cards()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()
	if str(load_result.status) in ["recovered", "failed"]:
		status_label.text = str(load_result.message)
	start_button.grab_focus()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color("090711")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var atmosphere := ColorRect.new()
	atmosphere.name = "Atmosphere"
	atmosphere.color = Color(0.18, 0.08, 0.27, 0.18)
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "CAMPANHA DO RITUAL"
	title_label.add_theme_color_override("font_color", Color("d6a4ff"))
	add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "Subtitle"
	subtitle_label.text = "Cada território exige a queda de seu soberano para revelar o próximo caminho."
	subtitle_label.add_theme_color_override("font_color", Color("aa9ab8"))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(subtitle_label)

	map_scroll = ScrollContainer.new()
	map_scroll.name = "MapScroll"
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.follow_focus = true
	add_child(map_scroll)

	path_row = HBoxContainer.new()
	path_row.name = "CampaignPath"
	path_row.add_theme_constant_override("separation", 12)
	map_scroll.add_child(path_row)

	var definitions := CampaignCatalogScript.all_maps()
	for index in range(definitions.size()):
		var definition: Dictionary = definitions[index]
		if index > 0:
			var connector := Label.new()
			connector.name = "Connector_%02d" % (index + 1)
			connector.text = "◆"
			connector.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			connector.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			connector.add_theme_color_override("font_color", Color(0.49, 0.31, 0.61, 0.72))
			connector.add_theme_font_size_override("font_size", 16)
			path_row.add_child(connector)
		var card := _build_map_card(definition)
		path_row.add_child(card)

	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "VOLTAR AO MENU"
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)

	status_label = Label.new()
	status_label.name = "StatusMessage"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("cdb9dc"))
	add_child(status_label)

	start_button = Button.new()
	start_button.name = "StartMap"
	start_button.text = "INICIAR MAPA"
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)

	if OS.has_feature("editor"):
		reset_button = Button.new()
		reset_button.name = "ResetCampaign"
		reset_button.text = "RESETAR CAMPANHA (TESTE)"
		reset_button.pressed.connect(_request_campaign_reset)
		add_child(reset_button)
		reset_dialog = ConfirmationDialog.new()
		reset_dialog.title = "RESETAR SOMENTE A CAMPANHA"
		reset_dialog.dialog_text = "Mapas concluídos e desbloqueados serão reiniciados.\nEssência, recordes, conquistas, perfil e opções serão preservados."
		reset_dialog.confirmed.connect(_confirm_campaign_reset)
		add_child(reset_dialog)


func _build_map_card(definition: Dictionary) -> Button:
	var map_id := str(definition.id)
	var card := Button.new()
	card.name = "MapCard_%s" % map_id
	card.clip_contents = true
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(func(): _on_card_pressed(map_id))
	map_cards[map_id] = card

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_bottom", 11)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Content"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var order := Label.new()
	order.name = "Order"
	order.text = "MAPA %02d" % int(definition.order)
	order.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order.add_theme_color_override("font_color", Color("a98abc"))
	order.add_theme_font_size_override("font_size", 12)
	column.add_child(order)

	var preview := TextureRect.new()
	preview.name = "Preview"
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(definition.content_ready):
		preview.texture = load(str(definition.preview_path)) as Texture2D
	else:
		var future_mark := Label.new()
		future_mark.name = "FutureMark"
		future_mark.text = "%02d" % int(definition.order)
		future_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		future_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		future_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		future_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		future_mark.add_theme_color_override("font_color", Color(0.46, 0.36, 0.52, 0.70))
		future_mark.add_theme_font_size_override("font_size", 38)
		preview.add_child(future_mark)
	preview_controls[map_id] = preview
	column.add_child(preview)

	var map_name := Label.new()
	map_name.name = "MapName"
	map_name.text = str(definition.name)
	map_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_name.add_theme_color_override("font_color", Color("eee4f2"))
	map_name.add_theme_font_size_override("font_size", 16)
	column.add_child(map_name)

	var state := Label.new()
	state.name = "State"
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", 12)
	column.add_child(state)

	var requirement := Label.new()
	requirement.name = "Requirement"
	requirement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	requirement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	requirement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	requirement.add_theme_color_override("font_color", Color("96879e"))
	requirement.add_theme_font_size_override("font_size", 10)
	column.add_child(requirement)
	return card


func _on_card_pressed(map_id: String) -> void:
	var definition := CampaignCatalogScript.map_data(map_id)
	if definition.is_empty():
		return
	if not bool(definition.content_ready):
		var requirement := CampaignCatalogScript.requirement_text(map_id)
		status_label.text = "PRÓXIMO TERRITÓRIO EM BREVE" if requirement.is_empty() else "%s · EM BREVE" % requirement
		return
	if not campaign_manager.can_start_map(map_id):
		status_label.text = CampaignCatalogScript.requirement_text(map_id)
		return
	selected_map_id = map_id
	status_label.text = "%s selecionado." % str(definition.name)
	_refresh_cards()


func _on_start_pressed() -> void:
	if transitioning or not campaign_manager.can_start_map(selected_map_id):
		return
	var definition := CampaignCatalogScript.map_data(selected_map_id)
	var scene_path := str(definition.get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		status_label.text = "ESTE MAPA AINDA NÃO POSSUI CONTEÚDO JOGÁVEL."
		return
	if not campaign_manager.persist_selection(selected_map_id):
		status_label.text = "NÃO FOI POSSÍVEL SALVAR A SELEÇÃO. O SAVE ANTERIOR FOI PRESERVADO."
		return
	transitioning = true
	start_button.disabled = true
	_set_transition_controls_locked(true)
	transition_fade = ColorRect.new()
	transition_fade.color = Color(0.01, 0.004, 0.025, 0.0)
	transition_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_fade.z_index = 100
	add_child(transition_fade)
	var tween := create_tween()
	tween.tween_property(transition_fade, "color", Color(0.01, 0.004, 0.025, 1.0), 0.28)
	tween.tween_callback(_open_selected_map.bind(scene_path))


func _open_selected_map(scene_path: String) -> void:
	var transition_guard = get_node_or_null("/root/SceneTransitionGuard")
	var error: Error = transition_guard.change_scene_to_file(scene_path) if transition_guard != null else get_tree().change_scene_to_file(scene_path)
	if error != OK:
		_cancel_scene_transition("NÃO FOI POSSÍVEL ABRIR O MAPA.")


func _on_back_pressed() -> void:
	if transitioning:
		return
	transitioning = true
	_set_transition_controls_locked(true)
	var transition_guard = get_node_or_null("/root/SceneTransitionGuard")
	var error: Error = transition_guard.change_scene_to_file("res://scenes/main_menu.tscn") if transition_guard != null else get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if error != OK:
		_cancel_scene_transition("NÃO FOI POSSÍVEL VOLTAR AO MENU.")


func _set_transition_controls_locked(locked: bool) -> void:
	if is_instance_valid(start_button):
		start_button.disabled = locked
	if is_instance_valid(back_button):
		back_button.disabled = locked
	if is_instance_valid(reset_button):
		reset_button.disabled = locked


func _cancel_scene_transition(message: String) -> void:
	transitioning = false
	_set_transition_controls_locked(false)
	if is_instance_valid(transition_fade):
		transition_fade.queue_free()
	transition_fade = null
	if is_instance_valid(status_label):
		status_label.text = message


func _request_campaign_reset() -> void:
	if is_instance_valid(reset_dialog):
		reset_dialog.popup_centered(Vector2i(480, 190))


func _confirm_campaign_reset() -> void:
	if campaign_manager.reset_campaign_progress(save_path) != OK:
		status_label.text = "NÃO FOI POSSÍVEL RESETAR A CAMPANHA."
		return
	selected_map_id = CampaignCatalogScript.first_map_id()
	status_label.text = "PROGRESSO DA CAMPANHA RESETADO. DEMAIS DADOS PRESERVADOS."
	_refresh_cards()


func _refresh_cards() -> void:
	for definition in CampaignCatalogScript.all_maps():
		var map_id := str(definition.id)
		var card := map_cards.get(map_id) as Button
		if not is_instance_valid(card):
			continue
		var state := card.get_node("Margin/Content/State") as Label
		var requirement := card.get_node("Margin/Content/Requirement") as Label
		var preview := preview_controls.get(map_id) as TextureRect
		var status := str(campaign_manager.map_status(map_id))
		match status:
			"completed":
				state.text = "CONCLUÍDO"
				state.add_theme_color_override("font_color", Color("75d69b"))
				requirement.text = "Disponível para repetir"
				preview.modulate = Color.WHITE
			"available":
				state.text = "◆ DISPONÍVEL"
				state.add_theme_color_override("font_color", Color("d6a4ff"))
				requirement.text = "Derrote o soberano final para concluir"
				preview.modulate = Color.WHITE
			"coming_soon":
				state.text = "EM BREVE"
				state.add_theme_color_override("font_color", Color("8c7a97"))
				requirement.text = CampaignCatalogScript.requirement_text(map_id)
				preview.modulate = Color(0.28, 0.25, 0.31, 0.82)
			_:
				state.text = "BLOQUEADO"
				state.add_theme_color_override("font_color", Color("b47783"))
				requirement.text = CampaignCatalogScript.requirement_text(map_id)
				preview.modulate = Color(0.32, 0.28, 0.34, 0.82)
		_apply_card_style(card, status, map_id == selected_map_id)
	start_button.disabled = not campaign_manager.can_start_map(selected_map_id)
	var selected := CampaignCatalogScript.map_data(selected_map_id)
	start_button.text = "INICIAR · %s" % str(selected.get("name", "MAPA"))


func _apply_card_style(card: Button, status: String, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.036, 0.077, 0.98)
	style.border_color = Color("d5a2ff") if selected else Color(0.29, 0.22, 0.35, 0.92)
	if status == "completed":
		style.bg_color = Color(0.035, 0.075, 0.065, 0.98)
	elif status in ["locked", "coming_soon"]:
		style.bg_color = Color(0.035, 0.029, 0.043, 0.98)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = style.bg_color.lightened(0.055)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("focus", hover)
	card.add_theme_stylebox_override("pressed", hover)


func _update_responsive_layout() -> void:
	if size.x <= 1.0 or size.y <= 1.0 or not is_instance_valid(map_scroll):
		return
	var compact := size.x <= 800.0 or size.y <= 450.0
	var margin_x := 18.0 if compact else 42.0
	var header_height := 72.0 if compact else 112.0
	var footer_height := 52.0 if compact else 72.0
	title_label.position = Vector2(margin_x, 10.0 if compact else 20.0)
	title_label.size = Vector2(size.x - margin_x * 2.0, 34.0 if compact else 48.0)
	title_label.add_theme_font_size_override("font_size", 22 if compact else 34)
	subtitle_label.position = Vector2(margin_x, 42.0 if compact else 67.0)
	subtitle_label.size = Vector2(size.x - margin_x * 2.0, 30.0 if compact else 38.0)
	subtitle_label.add_theme_font_size_override("font_size", 10 if compact else 13)
	map_scroll.position = Vector2(margin_x, header_height)
	map_scroll.size = Vector2(size.x - margin_x * 2.0, maxf(120.0, size.y - header_height - footer_height))
	var card_size := Vector2(190.0, maxf(116.0, map_scroll.size.y - 10.0)) if compact else Vector2(252.0, maxf(220.0, map_scroll.size.y - 16.0))
	for card_value in map_cards.values():
		var card := card_value as Button
		card.custom_minimum_size = card_size
		var preview := card.get_node("Margin/Content/Preview") as TextureRect
		preview.custom_minimum_size = Vector2(card_size.x - 22.0, 62.0 if compact else minf(155.0, card_size.y * 0.42))
		(card.get_node("Margin/Content/MapName") as Label).add_theme_font_size_override("font_size", 12 if compact else 16)
		(card.get_node("Margin/Content/Requirement") as Label).visible = card_size.y >= 185.0
	for child in path_row.get_children():
		if child is Label and str(child.name).begins_with("Connector"):
			child.custom_minimum_size = Vector2(22.0 if compact else 34.0, card_size.y)
	path_row.custom_minimum_size = Vector2(0.0, card_size.y)
	var footer_y := size.y - footer_height + (5.0 if compact else 10.0)
	back_button.position = Vector2(margin_x, footer_y)
	back_button.size = Vector2(140.0 if compact else 190.0, 38.0 if compact else 46.0)
	start_button.size = Vector2(210.0 if compact else 310.0, 38.0 if compact else 46.0)
	start_button.position = Vector2(size.x - margin_x - start_button.size.x, footer_y)
	status_label.position = Vector2(back_button.position.x + back_button.size.x + 8.0, footer_y)
	status_label.size = Vector2(maxf(0.0, start_button.position.x - status_label.position.x - 8.0), start_button.size.y)
	status_label.add_theme_font_size_override("font_size", 9 if compact else 12)
	if is_instance_valid(reset_button):
		reset_button.position = Vector2(size.x - margin_x - 190.0, 12.0 if compact else 22.0)
		reset_button.size = Vector2(190.0, 24.0)
		reset_button.add_theme_font_size_override("font_size", 9)
