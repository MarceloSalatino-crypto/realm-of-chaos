extends SceneTree

const TYPES := [
	"prowler", "assassin", "bat", "swarm",
	"mage", "necromancer", "archer", "brute",
	"guardian", "ember", "bomber"
]
const EXPECTED_TEXTURES := {
	"prowler": "res://assets/generated/enemy_anim_prowler.png",
	"assassin": "res://assets/generated/enemy_anim_assassin.png",
	"bat": "res://assets/generated/enemy_anim_bat.png",
	"swarm": "res://assets/generated/enemy_anim_swarm.png",
	"mage": "res://assets/generated/enemy_anim_mage.png",
	"necromancer": "res://assets/generated/enemy_anim_necromancer.png",
	"archer": "res://assets/generated/enemy_anim_archer.png",
	"brute": "res://assets/generated/enemy_anim_brute.png",
	"guardian": "res://assets/generated/enemy_anim_guardian.png",
	"ember": "res://assets/generated/enemy_anim_ember.png",
	"bomber": "res://assets/generated/enemy_anim_bomber.png"
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("ENEMY COMMON WORLD VISUAL: " + message)


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
		Vector2(-420.0, -170.0),
		Vector2(-140.0, -170.0),
		Vector2(140.0, -170.0),
		Vector2(420.0, -170.0),
		Vector2(-420.0, 30.0),
		Vector2(-140.0, 30.0),
		Vector2(140.0, 30.0),
		Vector2(420.0, 30.0),
		Vector2(-280.0, 230.0),
		Vector2(0.0, 230.0),
		Vector2(280.0, 230.0)
	]
	var observed_paths: Dictionary = {}
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
		var texture_path: String = enemy.sprite.texture.resource_path
		_check(
			texture_path == EXPECTED_TEXTURES[kind],
			"%s apareceu com a textura %s" % [kind, texture_path]
		)
		_check(
			not observed_paths.has(texture_path),
			"%s compartilhou a textura de %s" % [kind, observed_paths.get(texture_path, "outro tipo")]
		)
		observed_paths[texture_path] = kind

	_check(observed_paths.size() == TYPES.size(), "world.tscn nao exibiu onze texturas unicas")

	world.game_ended = true
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

	var screenshot: Image = world.get_viewport().get_texture().get_image()
	_check(not screenshot.is_empty(), "captura visual de world.tscn ficou vazia")
	var screenshot_path := "user://enemy_common_world_validation.png"
	if not screenshot.is_empty():
		var save_error: int = screenshot.save_png(screenshot_path)
		_check(save_error == OK, "nao foi possivel salvar a captura de world.tscn")
		if save_error == OK:
			print(
				"ENEMY COMMON WORLD SCREENSHOT: ",
				ProjectSettings.globalize_path(screenshot_path)
			)

	for music_player in world.audio.music_players:
		music_player.stop()
		music_player.stream = null
	world.audio.cached_streams.clear()
	await process_frame

	current_scene = null
	world.queue_free()
	await process_frame

	if failures.is_empty():
		print("ENEMY COMMON WORLD VISUAL OK: onze tipos instanciados em world.tscn com silhuetas proprias")
	quit(0 if failures.is_empty() else 1)
