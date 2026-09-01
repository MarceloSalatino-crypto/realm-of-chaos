extends SceneTree

const WORLD_SCENE = preload("res://scenes/world.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var watchdog := create_timer(25.0, true, false, true)
	watchdog.timeout.connect(func():
		push_error("CROSS-EVOLUTION PROJECTILE CAP: teste excedeu 25 segundos")
		quit(2)
	)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("CROSS-EVOLUTION PROJECTILE CAP: " + message)


func _run() -> void:
	var world = WORLD_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.suppress_save = true
	world.audio.enabled = false
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_process(false)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2.ZERO
	world.player.damage_multiplier = 1.0
	world.player.temporary_damage_multiplier = 1.0
	world.player.crit_chance = -1.0
	world.player.temporary_crit_bonus = 0.0

	# O projétil mais antigo pertence à Ceifadora Carmesim.
	world.player.combat.spawn_crimson_crescent(Vector2.RIGHT, 6, 245.0, {})
	_check(world.projectiles.get_child_count() == 1, "Ceifadora não criou o projétil mais antigo")
	var oldest: Node = world.projectiles.get_child(0)
	oldest.set_physics_process(false)
	var oldest_id := oldest.get_instance_id()
	_check(str(oldest.get("source_weapon")) == "blood_scythe", "projétil mais antigo não pertence à Ceifadora")

	# Preenche as posições intermediárias com projéteis reais da Balista/Besta.
	while world.projectiles.get_child_count() < world.MAX_PLAYER_PROJECTILES:
		world.player.combat.spawn_player_projectile(
			Vector2.RIGHT, 1.0, 0.0, 0, 6.0,
			Color("a96cff"), "chaos_bolt", false
		)
		world.projectiles.get_child(world.projectiles.get_child_count() - 1).set_physics_process(false)
	_check(world.projectiles.get_child_count() == 360, "preenchimento não atingiu exatamente 360 projéteis")
	_check(world.player_projectile_batch_renderer._entries_by_id.has(oldest_id), "batch não registrou o projétil mais antigo")

	# O 361º pertence à Dança das Sombras e deve substituir o mais antigo global.
	var newest: Node = world.player.combat.spawn_shadow_dance_projectile(
		Vector2(-40.0, 12.0), Vector2.LEFT, 1.0, 0.0,
		1, 8.0, Color("df63ff"), false, true
	)
	_check(is_instance_valid(newest), "Dança não criou o 361º projétil")
	var newest_id := newest.get_instance_id() if is_instance_valid(newest) else 0
	if is_instance_valid(newest):
		newest.set_physics_process(false)
	_check(world.projectiles.get_child_count() == 360, "361º projétil alterou o teto global")
	_check(oldest.get_parent() == null, "política oldest-first não removeu o projétil mais antigo")
	_check(world.projectiles.get_child(world.projectiles.get_child_count() - 1) == newest, "novo projétil não entrou no final da ordem")
	_check(not world.player_projectile_batch_renderer._entries_by_id.has(oldest_id), "batch manteve ID do projétil removido")
	_check(world.player_projectile_batch_renderer._entries_by_id.has(newest_id), "batch não registrou o projétil da nova evolução")
	_check(world.player_projectile_batch_renderer._entries.size() == 360, "batch divergiu do teto de 360")

	await process_frame
	_check(not is_instance_valid(oldest), "projétil removido continuou vivo após o frame de limpeza")
	for projectile in world.projectiles.get_children():
		projectile.queue_free()
	await process_frame
	await process_frame
	_check(world.projectiles.get_child_count() == 0, "limpeza final manteve projéteis")
	_check(world.player_projectile_batch_renderer._entries.is_empty(), "limpeza final manteve IDs órfãos no batch")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("CROSS-EVOLUTION PROJECTILE CAP OK: Ceifadora mais antiga removida pelo 361º da Dança; 360 IDs e limpeza validados")
		quit(0)
	else:
		quit(1)
