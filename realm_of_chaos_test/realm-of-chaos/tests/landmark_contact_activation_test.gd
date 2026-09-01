extends SceneTree

const LAB_SCENE := preload("res://scenes/biome_vertical_slice_lab.tscn")

var failures: Array[String] = []
var capture_directory := ""


func _initialize() -> void:
	capture_directory = OS.get_environment("ROC_LANDMARK_CONTACT_CAPTURE_DIR")
	if not capture_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_directory)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("LANDMARK CONTACT ACTIVATION: " + message)


func _landmark_by_kind(world: Node, kind: String) -> Node:
	for landmark in world.landmarks.get_children():
		if str(landmark.landmark_kind) == kind:
			return landmark
	return null


func _walk_into_landmark(world: Node, landmark: Node, start_offset: Vector2) -> void:
	var player = world.player
	player.global_position = landmark.global_position + start_offset
	player.velocity = Vector2.ZERO
	await physics_frame
	_check(not landmark.activated, "%s ativou sem contato físico" % landmark.landmark_kind)
	for _step in range(90):
		await physics_frame
		player.velocity = Vector2.UP * 620.0
		player.move_and_slide()
		player._process_landmark_contacts()
		if landmark.activated:
			break
	player.velocity = Vector2.ZERO


func _capture(world: Node, capture_name: String) -> void:
	if capture_directory.is_empty():
		return
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	for _frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := world.get_viewport().get_texture().get_image()
	_check(not image.is_empty(), "captura vazia: " + capture_name)
	if image.is_empty():
		return
	var output_path := capture_directory.path_join(capture_name + ".png")
	_check(image.save_png(output_path) == OK, "falha ao salvar " + output_path)
	print("LANDMARK CONTACT CAPTURE: " + output_path)


func _run() -> void:
	var lab = LAB_SCENE.instantiate()
	root.add_child(lab)
	await process_frame
	await lab.load_slice("forest_production")
	var world = lab.current_world
	world.audio.enabled = false
	world.set_process(false)
	world.player.set_physics_process(false)
	await physics_frame

	var approaches := {
		"altar": Vector2(0.0, 96.0),
		"obelisk": Vector2(0.0, 96.0),
		"tree": Vector2(0.0, 96.0),
		"portal": Vector2(-71.0, 82.0),
	}
	var expected_titles := {
		"altar": "FÚRIA RUBRA",
		"obelisk": "FLUXO CRONAL",
		"tree": "CHAMADO DAS ALMAS",
		"portal": "PELE DO VAZIO",
	}
	for kind in ["altar", "obelisk", "tree", "portal"]:
		var landmark := _landmark_by_kind(world, kind)
		_check(is_instance_valid(landmark), "landmark ausente: " + kind)
		if not is_instance_valid(landmark):
			continue
		var count_before: int = world.shrines_activated
		if kind == "altar" and not capture_directory.is_empty():
			lab.toggle_collision_debug()
			world.player.global_position = landmark.global_position + approaches[kind]
			await _capture(world, "altar_before_contact_f2")
			lab.toggle_collision_debug()
		await _walk_into_landmark(world, landmark, approaches[kind])
		_check(landmark.activated, "%s não ativou ao colidir" % kind)
		_check(world.shrines_activated == count_before + 1, "%s não contou exatamente uma ativação" % kind)
		_check(world.player.blessing_kind == kind, "%s não aplicou a identidade correta do buff" % kind)
		_check(world.player.blessing_title == expected_titles[kind], "%s aplicou a recompensa errada" % kind)
		_check(world.player.blessing_time > 39.0, "%s alterou a duração da bênção" % kind)
		_check(world.hud.active_buffs_panel.visible, "%s não apareceu na HUD" % kind)
		_check(world.hud.active_buffs_panel.displayed_buff_ids() == [kind], "%s duplicou ou exibiu o buff errado" % kind)
		if kind == "altar":
			await _capture(world, "altar_activated_hud")
			if not capture_directory.is_empty():
				world.hud.stage_banner.hide()
				await _capture(world, "altar_active_minimal_hud")
		elif kind == "portal":
			await _capture(world, "portal_activated_hud")
		landmark.activate_from_physical_contact(world.player)
		world.activate_landmark(landmark)
		_check(world.shrines_activated == count_before + 1, "%s permitiu ativação múltipla" % kind)

	world.player.blessing_time = 0.01
	world.player._update_temporary_blessing(0.02)
	world._update_hud()
	_check(world.player.blessing_kind.is_empty(), "buff expirado manteve identidade residual")
	_check(world.player.active_landmark_buffs().is_empty(), "buff expirado permaneceu no estado da HUD")
	_check(not world.hud.active_buffs_panel.visible, "painel não sumiu quando o buff expirou")

	await lab.load_slice("forest_production")
	var restarted_world = lab.current_world
	restarted_world.audio.enabled = false
	restarted_world.set_process(false)
	await physics_frame
	_check(restarted_world.suppress_save, "reinício do laboratório deixou de proteger o save")
	_check(restarted_world.player.active_landmark_buffs().is_empty(), "novo mapa herdou buff da instância anterior")
	_check(not restarted_world.hud.active_buffs_panel.visible, "novo mapa abriu com indicador duplicado")
	for landmark in restarted_world.landmarks.get_children():
		_check(not landmark.activated, "novo mapa herdou landmark ativado")

	lab.queue_free()
	for _frame in range(5):
		await process_frame
	if failures.is_empty():
		print("LANDMARK CONTACT ACTIVATION OK: 4 colisões reais, recompensas, idempotência, substituição e expiração validadas")
	quit(0 if failures.is_empty() else 1)
