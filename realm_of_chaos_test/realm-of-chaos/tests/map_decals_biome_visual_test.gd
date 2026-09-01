extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")

const BIOME_NAMES := ["forest", "frozen", "cathedral"]
const DECAL_KINDS := ["crater", "ritual", "battle"]
const DECAL_POSITIONS := [Vector2(-330.0, 100.0), Vector2(0.0, -125.0), Vector2(330.0, 100.0)]
const DECAL_ALPHA := [0.42, 0.38, 0.44]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("MAP DECALS BIOME VISUAL: " + message)


func _capture_biome(cycle: int) -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.player.disabled = true
	world.run_cycle = cycle
	world.map_seed_offset = cycle
	world.biome = GameDefs.biome_data(cycle)
	world._apply_biome()
	world.ground.position = Vector2.ZERO
	world.player.global_position = Vector2.ZERO
	world.hud.visible = false

	var batcher = world.environment_builder.visual_batcher
	batcher.reset()
	for index in range(DECAL_KINDS.size()):
		var atlas_key: String = batcher.floor_decal_key(str(world.biome.id), DECAL_KINDS[index])
		batcher.add_visual(
			atlas_key,
			DECAL_POSITIONS[index],
			Vector2.ONE * 0.92,
			0.0,
			false,
			Color(1.0, 1.0, 1.0, DECAL_ALPHA[index]),
			-6,
			"floor_preview_" + DECAL_KINDS[index]
		)
	batcher.flush()

	var enemy_kinds := ["prowler", "mage", "brute"]
	for index in range(enemy_kinds.size()):
		var enemy = world.spawn_enemy(enemy_kinds[index], false, 1.0)
		if not is_instance_valid(enemy):
			continue
		enemy.global_position = Vector2(-250.0 + index * 250.0, 245.0)
		enemy.set_physics_process(false)

	for _frame in range(5):
		await process_frame
	var screenshot := world.get_viewport().get_texture().get_image()
	_check(not screenshot.is_empty(), "captura vazia para " + BIOME_NAMES[cycle])
	if not screenshot.is_empty():
		var output_path := "user://map_decals_%s_preview.png" % BIOME_NAMES[cycle]
		_check(screenshot.save_png(output_path) == OK, "falha ao salvar " + output_path)
		print("MAP DECALS PREVIEW: " + ProjectSettings.globalize_path(output_path))

	world.queue_free()
	await process_frame


func _run() -> void:
	for cycle in range(3):
		await _capture_biome(cycle)
	if failures.is_empty():
		print("MAP DECALS BIOME VISUAL OK: bosque, gelo e catedral renderizados com variantes proprias")
	quit(0 if failures.is_empty() else 1)
