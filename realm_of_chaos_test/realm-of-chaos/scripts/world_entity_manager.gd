extends RefCounted

const GameDefs = preload("res://scripts/game_defs.gd")
const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const EnemyProjectileScene = preload("res://scenes/enemies/enemy_projectile.tscn")
const GemScene = preload("res://scenes/xp_gem.tscn")
const EffectScript = preload("res://scripts/effect.gd")
const DamageNumberScript = preload("res://scripts/damage_number.gd")
const WeaponFlashScript = preload("res://scripts/weapon_flash.gd")
const LightningEffectScript = preload("res://scripts/lightning_effect.gd")

var world


func _init(owner_world) -> void:
	world = owner_world


func enemy_population_cap() -> int:
	return int(GameDefs.difficulty_data(world.time_survived).cap)


func remaining_enemy_capacity() -> int:
	if not is_instance_valid(world.enemies):
		return 0
	return maxi(0, enemy_population_cap() - world.enemies.get_child_count())


func has_enemy_capacity() -> bool:
	return remaining_enemy_capacity() > 0


func spawn_enemy(kind: String, force_elite := false, power_override := -1.0) -> Node:
	if world.game_ended or not is_instance_valid(world.player):
		return null
	if not has_enemy_capacity():
		return null
	var enemy = EnemyScene.instantiate()
	var phase := GameDefs.difficulty_data(world.time_survived)
	var data := GameDefs.enemy_data(kind)
	var difficulty := float(phase.power) * float(world.biome.get("enemy_power", 1.0))
	if power_override > 0.0:
		difficulty = power_override
	var elite_chance := float(phase.elite_chance)
	var is_boss := bool(data.get("boss", false))
	var is_elite := force_elite or (not is_boss and randf() < elite_chance)
	enemy.setup(kind, difficulty, is_elite, world)
	world.enemies.add_child(enemy)
	enemy.global_position = get_spawn_position(580.0 if is_boss else 610.0, 670.0 if is_boss else 760.0)
	return enemy


func get_spawn_position(minimum := 610.0, maximum := 760.0) -> Vector2:
	if not is_instance_valid(world.player):
		return Vector2.ZERO
	var fallback: Vector2 = world.player.global_position
	for _attempt in range(12):
		var angle := randf() * TAU
		var candidate: Vector2 = world.player.global_position + Vector2.RIGHT.rotated(angle) * randf_range(minimum, maximum)
		fallback = candidate
		if absf(candidate.x) > 5420.0 or absf(candidate.y) > 5420.0:
			continue
		if world.environment_builder.is_spawn_position_clear(candidate):
			return candidate
	return Vector2(clampf(fallback.x, -5420.0, 5420.0), clampf(fallback.y, -5420.0, 5420.0))


func add_player_projectile(projectile: Node) -> void:
	if world.projectiles.get_child_count() >= world.MAX_PLAYER_PROJECTILES:
		var oldest: Node = world.projectiles.get_child(0)
		world.projectiles.remove_child(oldest)
		oldest.queue_free()
	world.projectiles.add_child(projectile)
	world.player_projectile_batch_renderer.register_projectile(projectile)


func spawn_enemy_projectile(
	position: Vector2, direction: Vector2, amount: float, projectile_speed: float,
	color: Color, size: float, danger_style := false
) -> Node:
	var projectile: Node
	if world.enemy_projectiles.get_child_count() >= world.MAX_ENEMY_PROJECTILES:
		projectile = world.enemy_projectiles.get_child(0)
		world.enemy_projectiles.move_child(projectile, world.enemy_projectiles.get_child_count() - 1)
	elif world.enemy_projectile_pool.get_child_count() > 0:
		projectile = world.enemy_projectile_pool.get_child(world.enemy_projectile_pool.get_child_count() - 1)
		projectile.reparent(world.enemy_projectiles)
	else:
		projectile = EnemyProjectileScene.instantiate()
		world.enemy_projectiles.add_child(projectile)
	projectile.global_position = position
	projectile.setup(direction, amount, projectile_speed, color, size, danger_style, world, world.player)
	world.enemy_projectile_batch_renderer.register_projectile(projectile)
	return projectile


func recycle_enemy_projectile(projectile: Node) -> void:
	if not is_instance_valid(projectile) or bool(projectile.get("active")):
		return
	if projectile.get_parent() == world.enemy_projectile_pool:
		return
	if world.enemy_projectile_pool.get_child_count() >= world.ENEMY_PROJECTILE_POOL_LIMIT:
		projectile.queue_free()
		return
	projectile.reparent(world.enemy_projectile_pool)


func add_enemy_projectile(projectile: Node) -> void:
	# Compatibilidade para chamadas externas: novos disparos usam spawn_enemy_projectile().
	if world.enemy_projectiles.get_child_count() >= world.MAX_ENEMY_PROJECTILES:
		var oldest: Node = world.enemy_projectiles.get_child(0)
		if oldest.has_method("prepare_for_pool"):
			oldest.prepare_for_pool()
		recycle_enemy_projectile(oldest)
	world.enemy_projectiles.add_child(projectile)
	if projectile.has_method("bind_runtime"):
		projectile.bind_runtime(world, world.player)
	world.enemy_projectile_batch_renderer.register_projectile(projectile)


