extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")
const EXPECTED_ANIMATION_FINGERPRINT := "walk:f1,0:c1.000:p0.000,-0.335:s1.000,1.000:r0.0051:sh1.014,0.983,0.382|attack:f2,1:r0.480:fl0.000:p-0.618,-0.346:s0.997,1.005|idle:f0,0:c0.000:p-0.186,-0.234:s1.003,0.998:r-0.0022:sh1.023,0.970,0.377"

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(20.0, true, false, true)
	watchdog.timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _on_watchdog_timeout() -> void:
	push_error("PLAYER VISUAL CONTROLLER: teste excedeu 20 segundos")
	quit(2)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PLAYER VISUAL CONTROLLER: " + message)


func _check_close(actual: float, expected: float, message: String, tolerance := 0.002) -> void:
	_check(absf(actual - expected) <= tolerance, "%s (esperado %.4f, obtido %.4f)" % [message, expected, actual])


func _reset_visual(player) -> void:
	player.disabled = false
	player.death_started = false
	player.motion_age = 0.0
	player.last_direction = Vector2.RIGHT
	player.attack_direction = Vector2.RIGHT
	player.attack_facing_x = 1.0
	player.attack_facing_time = 0.0
	player.pending_attack_facing_x = 0.0
	player.attack_recoil = 0.0
	player.attack_flash = 0.0
	player.hurt_recoil = 0.0
	player.walk_animation_clock = 0.0
	player.velocity = Vector2.ZERO
	player.visual.position = Vector2.ZERO
	player.visual.rotation = 0.0
	player.visual.scale = Vector2.ONE
	player.visual.modulate = Color.WHITE
	player.sprite.position = Vector2.ZERO
	player.sprite.rotation = 0.0
	player.sprite.scale = Vector2.ONE
	player.sprite.flip_h = false
	player.sprite.frame_coords = Vector2i.ZERO
	player.shadow.scale = Vector2.ONE
	player.shadow.color = Color(0.01, 0.005, 0.02, 0.40)


