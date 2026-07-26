extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ATTACK ORIENTATION: " + message)


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
	var target = world.spawn_enemy("guardian", false, 1.0)
	target.set_process(false)
	target.set_physics_process(false)

	_test_chaos_bolt_burst(world, player, target)
	_test_target_switch_lock(world, player, target)
	_test_vertical_deadzone(player)
	_test_primary_weapon_priority(world, player, target)
	_test_shadow_blade_burst(world, player, target)
	_test_radial_and_summon_attacks(player)

	paused = false
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ATTACK ORIENTATION OK: rajadas, alvos opostos, trava, zona morta e prioridade visual validados")
		quit(0)
	else:
		quit(1)


func _test_chaos_bolt_burst(world: Node, player: Node, target: Node2D) -> void:
	_reset_orientation(player, "chaos_bolt")
	player.weapon_levels.chaos_bolt = 4
	_place_target(world, player, target, Vector2(-260.0, -35.0))
	var projectiles_before: int = world.projectiles.get_child_count()
	player._fire_chaos_bolt()
	var spawned: int = world.projectiles.get_child_count() - projectiles_before
	_check(spawned == 2, "Besta nível 4 não criou a rajada esperada de 2 projéteis")
	_check(player.sprite.flip_h, "Besta não virou imediatamente para o alvo à esquerda")
	_check(player.attack_facing_x < 0.0, "rajada não preservou a direção central à esquerda")
	_check(player.attack_facing_time > 0.20, "trava visual da Besta ficou curta demais")

	player._spawn_player_projectile(
		Vector2.RIGHT, 1.0, 100.0, 0, 2.0, Color.WHITE, "chaos_bolt"
	)
	_check(
		player.attack_direction.x > 0.0 and player.attack_facing_x < 0.0 and player.sprite.flip_h,
		"direção de um projétil individual sobrescreveu a orientação visual central"
	)


func _test_target_switch_lock(world: Node, player: Node, target: Node2D) -> void:
	player._animate_character(0.10, Vector2.RIGHT, true, 20.0)
	_place_target(world, player, target, Vector2(260.0, 35.0))
	player._fire_chaos_bolt()
	_check(player.sprite.flip_h, "alvo oposto quebrou a trava antes da pose terminar")
	_check(player.pending_attack_facing_x > 0.0, "nova direção não ficou pendente durante a trava")

	var flip_changes := 0
	var previous_flip: bool = player.sprite.flip_h
	for _frame in range(10):
		player._animate_character(1.0 / 60.0, Vector2.RIGHT, true, 4.0)
		if player.sprite.flip_h != previous_flip:
			flip_changes += 1
			previous_flip = player.sprite.flip_h
	_check(flip_changes == 1, "troca de alvo produziu %d mudanças de lado; esperado 1" % flip_changes)
	_check(not player.sprite.flip_h and player.attack_facing_x > 0.0, "direção pendente não assumiu o lado direito")

	player.last_direction = Vector2.LEFT
	player._animate_character(player.ATTACK_FACING_HOLD + 0.01, Vector2.LEFT, false, 0.0)
	_check(player.sprite.flip_h, "sprite não voltou à última direção de movimento após a pose")
	_check(player.attack_facing_time <= 0.0, "trava permaneceu ativa além da pose")


func _test_vertical_deadzone(player: Node) -> void:
	_reset_orientation(player, "chaos_bolt")
	player.last_direction = Vector2.LEFT
	player._animate_character(0.0, Vector2.LEFT, false, 0.0)
	player._set_primary_attack_facing(Vector2(0.10, -1.0), "chaos_bolt")
	_check(player.sprite.flip_h, "direção quase vertical alterou o lado do sprite")
	_check(player.attack_facing_time <= 0.0, "direção quase vertical ativou a trava")


func _test_primary_weapon_priority(world: Node, player: Node, target: Node2D) -> void:
	_reset_orientation(player, "chaos_bolt")
	player.weapon_levels.shadow_blades = 3
	_place_target(world, player, target, Vector2(-220.0, 0.0))
	player._fire_shadow_blades(3)
	_check(not player.sprite.flip_h, "arma secundária tomou a orientação da arma principal")
	_check(player.attack_facing_time <= 0.0, "arma secundária ativou a trava visual")


func _test_shadow_blade_burst(world: Node, player: Node, target: Node2D) -> void:
	_reset_orientation(player, "shadow_blades")
	player.weapon_levels.shadow_blades = 4
	_place_target(world, player, target, Vector2(-240.0, 70.0))
	var projectiles_before: int = world.projectiles.get_child_count()
	player._fire_shadow_blades(4)
	var spawned: int = world.projectiles.get_child_count() - projectiles_before
	_check(spawned == 6, "Lâminas nível 4 não criaram a rajada esperada de 6 projéteis")
	_check(player.sprite.flip_h and player.attack_facing_x < 0.0, "rajada de Lâminas não usou o centro do alvo")


func _test_radial_and_summon_attacks(player: Node) -> void:
	_reset_orientation(player, "shadow_blades")
	player.weapon_levels.shadow_blades = 6
	player.evolved_weapons.shadow_blades = true
	player._fire_shadow_blades(6)
	_check(not player.sprite.flip_h, "rajada radial alterou a orientação visual")
	_check(player.attack_facing_time <= 0.0, "rajada radial ativou trava direcional")

	_reset_orientation(player, "chaos_bolt")
	player._cast_nova(3)
	player._damage_orbit(3)
	player._release_swarm_eyes(3)
	_check(not player.sprite.flip_h, "órbita, Nova ou invocação alterou o lado do sprite")
	_check(player.attack_facing_time <= 0.0, "órbita, Nova ou invocação ativou trava direcional")


func _place_target(world: Node, player: Node2D, target: Node2D, offset: Vector2) -> void:
	target.global_position = player.global_position + offset
	world._rebuild_spatial_grid()


func _reset_orientation(player: Node, weapon_id: String) -> void:
	for current_weapon_id in player.weapon_levels:
		player.weapon_levels[current_weapon_id] = 0
		player.evolved_weapons[current_weapon_id] = false
	player._equip_weapon_visual(weapon_id)
	player.last_direction = Vector2.RIGHT
	player.attack_direction = Vector2.RIGHT
	player.attack_facing_x = 1.0
	player.attack_facing_time = 0.0
	player.pending_attack_facing_x = 0.0
	player.attack_recoil = 0.0
	player.attack_flash = 0.0
	player.projectile_bonus = 0
	player.sprite.flip_h = false