func spawn_pickup(amount: int, position: Vector2, kind := "xp") -> Node:
	if world.pickups.get_child_count() >= world.MAX_PICKUPS:
		if kind == "xp":
			var merged_pickup := _merge_xp_into_existing(amount)
			if is_instance_valid(merged_pickup):
				return merged_pickup
			_remove_pickup(_least_valuable_heal())
		elif not _consolidate_two_xp_pickups():
			var heal_to_replace := _least_valuable_heal()
			if not is_instance_valid(heal_to_replace) or int(heal_to_replace.get("value")) > amount:
				return null
			_remove_pickup(heal_to_replace)
	var pickup = GemScene.instantiate()
	world.pickups.add_child(pickup)
	pickup.setup(amount, position, kind)
	world.pickup_batch_renderer.register_pickup(pickup)
	return pickup


func _merge_xp_into_existing(amount: int) -> Node:
	var pickup_count: int = world.pickups.get_child_count()
	for offset in range(pickup_count):
		var index: int = (world.pickup_merge_cursor + offset) % pickup_count
		var existing = world.pickups.get_child(index)
		if is_instance_valid(existing) and str(existing.get("pickup_kind")) == "xp":
			existing.value += amount
			_refresh_merged_xp(existing)
			world.pickup_merge_cursor = (index + 1) % pickup_count
			return existing
	return null


func _consolidate_two_xp_pickups() -> bool:
	var first_xp: Node = null
	var second_xp: Node = null
	for pickup in world.pickups.get_children():
		if not is_instance_valid(pickup) or str(pickup.get("pickup_kind")) != "xp":
			continue
		if not is_instance_valid(first_xp):
			first_xp = pickup
		else:
			second_xp = pickup
			break
	if not is_instance_valid(second_xp):
		return false
	second_xp.set("value", int(second_xp.get("value")) + int(first_xp.get("value")))
	second_xp.set("attracted", bool(second_xp.get("attracted")) or bool(first_xp.get("attracted")))
	_refresh_merged_xp(second_xp)
	_remove_pickup(first_xp)
	var pickup_count: int = world.pickups.get_child_count()
	world.pickup_merge_cursor = (second_xp.get_index() + 1) % pickup_count if pickup_count > 0 else 0
	return true


func _least_valuable_heal() -> Node:
	var selected: Node = null
	var selected_value := 0
	for pickup in world.pickups.get_children():
		if not is_instance_valid(pickup) or str(pickup.get("pickup_kind")) != "heal":
			continue
		var pickup_value := int(pickup.get("value"))
		if not is_instance_valid(selected) or pickup_value < selected_value:
			selected = pickup
			selected_value = pickup_value
	return selected


func _refresh_merged_xp(pickup: Node) -> void:
	pickup.set("attracted", bool(pickup.get("attracted")) or int(pickup.get("value")) >= 64)
	if pickup.has_method("request_visual_refresh"):
		pickup.request_visual_refresh()


func _remove_pickup(pickup: Node) -> void:
	if not is_instance_valid(pickup) or pickup.get_parent() != world.pickups:
		return
	world.pickup_batch_renderer.set_pickup_visible(pickup, false)
	var removed_index := pickup.get_index()
	world.pickups.remove_child(pickup)
	pickup.queue_free()
	var pickup_count: int = world.pickups.get_child_count()
	if pickup_count <= 0:
		world.pickup_merge_cursor = 0
	elif removed_index < world.pickup_merge_cursor:
		world.pickup_merge_cursor = (world.pickup_merge_cursor - 1) % pickup_count
	else:
		world.pickup_merge_cursor %= pickup_count


func spawn_effect(position: Vector2, color: Color, radius: float, duration := 0.35, filled := false) -> void:
	if world.effects.get_child_count() >= world.MAX_EFFECTS:
		return
	var effect = EffectScript.new()
	world.effects.add_child(effect)
	effect.setup(position, color, radius, duration, filled, effect_visual_quality(radius, duration))
	world.effect_batch_renderer.register_effect(effect)


func effect_visual_quality(radius: float, duration: float) -> int:
	var effect_count: int = world.effects.get_child_count()
	var enemy_count: int = world.enemies.get_child_count()
	var quality := 2
	if effect_count >= world.EFFECT_HIGH_LOAD or enemy_count >= world.ENEMY_HIGH_VISUAL_LOAD:
		quality = 0
	elif effect_count >= world.EFFECT_MEDIUM_LOAD or enemy_count >= world.ENEMY_MEDIUM_VISUAL_LOAD or world.enemy_projectiles.get_child_count() >= 96:
		quality = 1
	# Golpes grandes e telegráficos mantêm ao menos a leitura intermediária.
	if radius >= 140.0 or duration >= 0.50:
		quality = maxi(quality, 1)
	return quality


func spawn_weapon_flash(
	position: Vector2, atlas_frame: int, angle: float, scale_value: float,
	duration := 0.35, tint := Color.WHITE
) -> void:
	if world.effects.get_child_count() >= world.MAX_EFFECTS:
		return
	var flash = WeaponFlashScript.new()
	world.effects.add_child(flash)
	flash.setup(position, atlas_frame, angle, scale_value, duration, tint)


func spawn_lightning(chain_points: PackedVector2Array, color := Color("6eeaff")) -> void:
	if world.effects.get_child_count() >= world.MAX_EFFECTS:
		return
	var lightning = LightningEffectScript.new()
	world.effects.add_child(lightning)
	lightning.setup(chain_points, color, 0.24, effect_visual_quality(80.0, 0.24))


func spawn_damage_number(position: Vector2, amount: float, critical := false, healing := false, custom_text := "") -> void:
	if world.effects.get_child_count() >= world.MAX_EFFECTS:
		return
	var number = DamageNumberScript.new()
	world.effects.add_child(number)
	number.setup(position, amount, critical, healing, custom_text)
