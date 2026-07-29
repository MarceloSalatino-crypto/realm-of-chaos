extends SceneTree

const TYPES := ["prowler", "assassin", "brute", "guardian"]
const EXPECTED_TEXTURES := {
	"prowler": "res://assets/generated/enemy_anim_prowler.png",
	"assassin": "res://assets/generated/enemy_anim_assassin.png",
	"brute": "res://assets/generated/enemy_anim_brute.png",
	"guardian": "res://assets/generated/enemy_anim_guardian.png"
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("ENEMY BATCH 1 WORLD VISUAL: " + message)


func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame

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

	var positions := [
		Vector2(-330.0, -45.0),
		Vector2(-115.0, -45.0),
		Vector2(115.0, -45.0),
		Vector2(330.0, -45.0)
	]
	for index in range(TYPES.size()):
		var kind: String = TYPES[index]
		var enemy = world.spawn_enemy(kind, false, 1.0)
		_check(is_instance_valid(enemy), "world.tscn nao criou %s" % kind)
		if not is_instance_valid(enemy):
			continue
		enemy.global_position = positions[index]
		enemy.velocity = Vector2.ZERO
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemy.sprite.frame = 0
		_check(
			enemy.sprite.texture.resource_path == EXPECTED_TEXTURES[kind],
			"%s apareceu com a textura %s" % [kind, enemy.sprite.texture.resource_path]
		)

	world.game_ended = true
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

	var screenshot: Image = world.get_viewport().get_texture().get_image()
	_check(not screenshot.is_empty(), "captura visual de world.tscn ficou vazia")
	var screenshot_path := "user://enemy_batch_1_world_validation.png"
	if not screenshot.is_empty():
		var save_error: int = screenshot.save_png(screenshot_path)
		_check(save_error == OK, "nao foi possivel salvar a captura de world.tscn")
		if save_error == OK:
			print(
				"ENEMY BATCH 1 WORLD SCREENSHOT: ",
				ProjectSettings.globalize_path(screenshot_path)
			)

	if failures.is_empty():
		print("ENEMY BATCH 1 WORLD VISUAL OK: quatro tipos instanciados em world.tscn com texturas proprias")
	quit(0 if failures.is_empty() else 1)
