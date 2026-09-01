extends SceneTree

const WORLD_SCENE := preload("res://scenes/world.tscn")
const VOLLEY_SCRIPT := preload("res://scripts/abyssal_ballista_volley.gd")

var failures: Array[String] = []


class DummyEnemy:
	extends Node2D
	var dead := false
	var hit_radius := 10.0
	var damage_taken := 0.0

	func take_damage(amount: float, _knockback := Vector2.ZERO, _critical := false, _source := "") -> void:
		damage_taken += amount


func _initialize() -> void:
	var watchdog := create_timer(30.0, true, false, true)
	watchdog.timeout.connect(func(): push_error("ABYSSAL BALLISTA PILOT: timeout"); quit(2))
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ABYSSAL BALLISTA PILOT: " + message)


func _check_close(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (esperado %.5f, obtido %.5f)" % [message, expected, actual])


func _prepare_player(player: Node, evolved: bool) -> void:
	for weapon_id in player.WEAPON_IDS:
		player.weapon_levels[weapon_id] = 0
		player.evolved_weapons[weapon_id] = false
	player.weapon_levels.chaos_bolt = 8
	player.evolved_weapons.chaos_bolt = evolved
	player.equipped_weapon_id = "chaos_bolt"
	player.damage_multiplier = 1.0
	player.temporary_damage_multiplier = 1.0
	player.cooldown_multiplier = 1.0
	player.temporary_cooldown_multiplier = 1.0
	player.crit_chance = -1.0
	player.temporary_crit_bonus = 0.0
	player.projectile_bonus = 0
	player.last_direction = Vector2.RIGHT
	player.attack_facing_time = 0.0
	player.pending_attack_facing_x = 0.0


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
	await process_frame


func _spawn_dummy(world: Node, position: Vector2) -> DummyEnemy:
	var enemy := DummyEnemy.new()
	enemy.add_to_group("enemies")
	world.enemies.add_child(enemy)
	enemy.global_position = position
	return enemy


func _find_volley(world: Node) -> Node:
	for effect in world.effects.get_children():
		if effect.get_script() == VOLLEY_SCRIPT and not effect.is_queued_for_deletion():
			return effect
	return null


func _step_volley(volley: Node, delta: float) -> void:
	volley.set_process(false)
	volley._process(delta)


func _test_base_untouched(world: Node) -> void:
	await _clear_container(world.projectiles)
	await _clear_container(world.effects)
	await _clear_container(world.enemies)
	_prepare_player(world.player, false)
	_spawn_dummy(world, world.player.global_position + Vector2(1200.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._fire_chaos_bolt()
	_check(world.projectiles.get_child_count() == 3, "Besta base não criou imediatamente os 3 projéteis históricos")
	_check(_find_volley(world) == null, "Besta base criou formação exclusiva da evolução")
	_check_close(world.player.bolt_timer, 0.32, "cooldown da Besta base mudou")


func _test_formation_and_release(world: Node) -> void:
	await _clear_container(world.projectiles)
	await _clear_container(world.effects)
	await _clear_container(world.enemies)
	_prepare_player(world.player, true)
	var target := _spawn_dummy(world, world.player.global_position + Vector2(800.0, 0.0))
	world._rebuild_spatial_grid()
	world.player._fire_chaos_bolt()
	var volley := _find_volley(world)
	_check(is_instance_valid(volley), "Balista não criou a formação coordenada")
	_check(world.projectiles.get_child_count() == 0, "Balista causou tiro antes da formação visual")
	if not is_instance_valid(volley):
		return
	var signature: Dictionary = volley.visual_signature()
	_check_close(float(signature.formation_time), 0.20, "tempo curto de formação mudou")
	_check(int(signature.entry_count) == 5 and int(signature.formation_position_count) == 5, "formação não contém os cinco virotes históricos")
	_step_volley(volley, 0.19)
	_check(world.projectiles.get_child_count() == 0 and not bool(volley.released), "salva saiu antes do frame de liberação")
	var moved_position: Vector2 = world.player.global_position + Vector2(90.0, -35.0)
	world.player.global_position = moved_position
	target.dead = true
	target.remove_from_group("enemies")
	_step_volley(volley, 0.02)
	_check(volley.global_position.is_equal_approx(moved_position), "formação não acompanhou o jogador até a liberação")
	_check(world.projectiles.get_child_count() == 5, "salva sincronizada não liberou cinco projéteis")
	_check(int(volley.released_projectile_count) == 5, "contador de liberação não registrou a salva completa")
	for projectile in world.projectiles.get_children():
		projectile.set_physics_process(false)
		_check(Vector2(projectile.direction).x > 0.98, "alvo removido alterou a direção central já capturada")
		_check_close(float(projectile.damage), 97.58, "dano histórico da Balista mudou")
		_check_close(float(projectile.speed), 760.0, "velocidade histórica da Balista mudou")
		_check(int(projectile.pierce) == 8, "perfuração histórica da Balista mudou")
	_check(bool(volley.get_meta("combat_critical_visual", false)), "formação não foi marcada como visual crítico")


func _test_piercing_path(world: Node) -> void:
	await _clear_container(world.projectiles)
	await _clear_container(world.effects)
	await _clear_container(world.enemies)
	_prepare_player(world.player, true)
	var targets: Array[DummyEnemy] = []
	for index in range(9):
		targets.append(_spawn_dummy(world, world.player.global_position + Vector2(120.0 + index * 90.0, 0.0)))
	world._rebuild_spatial_grid()
	world.player._fire_chaos_bolt()
	var volley := _find_volley(world)
	_check(is_instance_valid(volley), "formação ausente no teste de perfuração")
	if not is_instance_valid(volley):
		return
	_step_volley(volley, 0.21)
	var center_projectile: Node = null
	var smallest_angle := INF
	for projectile in world.projectiles.get_children():
		projectile.set_physics_process(false)
		var angle := absf(Vector2(projectile.direction).angle())
		if angle < smallest_angle:
			smallest_angle = angle
			center_projectile = projectile
	_check(is_instance_valid(center_projectile), "virote central não foi encontrado")
	if not is_instance_valid(center_projectile):
		return
	for target in targets:
		center_projectile.global_position = target.global_position
		center_projectile._physics_process(0.0)
	for target in targets:
		_check_close(target.damage_taken, 97.58, "virote perfurante não atingiu cada inimigo uma vez")
	_check(center_projectile.is_queued_for_deletion(), "perfuração 8 deixou de encerrar após o nono impacto")


func _test_saturation(world: Node) -> void:
	await _clear_container(world.projectiles)
	await _clear_container(world.effects)
	await _clear_container(world.enemies)
	_prepare_player(world.player, true)
	_spawn_dummy(world, world.player.global_position + Vector2(850.0, 0.0))
	world._rebuild_spatial_grid()
	for index in range(world.MAX_EFFECTS):
		var filler := Node2D.new()
		filler.name = "CosmeticEffect%d" % index
		world.effects.add_child(filler)
	for index in range(world.MAX_PLAYER_PROJECTILES):
		var filler := Node2D.new()
		filler.name = "ProjectileCap%d" % index
		world.add_player_projectile(filler)
	world.player._fire_chaos_bolt()
	var volley := _find_volley(world)
	_check(is_instance_valid(volley), "formação crítica sumiu com 120 efeitos")
	_check(world.effects.get_child_count() == world.MAX_EFFECTS, "formação ultrapassou o teto de 120 efeitos")
	if not is_instance_valid(volley):
		return
	_step_volley(volley, 0.21)
	_check(world.projectiles.get_child_count() == world.MAX_PLAYER_PROJECTILES, "salva ultrapassou o teto de 360 projéteis")
	var ballista_projectiles := 0
	for projectile in world.projectiles.get_children():
		if str(projectile.get("source_weapon")) == "chaos_bolt":
			ballista_projectiles += 1
	_check(ballista_projectiles == 5, "teto cheio descartou parte da salva principal")


func _run() -> void:
	var world := WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.spawn_timer = 9999.0
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO

	await _test_base_untouched(world)
	await _test_formation_and_release(world)
	await _test_piercing_path(world)
	await _test_saturation(world)

	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("ABYSSAL BALLISTA PILOT OK: base intacta, formação, salva, direção, perfuração e saturação validadas")
	quit(0 if failures.is_empty() else 1)
