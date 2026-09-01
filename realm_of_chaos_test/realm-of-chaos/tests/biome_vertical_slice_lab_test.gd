extends SceneTree

const LAB_SCENE := preload("res://scenes/biome_vertical_slice_lab.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("BIOME VERTICAL SLICE LAB: " + message)


func _run() -> void:
	var lab = LAB_SCENE.instantiate()
	root.add_child(lab)
	await process_frame
	_check(not is_instance_valid(lab.current_world), "o laboratório iniciou uma partida sem escolha do usuário")
	_check(ProjectSettings.get_setting("application/run/main_scene") != "res://scenes/biome_vertical_slice_lab.tscn", "o laboratório substituiu a cena principal")

	await lab.load_slice("forest_production")
	_check(lab.current_slice_id == "forest_production", "o Bosque de produção não foi selecionado")
	_check(is_instance_valid(lab.current_world), "world.tscn real não foi instanciado no modo produção")
	_check(not is_instance_valid(lab.current_slice), "o modo produção carregou a vertical slice por engano")
	_check(lab.current_world.suppress_save, "o modo produção não bloqueou salvamentos")
	_check(lab.current_world.is_processing(), "a campanha real permaneceu congelada")
	_check(lab.current_world.hud.visible, "o HUD real foi ocultado no modo produção")
	_check(str(lab.current_world.biome.id) == "forest", "o modo produção não forçou o Bosque somente em memória")
	_check(lab.current_world.run_cycle == 0, "o ciclo em memória não foi isolado no Bosque")
	_check(lab.current_world.obstacles.get_child_count() == 91, "as 36 âncoras e 55 massas florestais reais não foram geradas")
	_check(lab.current_world.landmarks.get_child_count() == 4, "os landmarks reais do Bosque não foram gerados")
	var terrain_summary: Dictionary = lab.current_world.environment_builder.terrain_composer.summary()
	_check(bool(terrain_summary.active), "o ForestTerrainComposer de produção não está ativo")
	_check(int(terrain_summary.route_count) == 5, "as rotas reais de produção não foram geradas")
	_check(lab.toggle_collision_debug(), "F2 não ativou os limites dos colisores")
	var collision_overlay = lab.current_world.get_node_or_null("EnvironmentCollisionDebugOverlay")
	_check(is_instance_valid(collision_overlay) and collision_overlay.visible, "sobreposição de colisão não apareceu no world.tscn real")
	_check(collision_overlay.displayed_shape_count() >= 70, "sobreposição não contém todos os obstáculos ambientais")
	_check(not lab.toggle_collision_debug(), "F2 não desativou os limites dos colisores")
	lab.focus_region("DENSE_REGION")
	await process_frame
	var production_dense := Vector2(lab.current_world.environment_builder.terrain_composer.capture_point("DENSE_REGION"))
	_check(lab.current_world.player.global_position.distance_to(production_dense) < 1.0, "o atalho não usa a região densa do compositor real")
	lab.show_selector()
	_check(lab.current_world.process_mode == Node.PROCESS_MODE_DISABLED, "a campanha continuou sob o seletor")
	lab.hide_selector()
	_check(lab.current_world.process_mode == Node.PROCESS_MODE_INHERIT, "a campanha não retomou ao fechar o seletor")

	await lab.load_slice("frozen")
	_check(lab.current_slice_id == "frozen", "a slice glacial não foi selecionada")
	_check(is_instance_valid(lab.current_world), "world.tscn real não foi instanciado")
	_check(lab.current_world.suppress_save, "o modo visual não bloqueou salvamentos")
	_check(not lab.current_world.is_processing(), "o cronômetro/spawner normal continuou processando")
	_check(not lab.current_world.hud.visible, "o HUD normal permaneceu sobre o laboratório")
	_check(lab.current_world.player.collision_mask == 0, "o player ainda pode colidir com obstáculos invisíveis")
	_check(lab.current_slice.name == "FrozenRuinsVerticalSlice", "o compositor glacial isolado não foi aplicado")
	lab.focus_region("DENSE_REGION")
	await process_frame
	_check(lab.current_region_id == "DENSE_REGION", "o atalho de região não atualizou o foco")
	_check(lab.current_world.player.global_position.distance_to(Vector2(1570.0, -410.0)) < 1.0, "o foco não levou o player à região densa")

	lab.show_selector()
	_check(lab.current_world.player.disabled, "o player continuou andando sob o seletor")
	lab.hide_selector()
	_check(not lab.current_world.player.disabled, "o player não foi liberado ao fechar o seletor")

	await lab.load_slice("forest")
	_check(lab.current_slice_id == "forest", "não foi possível trocar para o Bosque")
	_check(lab.current_slice.name == "ForestVerticalSlice", "a troca de bioma reutilizou a slice errada")
	_check(lab.current_world.suppress_save, "a troca de slice reativou salvamentos")

	lab.queue_free()
	for _frame in range(5):
		await process_frame
	if failures.is_empty():
		print("BIOME VERTICAL SLICE LAB OK: Bosque de produção, slices, regiões e proteção do save validados")
	quit(0 if failures.is_empty() else 1)
