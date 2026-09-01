extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const FROZEN_SLICE_SCRIPT := preload("res://scripts/frozen_vertical_slice.gd")
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
	capture_directory = OS.get_environment("ROC_FROZEN_SLICE_CAPTURE_DIR")
	if not capture_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_directory)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("FROZEN VERTICAL SLICE: " + message)


func _capture(world: Node, capture_name: String) -> void:
	for _frame in range(7):
		await process_frame
	RenderingServer.force_draw(false, 0.0)
	var screenshot := world.get_viewport().get_texture().get_image()
	_check(not screenshot.is_empty(), "captura vazia: " + capture_name)
	if screenshot.is_empty():
		return
	_check(screenshot.get_size() == Vector2i(1280, 720), "resolução inesperada em %s: %s" % [capture_name, screenshot.get_size()])
	var output_path := "user://frozen_vertical_slice_%s.png" % capture_name
	if not capture_directory.is_empty():
		output_path = capture_directory.path_join("frozen_vertical_slice_%s.png" % capture_name)
	_check(screenshot.save_png(output_path) == OK, "não foi possível salvar " + output_path)
	print("FROZEN VERTICAL SLICE CAPTURE: " + ProjectSettings.globalize_path(output_path))


func _spawn_combat_scene(world: Node) -> void:
	for index in range(COMBAT_ENEMIES):
		var enemy = world.spawn_enemy(ENEMY_TYPES[index % ENEMY_TYPES.size()], index % 17 == 0, 3.0)
		_check(is_instance_valid(enemy), "inimigo real não foi criado no índice %d" % index)
		if not is_instance_valid(enemy):
			continue
		var angle := TAU * float(index) / float(COMBAT_ENEMIES)
		var ring := 278.0 + float(index % 5) * 51.0
		enemy.global_position = Vector2.RIGHT.rotated(angle) * ring
		enemy.set_physics_process(false)

	for index in range(30):
		var angle := TAU * float(index) / 30.0
		var projectile = BULLET_SCENE.instantiate()
		projectile.global_position = Vector2.RIGHT.rotated(angle) * (105.0 + float(index % 4) * 22.0)
		projectile.setup(Vector2.RIGHT.rotated(angle + PI * 0.5), 0.0, 28.0, 999, 8.0, Color("9b6dff"))
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
			Color("6b8bd1").lerp(Color("a96cff"), float(index % 4) / 3.0),
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
	return {"average_ms": total_ms / float(frame_count), "p95_ms": frame_times[p95_index]}


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

	var vertical_slice = FROZEN_SLICE_SCRIPT.new()
	world.add_child(vertical_slice)
	vertical_slice.setup(world)
	await process_frame

	var semantic_ids: Array[String] = vertical_slice.get_semantic_region_ids()
	for expected_id in ["OPEN_ARENA", "DENSE_REGION", "NATURAL_CORRIDOR", "LANDMARK_REGION", "TRANSITION"]:
		_check(expected_id in semantic_ids, "região semântica ausente: " + expected_id)
	var anchors: Dictionary = vertical_slice.get_prop_anchor_metadata()
	_check(anchors.has("collapsed_cloister") and anchors.has("frozen_sanctum"), "metadados de âncora incompletos")
	var terrain_summary: Dictionary = vertical_slice.get_terrain_system_summary()
	_check(int(terrain_summary.get("material_count", 0)) == 4, "o chão não preservou os quatro materiais integrados")
	_check(str(terrain_summary.get("causeway_representation", "")) == "continuous_material_mask", "a via antiga voltou a ser um decalque separado do chão")
	_check(int(terrain_summary.get("prop_transition_aprons", 0)) == 7, "faltam transições de assentamento dos grandes objetos")
	_check(bool(terrain_summary.get("cyan_is_accent_only", false)), "o ciano deixou de ser um destaque controlado")
	_check(vertical_slice.batch_count() == 1, "a slice criou lotes ambientais inesperados")

	vertical_slice.focus_region("OPEN_ARENA")
	await _capture(world, "open_arena")
	vertical_slice.focus_region("NATURAL_CORRIDOR")
	await _capture(world, "natural_corridor")
	vertical_slice.focus_region("DENSE_REGION")
	await _capture(world, "dense_region")
	vertical_slice.focus_region("LANDMARK_REGION")
	await _capture(world, "landmark_region")

	vertical_slice.focus_region("OPEN_ARENA")
	world.hud.visible = true
	world.hud.stage_banner.hide()
	world.hud.stage_label.text = "II · RUÍNAS GLACIAIS"
	_spawn_combat_scene(world)
	for _frame in range(24):
		await process_frame
	await _capture(world, "combat")

	var metrics := await _measure_frames(MEASURED_FRAMES)
	var average_ms := float(metrics.average_ms)
	var p95_ms := float(metrics.p95_ms)
	_check(average_ms <= MAX_AVERAGE_MS and p95_ms <= MAX_P95_MS, "slice excedeu o gate: média %.2f ms, p95 %.2f ms" % [average_ms, p95_ms])
	print("FROZEN VERTICAL SLICE PERFORMANCE: %d inimigos reais, %d lotes ambientais, %d nós; média %.2f ms, p95 %.2f ms" % [COMBAT_ENEMIES, vertical_slice.batch_count(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), average_ms, p95_ms])

	world.queue_free()
	for _frame in range(4):
		await process_frame
	vertical_slice = null
	world = null
	if failures.is_empty():
		print("FROZEN VERTICAL SLICE OK: cinco regiões capturadas sem integrar as Ruínas Glaciais ao mapa principal")
	quit(0 if failures.is_empty() else 1)
