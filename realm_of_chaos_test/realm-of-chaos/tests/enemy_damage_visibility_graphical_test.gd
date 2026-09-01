extends SceneTree

const RANGED_TYPES := ["mage", "archer", "necromancer", "void_knight"]

var failures: Array[String] = []
var capture_directory := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("ENEMY DAMAGE VISIBILITY GRAPHICAL: " + message)


func _capture(world: Node, capture_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := world.get_viewport().get_texture().get_image()
	_check(not image.is_empty(), "captura vazia: " + capture_name)
	if image.is_empty():
		return
	var output_path := capture_directory.path_join(capture_name + ".png")
	_check(image.save_png(output_path) == OK, "não foi possível salvar " + output_path)
	print("COMBAT VISIBILITY CAPTURE: " + output_path)


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
	await process_frame


func _prepare_player(world: Node) -> void:
	world.player.set_physics_process(false)
	world.player.disabled = false
	world.player.dodge_chance = 0.0
	world.player.invulnerability = 0.0
	world.player.hp = world.player.max_hp
	world.player.global_position = Vector2.ZERO


func _capture_contact_feedback(world: Node) -> void:
	await _clear(world.enemies)
	await _clear(world.enemy_projectiles)
	_prepare_player(world)
	var directions := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	for index in range(RANGED_TYPES.size()):
		var enemy = world.spawn_enemy(RANGED_TYPES[index], false, 1.0)
		enemy.set_physics_process(false)
		enemy.player = world.player
		enemy.global_position = directions[index] * (float(enemy.hit_radius) + 20.0)
		enemy.cast_cooldown = 0.0
		enemy.special_cooldown = 999.0
		enemy.damage_cooldown = 0.0
		world.player.invulnerability = 0.0
		enemy._physics_process(1.0 / 60.0)
		_check(enemy.contact_attack_visual_time > 0.0, "%s não exibiu golpe de contato" % RANGED_TYPES[index])
		_check(enemy.pending_projectile_attack.is_empty(), "%s misturou contato e disparo" % RANGED_TYPES[index])
	await _capture(world, "ranged_contact_feedback")


func _capture_projectile_before_damage(world: Node) -> void:
	await _clear(world.enemies)
	await _clear(world.enemy_projectiles)
	_prepare_player(world)
	var hp_before: float = world.player.hp
	var projectile = world.spawn_enemy_projectile(
		world.player.global_position + Vector2(4.0, 0.0), Vector2.LEFT,
		12.0, 245.0, Color("ff496d"), 8.0, true
	)
	# Mesmo sob vários ticks de física sem frame renderizado, o disparo não
	# pode acertar nem desaparecer.
	for _tick in range(8):
		projectile._physics_process(1.0 / 12.0)
	_check(is_equal_approx(world.player.hp, hp_before), "projétil acertou antes da apresentação sob FPS desfavorável")
	_check(projectile.active and projectile.visible, "projétil sumiu antes da apresentação")
	await _capture(world, "projectile_visible_before_damage")
	_check(projectile.visual_presented, "batch não confirmou o projétil após o frame desenhado")
	var danger_batch: Dictionary = world.enemy_projectile_batch_renderer._batches.danger
	_check(danger_batch.multimesh.visible_instance_count >= 1, "batch perigoso não continha o projétil no frame da captura")
	projectile._physics_process(1.0 / 60.0)
	_check(world.player.hp < hp_before, "projétil apresentado deixou de causar o dano original")


func _fill_effect_budget(world: Node) -> void:
	await _clear(world.effects)
	while world.effects.get_child_count() < world.MAX_EFFECTS:
		var cosmetic := Node2D.new()
		cosmetic.set_meta("combat_critical_visual", false)
		world.effects.add_child(cosmetic)


func _critical_effects(world: Node) -> int:
	var total := 0
	for effect in world.effects.get_children():
		if bool(effect.get_meta("combat_critical_visual", false)):
			total += 1
	return total


func _capture_saturated_danger(world: Node) -> void:
	await _clear(world.enemies)
	await _fill_effect_budget(world)
	_prepare_player(world)
	var boss = world.spawn_enemy("ossuary_colossus", false, 1.0)
	boss.set_physics_process(false)
	boss.player = world.player
	boss.global_position = Vector2(88.0, -35.0)
	boss._ground_slam(165.0, 0.82)
	var bomber = world.spawn_enemy("bomber", false, 1.0)
	bomber.set_physics_process(false)
	bomber.player = world.player
	bomber.global_position = Vector2(-78.0, 38.0)
	world.player.invulnerability = 0.0
	bomber.take_damage(bomber.max_hp + 1.0, Vector2.ZERO, false, "graphical_visibility_test")
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "visuais críticos ultrapassaram o teto de efeitos")
	_check(_critical_effects(world) >= 2, "slam/Bomber não substituíram cosméticos no teto")
	await _capture(world, "dangerous_effects_at_full_budget")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("ENEMY DAMAGE VISIBILITY GRAPHICAL SKIPPED: requer renderização real")
		quit(0)
		return
	capture_directory = OS.get_environment("ROC_COMBAT_VISIBILITY_CAPTURE_DIR")
	if capture_directory.is_empty():
		capture_directory = ProjectSettings.globalize_path("user://combat_visibility")
	_check(DirAccess.make_dir_recursive_absolute(capture_directory) == OK, "não foi possível criar diretório de capturas")

	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await RenderingServer.frame_post_draw
	world.suppress_save = true
	world.spawn_timer = 9999.0
	world.set_process(false)
	world.audio.enabled = false
	_prepare_player(world)

	_check(world.player_projectile_batch_renderer.z_index == 12, "batch do jogador não está em z=12 em execução")
	_check(world.enemy_projectile_batch_renderer.z_index == 11, "batch inimigo não está em z=11 em execução")
	_check(world.pickup_batch_renderer.z_index == 2, "batch de pickups não está em z=2 em execução")
	_check(world.effect_batch_renderer.z_index == 14, "batch de efeitos não está em z=14 em execução")

	await _capture_contact_feedback(world)
	await _capture_projectile_before_damage(world)
	await _capture_saturated_danger(world)

	for music_player in world.audio.music_players:
		music_player.stop()
		music_player.stream = null
	world.audio.cached_streams.clear()
	current_scene = null
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY DAMAGE VISIBILITY GRAPHICAL OK: world real comprovou contato, projétil antes do dano e perigos no teto")
	quit(0 if failures.is_empty() else 1)
