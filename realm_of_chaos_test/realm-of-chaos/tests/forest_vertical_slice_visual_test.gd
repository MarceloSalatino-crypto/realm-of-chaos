extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const FOREST_SLICE_SCRIPT := preload("res://scripts/forest_vertical_slice.gd")
const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const EFFECT_SCRIPT := preload("res://scripts/effect.gd")

const ENEMY_TYPES := [
	"prowler", "bat", "mage", "brute", "ember", "bomber",
	"necromancer", "archer", "assassin", "swarm", "guardian",
]
const COMBAT_ENEMIES := 64
const MEASURED_FRAMES := 90
const MAX_AVERAGE_MS := 14.0
const MAX_P95_MS := 22.0

var failures: Array[String] = []
var capture_directory := ""


func _initialize() -> void:
	capture_directory = OS.get_environment("ROC_FOREST_SLICE_CAPTURE_DIR")
	if not capture_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_directory)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FOREST VERTICAL SLICE: " + message)


func _capture(world: Node, capture_name: String) -> void:
	for _frame in range(5):
		await process_frame
	RenderingServer.force_draw(false, 0.0)
	var screenshot := world.get_viewport().get_texture().get_image()
	_check(not screenshot.is_empty(), "captura vazia: " + capture_name)
	if screenshot.is_empty():
		return
	var output_path := "user://forest_vertical_slice_%s.png" % capture_name
	if not capture_directory.is_empty():
		output_path = capture_directory.path_join("forest_vertical_slice_%s.png" % capture_name)
	_check(screenshot.save_png(output_path) == OK, "não foi possível salvar " + output_path)
	print("FOREST VERTICAL SLICE CAPTURE: " + ProjectSettings.globalize_path(output_path))


func _spawn_combat_scene(world: Node) -> void:
	for index in range(COMBAT_ENEMIES):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], index % 17 == 0, 3.0)
		_check(is_instance_valid(enemy), "inimigo real não foi criado no índice %d" % index)
		if not is_instance_valid(enemy):
			continue
		var angle := TAU * float(index) / float(COMBAT_ENEMIES)
		var ring := 285.0 + float(index % 5) * 54.0
		enemy.global_position = Vector2.RIGHT.rotated(angle) * ring
		enemy.set_physics_process(false)

	for index in range(30):
		var angle := TAU * float(index) / 30.0
		var projectile = BULLET_SCENE.instantiate()
		projectile.global_position = Vector2.RIGHT.rotated(angle) * (105.0 + float(index % 4) * 22.0)
		projectile.setup(Vector2.RIGHT.rotated(angle + PI * 0.5), 0.0, 28.0, 999, 8.0, Color("a96cff"))
		projectile.lifetime = 8.0
		world.add_player_projectile(projectile)

	for index in range(18):
		var angle := TAU * float(index) / 18.0
		var projectile = world.spawn_enemy_projectile(
			Vector2.RIGHT.rotated(angle) * (225.0 + float(index % 3) * 25.0),
			Vector2.RIGHT.rotated(angle + PI * 0.5), 0.0, 26.0,
			Color("ff496d"), 8.0, index % 3 == 0
		)
		if is_instance_valid(projectile):
			projectile.lifetime = 8.0

	for index in range(28):
		var angle := TAU * float(index) / 28.0
		world._spawn_pickup(1 + index % 3, Vector2.RIGHT.rotated(angle) * (175.0 + float(index % 3) * 24.0), "xp")

	for index in range(18):
		var effect = EFFECT_SCRIPT.new()
		world.effects.add_child(effect)
		var angle := TAU * float(index) / 18.0
		effect.setup(
			Vector2.RIGHT.rotated(angle) * (130.0 + float(index % 4) * 58.0),
			Color("8f62cc").lerp(Color("cf496d"), float(index % 4) / 3.0),
			38.0 + float(index % 3) * 9.0, 4.0, index % 3 == 0, 0
		)


func _measure_frames(frame_count: int) -> Dictionary:
	var frame_times: Array[float] = []
	var total_started := Time.get_ticks_usec()
	for _frame in range(frame_count):
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec() - frame_started) / 1000.0)
	var total_ms := float(Time.get_ticks_usec() - total_started) / 1000.0
	frame_times.sort()
	var p95_index := mini(frame_times.size() - 1, ceili(float(frame_times.size()) * 0.95) - 1)
	return {
		"average_ms": total_ms / float(frame_count),
		"p95_ms": frame_times[p95_index],
	}


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true
	world.player.set_physics_process(false)
	world.camera.position_smoothing_enabled = false
	world.time_survived = world.RUN_DURATION
	world.hud.visible = false

	var vertical_slice = FOREST_SLICE_SCRIPT.new()
	world.add_child(vertical_slice)
	vertical_slice.setup(world)
	await process_frame

	var semantic_ids: Array[String] = vertical_slice.get_semantic_region_ids()
	for expected_id in ["OPEN_ARENA", "DENSE_REGION", "NATURAL_CORRIDOR", "LANDMARK_REGION", "TRANSITION"]:
		_check(expected_id in semantic_ids, "região semântica ausente: " + expected_id)
	var anchors: Dictionary = vertical_slice.get_prop_anchor_metadata()
	_check(anchors.has("dense_grove") and anchors.has("root_altar"), "metadados de âncora incompletos")
	var terrain_summary: Dictionary = vertical_slice.get_terrain_system_summary()
	_check(int(terrain_summary.get("material_count", 0)) == 4, "o chão não preservou os quatro materiais contínuos")
	_check(
		str(terrain_summary.get("trail_representation", "")) == "continuous_material_mask",
		"a trilha voltou a ser representada por sprites/decalques"
	)
	_check(int(terrain_summary.get("prop_transition_aprons", 0)) == 4, "faltam transições de terreno nos grandes objetos")
	_check(vertical_slice.batch_count() == 2, "o chão contínuo ainda deixou lotes antigos de decalques ativos")

	vertical_slice.focus_region("OPEN_ARENA")
	await _capture(world, "trail_open_arena")
	vertical_slice.focus_region("NATURAL_CORRIDOR")
	await _capture(world, "trail_natural_corridor")
	vertical_slice.focus_region("TRANSITION")
	await _capture(world, "trail_dense_transition")
	vertical_slice.focus_region("LANDMARK_REGION")
	await _capture(world, "trail_landmark")

	vertical_slice.focus_region("OPEN_ARENA")
	world.hud.visible = true
	world.hud.stage_banner.hide()
	_spawn_combat_scene(world)
	for _frame in range(24):
		await process_frame
	await _capture(world, "combat")

	var metrics := await _measure_frames(MEASURED_FRAMES)
	var average_ms := float(metrics.average_ms)
	var p95_ms := float(metrics.p95_ms)
	_check(
		average_ms <= MAX_AVERAGE_MS and p95_ms <= MAX_P95_MS,
		"piloto excedeu o gate: média %.2f ms, p95 %.2f ms" % [average_ms, p95_ms]
	)
	print(
		"FOREST VERTICAL SLICE PERFORMANCE: %d inimigos reais, %d lotes ambientais, %d nós; média %.2f ms, p95 %.2f ms"
		% [COMBAT_ENEMIES, vertical_slice.batch_count(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), average_ms, p95_ms]
	)

	world.queue_free()
	for _frame in range(4):
		await process_frame
	vertical_slice = null
	world = null
	if failures.is_empty():
		print("FOREST VERTICAL SLICE OK: rede de trilhas capturada em quatro regiões sem alterar o fluxo normal")
	quit(0 if failures.is_empty() else 1)
