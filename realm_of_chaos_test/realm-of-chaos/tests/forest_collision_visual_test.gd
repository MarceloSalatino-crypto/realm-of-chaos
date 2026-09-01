extends SceneTree

const LAB_SCENE := preload("res://scenes/biome_vertical_slice_lab.tscn")

var failures: Array[String] = []
var capture_directory := ""


func _initialize() -> void:
	capture_directory = OS.get_environment("ROC_FOREST_COLLISION_CAPTURE_DIR")
	if not capture_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_directory)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FOREST COLLISION VISUAL: " + message)


func _focus(world: Node, world_position: Vector2) -> void:
	world.player.global_position = world_position
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	world.environment_builder.rebuild_obstacle_grid()


func _capture(world: Node, capture_name: String) -> void:
	for _frame in range(6):
		await process_frame
	RenderingServer.force_draw(false, 0.0)
	var screenshot := world.get_viewport().get_texture().get_image()
	_check(not screenshot.is_empty(), "captura vazia: " + capture_name)
	if screenshot.is_empty():
		return
	var output_path := "user://forest_collision_%s.png" % capture_name
	if not capture_directory.is_empty():
		output_path = capture_directory.path_join("forest_collision_%s.png" % capture_name)
	_check(screenshot.save_png(output_path) == OK, "falha ao salvar " + output_path)
	print("FOREST COLLISION CAPTURE: " + ProjectSettings.globalize_path(output_path))


func _run() -> void:
	var lab = LAB_SCENE.instantiate()
	root.add_child(lab)
	await process_frame
	await lab.load_slice("forest_production")
	var world = lab.current_world
	world.audio.enabled = false
	world.hud.hide()
	world.camera.position_smoothing_enabled = false
	_check(lab.toggle_collision_debug(), "F2 não ativou a sobreposição")
	_check(lab.collision_debug_enabled(), "estado da sobreposição não ficou ativo")
	var overlay = world.get_node_or_null("EnvironmentCollisionDebugOverlay")
	_check(is_instance_valid(overlay), "sobreposição não foi criada no world.tscn")
	if is_instance_valid(overlay):
		_check(overlay.displayed_shape_count() >= 70, "sobreposição omitiu colisores reais")

	var composer = world.environment_builder.terrain_composer
	var layout: Dictionary = composer.art_layout()
	var captured_normal_variants: Dictionary = {}
	for descriptor in layout.grove_visuals:
		var texture_index := int(descriptor.texture_index)
		if bool(descriptor.dense) or captured_normal_variants.has(texture_index):
			continue
		captured_normal_variants[texture_index] = true
		_focus(world, Vector2(descriptor.anchor) + Vector2(0.0, 165.0))
		await _capture(world, "grove_variant_%d" % texture_index)
	var dense_index := 0
	for descriptor in layout.grove_visuals:
		if not bool(descriptor.dense):
			continue
		_focus(world, Vector2(descriptor.anchor) + Vector2(0.0, 165.0))
		await _capture(world, "dense_%d_variant_%d" % [dense_index, int(descriptor.texture_index)])
		dense_index += 1
	_focus(world, composer.capture_point("DENSE_REGION"))
	await _capture(world, "dense_mass")

	for landmark in world.landmarks.get_children():
		_focus(world, landmark.global_position + Vector2(0.0, 150.0))
		await _capture(world, "landmark_" + str(landmark.landmark_kind))

	lab.queue_free()
	for _frame in range(6):
		await process_frame
	if failures.is_empty():
		print("FOREST COLLISION VISUAL OK: perfis reais capturados com F2")
	quit(0 if failures.is_empty() else 1)
