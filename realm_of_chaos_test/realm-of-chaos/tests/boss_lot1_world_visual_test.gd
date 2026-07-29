extends SceneTree

const TYPES := ["void_knight", "ossuary_colossus", "glacial_archon"]
const EXPECTED_TEXTURES := {
	"void_knight": "res://assets/generated/enemy_anim_void_knight.png",
	"ossuary_colossus": "res://assets/generated/boss_ossuary_colossus.png",
	"glacial_archon": "res://assets/generated/boss_glacial_archon.png"
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("BOSS LOT 1 WORLD VISUAL: " + message)


func _run() -> void:
	print("BOSS LOT 1 WORLD VISUAL STEP: instantiate")
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	print("BOSS LOT 1 WORLD VISUAL STEP: world ready")

	world.suppress_save = true
	world.spawn_timer = 9999.0
	world.director_spawn_queue.clear()
	world.player.global_position = Vector2.ZERO
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.visible = false
	world.hud.hide()

	for child in world.enemies.get_children():
		child.queue_free()
	await process_frame
	print("BOSS LOT 1 WORLD VISUAL STEP: spawn showcase")

	var positions := [
		Vector2(-330.0, -20.0),
		Vector2(0.0, -20.0),
		Vector2(330.0, -20.0)
	]
	var showcase_frames := [0, 2, 3]
	for index in range(TYPES.size()):
		var kind: String = TYPES[index]
		var boss = world.spawn_enemy(kind, false, 1.0)
		_check(is_instance_valid(boss), "world.tscn nao criou %s" % kind)
		if not is_instance_valid(boss):
			continue
		boss.global_position = positions[index]
		boss.velocity = Vector2.ZERO
		boss.set_process(false)
		boss.set_physics_process(false)
		boss.sprite.frame = showcase_frames[index]
		boss.movement_age = 1.2 + index
		boss.queue_redraw()
		_check(boss.boss, "%s nao foi instanciado como chefe" % kind)
		_check(
			boss.sprite.texture.resource_path == EXPECTED_TEXTURES[kind],
			"%s apareceu com a textura %s" % [kind, boss.sprite.texture.resource_path]
		)
		_check(
			boss.sprite.hframes == 4 and boss.sprite.vframes == 1,
			"%s nao manteve a grade 4x1 em world.tscn" % kind
		)

	print("BOSS LOT 1 WORLD VISUAL STEP: render")
	world.game_ended = true
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

	var screenshot: Image = world.get_viewport().get_texture().get_image()
	_check(
		screenshot != null and not screenshot.is_empty(),
		"captura visual de world.tscn ficou vazia"
	)
	var screenshot_path := "user://boss_lot1_world_validation.png"
	if screenshot != null and not screenshot.is_empty():
		var save_error: int = screenshot.save_png(screenshot_path)
		_check(save_error == OK, "nao foi possivel salvar a captura de world.tscn")
		if save_error == OK:
			print(
				"BOSS LOT 1 WORLD SCREENSHOT: ",
				ProjectSettings.globalize_path(screenshot_path)
			)

	print("BOSS LOT 1 WORLD VISUAL STEP: cleanup")
	for music_player in world.audio.music_players:
		music_player.stop()
		music_player.stream = null
	world.audio.cached_streams.clear()
	await process_frame

	current_scene = null
	world.queue_free()
	await process_frame
	print("BOSS LOT 1 WORLD VISUAL STEP: finish")

	if failures.is_empty():
		print("BOSS LOT 1 WORLD VISUAL OK: tres folhas e auras instanciadas em world.tscn")
	quit(0 if failures.is_empty() else 1)
