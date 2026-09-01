extends SceneTree

const LAB_SCENE := preload("res://scenes/biome_vertical_slice_lab.tscn")

var failures: Array[String] = []
var capture_directory := ""


func _initialize() -> void:
	capture_directory = OS.get_environment("ROC_BOSS_ARENA_CAPTURE_DIR")
	if not capture_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_directory)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("BOSS ARENA SAFETY VISUAL: " + message)


func _clear_boss(world: Node) -> void:
	if is_instance_valid(world.active_boss_arena):
		world.active_boss_arena.free()
	world.active_boss_arena = null
	if is_instance_valid(world.active_boss):
		world.active_boss.free()
	world.active_boss = null


func _capture(world: Node, capture_name: String) -> void:
	world.camera.global_position = world.active_boss_arena.global_position
	world.camera.zoom = Vector2(0.42, 0.42)
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	for _frame in range(8):
		await process_frame
	if DisplayServer.get_name() == "headless":
		print("BOSS ARENA SAFETY CAPTURE SKIPPED (headless): " + capture_name)
		return
	RenderingServer.force_draw(false, 0.0)
	var screenshot := world.get_viewport().get_texture().get_image()
	_check(not screenshot.is_empty(), "captura vazia: " + capture_name)
	if screenshot.is_empty():
		return
	var output_path := "user://boss_arena_safety_%s.png" % capture_name
	if not capture_directory.is_empty():
		output_path = capture_directory.path_join("boss_arena_safety_%s.png" % capture_name)
	_check(screenshot.save_png(output_path) == OK, "falha ao salvar " + output_path)
	print("BOSS ARENA SAFETY CAPTURE: " + ProjectSettings.globalize_path(output_path))


func _spawn_and_capture(
	world: Node, entry: Dictionary, origin: Vector2, capture_name: String
) -> void:
	_clear_boss(world)
	world.player.global_position = origin
	world.player.velocity = Vector2.ZERO
	var boss = world._spawn_scheduled_boss(entry, 0)
	_check(is_instance_valid(boss), capture_name + " não criou boss")
	if not is_instance_valid(boss):
		return
	boss.set_physics_process(false)
	_check(
		world.environment_builder.is_boss_arena_center_valid(
			world.active_boss_arena.global_position, world.active_boss_arena.radius
		),
		capture_name + " criou arena inválida"
	)
	await _capture(world, capture_name)


func _run() -> void:
	var lab = LAB_SCENE.instantiate()
	root.add_child(lab)
	await process_frame
	await lab.load_slice("forest_production")
	var world = lab.current_world
	world.audio.enabled = false
	world.set_process(false)
	world.hud.hide()
	world.player.disabled = true
	world.player.set_physics_process(false)
	world.camera.position_smoothing_enabled = false
	_check(lab.toggle_collision_debug(), "F2 não ativou a geometria física real")

	var composer = world.environment_builder.terrain_composer
	var schedule: Array[Dictionary] = GameDefs.boss_schedule()
	await _spawn_and_capture(
		world, schedule[0], Vector2(composer.capture_point("OPEN_ARENA")), "open_arena"
	)
	await _spawn_and_capture(
		world, schedule[0], Vector2(composer.capture_point("DENSE_REGION")), "dense_region"
	)
	var landmark = world.landmarks.get_child(0)
	await _spawn_and_capture(
		world, schedule[0], landmark.global_position + Vector2(0.0, 92.0), "landmark"
	)
	await _spawn_and_capture(world, schedule[-1], Vector2(5500.0, 5500.0), "world_corner_final")

	_clear_boss(world)
	lab.queue_free()
	for _frame in range(6):
		await process_frame
	if failures.is_empty():
		if DisplayServer.get_name() == "headless":
			print("BOSS ARENA SAFETY VISUAL OK: quatro cenários lógicos; captura omitida no headless")
		else:
			print("BOSS ARENA SAFETY VISUAL OK: produção real capturada com colisões em quatro cenários")
	quit(0 if failures.is_empty() else 1)