func _animation_fingerprint(player) -> String:
	_reset_visual(player)
	player.motion_age = 0.73
	for _step in range(4):
		player._animate_character(1.0 / 60.0, Vector2.RIGHT, true, 21.5)
	var walk_signature := "walk:f%d,%d:c%.3f:p%.3f,%.3f:s%.3f,%.3f:r%.4f:sh%.3f,%.3f,%.3f" % [
		player.sprite.frame_coords.x, player.sprite.frame_coords.y,
		player.walk_animation_clock,
		player.visual.position.x, player.visual.position.y,
		player.visual.scale.x, player.visual.scale.y, player.visual.rotation,
		player.shadow.scale.x, player.shadow.scale.y, player.shadow.color.a
	]

	player.attack_recoil = 1.0
	player.attack_flash = 1.0
	player.attack_direction = Vector2.LEFT
	player._animate_character(0.13, Vector2.LEFT, false, 0.0)
	var attack_signature := "attack:f%d,%d:r%.3f:fl%.3f:p%.3f,%.3f:s%.3f,%.3f" % [
		player.sprite.frame_coords.x, player.sprite.frame_coords.y,
		player.attack_recoil, player.attack_flash,
		player.visual.position.x, player.visual.position.y,
		player.visual.scale.x, player.visual.scale.y
	]

	player.attack_recoil = 0.0
	player.attack_flash = 0.0
	player.walk_animation_clock = 2.75
	player.motion_age = 1.31
	player.hurt_recoil = 0.65
	player._animate_character(0.08, Vector2.ZERO, false, 0.0)
	var idle_signature := "idle:f%d,%d:c%.3f:p%.3f,%.3f:s%.3f,%.3f:r%.4f:sh%.3f,%.3f,%.3f" % [
		player.sprite.frame_coords.x, player.sprite.frame_coords.y,
		player.walk_animation_clock,
		player.visual.position.x, player.visual.position.y,
		player.visual.scale.x, player.visual.scale.y, player.visual.rotation,
		player.shadow.scale.x, player.shadow.scale.y, player.shadow.color.a
	]
	return "%s|%s|%s" % [walk_signature, attack_signature, idle_signature]


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	var player = world.player
	player.set_process(false)
	player.set_physics_process(false)

	for method_name in [
		&"_equip_weapon_visual", &"_animate_character",
		&"_play_death_animation", &"_draw"
	]:
		_check(player.has_method(method_name), "API visual ausente: %s" % method_name)

	player.motion_age = 1.25
	player.walk_animation_clock = 2.5
	player.attack_facing_x = -1.0
	player.attack_facing_time = 0.2
	player.pending_attack_facing_x = 1.0
	_check(
		player.motion_age == 1.25 and player.walk_animation_clock == 2.5
		and player.attack_facing_x == -1.0 and player.pending_attack_facing_x == 1.0,
		"estado visual público deixou de ser gravável"
	)

	var expected_textures := {
		"chaos_bolt": "res://assets/generated/hero_anim_chaos_bolt.png",
		"shadow_blades": "res://assets/generated/hero_anim_shadow_blades.png",
		"soul_orbit": "res://assets/generated/hero_anim_soul_orbit.png",
		"chaos_nova": "res://assets/generated/hero_anim_chaos_nova.png"
	}
	for weapon_id in expected_textures:
		player._equip_weapon_visual(weapon_id)
		_check(player.equipped_weapon_id == weapon_id, "arma visual equipada mudou: %s" % weapon_id)
		_check(
			player.sprite.texture != null
			and player.sprite.texture.resource_path == expected_textures[weapon_id],
			"spritesheet incorreto: %s" % weapon_id
		)
		_check(
			player.sprite.hframes == 4 and player.sprite.vframes == 2
			and player.sprite.frame_coords == Vector2i.ZERO,
			"grade ou pose inicial mudou: %s" % weapon_id
		)
	var equipped_before: String = player.equipped_weapon_id
	var texture_before: Texture2D = player.sprite.texture
	player._equip_weapon_visual("weapon_without_visual")
	_check(
		player.equipped_weapon_id == equipped_before and player.sprite.texture == texture_before,
		"arma sem spritesheet alterou o visual atual"
	)

	var animation_fingerprint := _animation_fingerprint(player)
	print("PLAYER VISUAL FINGERPRINT: " + animation_fingerprint)
	_check(
		animation_fingerprint == EXPECTED_ANIMATION_FINGERPRINT,
		"fingerprint de caminhada, ataque, repouso ou sombra mudou"
	)

	_reset_visual(player)
	player.equipped_weapon_id = "chaos_bolt"
	player.last_direction = Vector2.RIGHT
	player._set_primary_attack_facing(Vector2.LEFT, "chaos_bolt")
	_check(player.sprite.flip_h and player.attack_facing_time > 0.20, "orientação visual não virou e travou")
	player._set_primary_attack_facing(Vector2.RIGHT, "chaos_bolt")
	player._animate_character(0.10, Vector2.RIGHT, true, 4.0)
	_check(player.sprite.flip_h and player.pending_attack_facing_x > 0.0, "direção pendente quebrou a trava")
	var flip_changes := 0
	var previous_flip: bool = player.sprite.flip_h
	for _frame in range(24):
		player._animate_character(1.0 / 60.0, Vector2.RIGHT, true, 4.0)
		if player.sprite.flip_h != previous_flip:
			flip_changes += 1
			previous_flip = player.sprite.flip_h
	_check(flip_changes == 1 and not player.sprite.flip_h, "trava visual produziu tremor")
	player.attack_facing_time = 0.0
	player.last_direction = Vector2.LEFT
	player._set_primary_attack_facing(Vector2(0.10, -1.0), "chaos_bolt")
	player._animate_character(0.0, Vector2.ZERO, false, 0.0)
	_check(player.sprite.flip_h and player.attack_facing_time <= 0.0, "zona morta vertical mudou")

	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
	player.attack_recoil = 0.0
	player.attack_flash = 0.0
	player.invulnerability = 0.25
	player._physics_process(0.0)
	_check_close(player.visual.modulate.a, 0.45, "piscar de invulnerabilidade claro mudou")
	player.invulnerability = 0.20
	player._physics_process(0.0)
	_check_close(player.visual.modulate.a, 1.0, "piscar de invulnerabilidade escuro mudou")

	var draw_count := [0]
	player.draw.connect(func() -> void: draw_count[0] += 1)
	player.weapon_levels.soul_orbit = 3
	player.attack_flash = 0.8
	player.queue_redraw()
	await process_frame
	await process_frame
	_check(draw_count[0] > 0, "desenho customizado de órbita/flash não foi solicitado")

	_reset_visual(player)
	player.collision_shape.set_deferred("disabled", false)
	await process_frame
	var died_count := [0]
	player.died.connect(func() -> void: died_count[0] += 1)
	player.last_direction = Vector2.LEFT
	player.velocity = Vector2(80.0, 20.0)
	player._play_death_animation()
	player._play_death_animation()
	_check(
		player.death_started and player.disabled and player.velocity == Vector2.ZERO,
		"estado imediato da morte visual mudou"
	)
	await process_frame
	_check(player.collision_shape.disabled, "morte visual não desativou a colisão")
	await create_timer(0.55).timeout
	_check_close(player.visual.rotation, -0.46, "rotação final da morte mudou")
	_check(player.visual.position.is_equal_approx(Vector2(-8.0, 13.0)), "posição final da morte mudou")
	_check(player.visual.scale.is_equal_approx(Vector2(1.12, 0.72)), "escala final da morte mudou")
	_check(player.visual.modulate.is_equal_approx(Color(0.55, 0.30, 0.68, 0.0)), "cor final da morte mudou")
	_check(player.shadow.scale.is_equal_approx(Vector2(1.35, 0.45)), "sombra final da morte mudou")
	_check(player.shadow.color.is_equal_approx(Color(0.01, 0.005, 0.02, 0.0)), "cor final da sombra mudou")
	_check(died_count[0] == 1, "animação de morte emitiu sinal mais de uma vez")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYER VISUAL CONTROLLER OK: spritesheets, caminhada, ataque, orientação, sombra, flash, desenho e morte validados")
	quit(0 if failures.is_empty() else 1)
