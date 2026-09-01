extends RefCounted

const EnemyScene = preload("res://scenes/enemies/enemy.tscn")
const EnemyProjectileScene = preload("res://scenes/enemies/enemy_projectile.tscn")
const GemScene = preload("res://scenes/xp_gem.tscn")
const EffectScript = preload("res://scripts/effect.gd")
const DamageNumberScript = preload("res://scripts/damage_number.gd")
const WeaponFlashScript = preload("res://scripts/weapon_flash.gd")
const CrimsonReaperSlashScript = preload("res://scripts/crimson_reaper_slash.gd")
const CodexRitualScript = preload("res://scripts/codex_ritual.gd")
const VoidCollapseScript = preload("res://scripts/void_collapse.gd")
const CataclysmRuptureScript = preload("res://scripts/cataclysm_rupture.gd")
const EternalStormScript = preload("res://scripts/eternal_storm.gd")
const LegionFocusScript = preload("res://scripts/legion_focus.gd")
const AbyssalBallistaVolleyScript = preload("res://scripts/abyssal_ballista_volley.gd")
const SpiritDevourerReleaseScript = preload("res://scripts/spirit_devourer_release.gd")
const ShadowDanceSequenceScript = preload("res://scripts/shadow_dance_sequence.gd")
const LightningEffectScript = preload("res://scripts/lightning_effect.gd")

var world


func _init(owner_world) -> void:
	world = owner_world


func enemy_population_cap() -> int:
	return int(world.difficulty_data().cap)


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
	var data := GameDefs.enemy_data(kind)
	var is_boss := bool(data.get("boss", false))
	var spawn_position := get_spawn_position(580.0 if is_boss else 610.0, 670.0 if is_boss else 760.0)
	if not _position_is_finite(spawn_position):
		return null
	return _spawn_enemy_at_position(kind, spawn_position, force_elite, power_override, data)


func spawn_enemy_near(
	kind: String, origin: Vector2, minimum: float, maximum: float,
	force_elite := false, power_override := -1.0, preferred_angle := NAN
) -> Node:
	if world.game_ended or not is_instance_valid(world.player) or not has_enemy_capacity():
		return null
	var spawn_position: Vector2 = world.environment_builder.find_clear_spawn_position(
		origin, minimum, maximum, 12, preferred_angle
	)
	if not _position_is_finite(spawn_position):
		return null
	return _spawn_enemy_at_position(
		kind, spawn_position, force_elite, power_override, GameDefs.enemy_data(kind)
	)


func spawn_enemy_at_validated_position(
	kind: String, spawn_position: Vector2,
	force_elite := false, power_override := -1.0
) -> Node:
	if world.game_ended or not is_instance_valid(world.player) or not has_enemy_capacity():
		return null
	if not _position_is_finite(spawn_position):
		return null
	return _spawn_enemy_at_position(
		kind, spawn_position, force_elite, power_override, GameDefs.enemy_data(kind)
	)


func _spawn_enemy_at_position(
	kind: String, spawn_position: Vector2, force_elite: bool,
	power_override: float, data: Dictionary
) -> Node:
	var enemy = EnemyScene.instantiate()
	var phase: Dictionary = world.difficulty_data()
	var difficulty := float(phase.power) * float(world.biome.get("enemy_power", 1.0))
	if power_override > 0.0:
		difficulty = power_override
	var elite_chance := float(phase.elite_chance)
	var is_boss := bool(data.get("boss", false))
	var is_elite := force_elite or (not is_boss and randf() < elite_chance)
	enemy.setup(kind, difficulty, is_elite, world)
	world.enemies.add_child(enemy)
	enemy.global_position = spawn_position
	return enemy


func get_spawn_position(minimum := 610.0, maximum := 760.0) -> Vector2:
	if not is_instance_valid(world.player):
		return Vector2.INF
	return world.environment_builder.find_clear_spawn_position(world.player.global_position, minimum, maximum)


func _position_is_finite(position: Vector2) -> bool:
	return is_finite(position.x) and is_finite(position.y)


func add_player_projectile(projectile: Node) -> void:
	if world.projectiles.get_child_count() >= world.MAX_PLAYER_PROJECTILES:
		var oldest: Node = world.projectiles.get_child(0)
		world.player_projectile_batch_renderer.unregister_projectile(oldest)
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
	world.enemy_projectile_batch_renderer.unregister_projectile(projectile)
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


func spawn_effect(
	position: Vector2, color: Color, radius: float, duration := 0.35,
	filled := false, combat_critical_visual := false
) -> void:
	if world.effects.get_child_count() >= world.MAX_EFFECTS:
		if not combat_critical_visual or not _replace_effect_for_critical_visual():
			return
	var effect = EffectScript.new()
	effect.set_meta("combat_critical_visual", combat_critical_visual)
	world.effects.add_child(effect)
	effect.setup(position, color, radius, duration, filled, effect_visual_quality(radius, duration))
	world.effect_batch_renderer.register_effect(effect)


func _replace_effect_for_critical_visual() -> bool:
	var candidate: Node = null
	for effect in world.effects.get_children():
		if is_instance_valid(effect) and not bool(effect.get_meta("combat_critical_visual", false)):
			candidate = effect
			break
	if not is_instance_valid(candidate):
		for effect in world.effects.get_children():
			if (
				is_instance_valid(effect)
				and bool(effect.get_meta("combat_critical_visual", false))
				and not _effect_has_pending_combat_stages(effect)
			):
				candidate = effect
				break
	if not is_instance_valid(candidate):
		return false
	world.effects.remove_child(candidate)
	candidate.queue_free()
	return true


func _effect_has_pending_combat_stages(effect: Node) -> bool:
	return (
		is_instance_valid(effect)
		and effect.has_method("has_pending_combat_stages")
		and bool(effect.call("has_pending_combat_stages"))
	)


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


func spawn_crimson_reaper_slash(position: Vector2, angle: float, radius: float) -> Node:
	if world.effects.get_child_count() >= world.MAX_EFFECTS and not _replace_effect_for_critical_visual():
		return null
	var slash = CrimsonReaperSlashScript.new()
	slash.name = "CrimsonReaperSlash"
	slash.set_meta("combat_critical_visual", true)
	world.effects.add_child(slash)
	slash.setup(position, angle, radius)
	return slash


func spawn_codex_ritual(
	position: Vector2, radius: float, damage: float,
	critical_chance: float, critical_multiplier: float
) -> Node:
	if world.effects.get_child_count() >= world.MAX_EFFECTS and not _replace_effect_for_critical_visual():
		return null
	var ritual = CodexRitualScript.new()
	ritual.name = "CodexRitual"
	ritual.set_meta("combat_critical_visual", true)
	world.effects.add_child(ritual)
	ritual.setup(world, position, radius, damage, critical_chance, critical_multiplier)
	return ritual


func spawn_void_collapse(
	position: Vector2, radius: float, damage: float,
	critical_chance: float, critical_multiplier: float
) -> Node:
	if world.effects.get_child_count() >= world.MAX_EFFECTS and not _replace_effect_for_critical_visual():
		return null
	var collapse = VoidCollapseScript.new()
	collapse.name = "VoidCollapse"
	collapse.set_meta("combat_critical_visual", true)
	world.effects.add_child(collapse)
	collapse.setup(world, position, radius, damage, critical_chance, critical_multiplier)
	return collapse


func spawn_cataclysm_rupture(
	position: Vector2, direction: Vector2, radius: float, damage: float
) -> Node:
	if world.effects.get_child_count() >= world.MAX_EFFECTS and not _replace_effect_for_critical_visual():
		return null
	var rupture = CataclysmRuptureScript.new()
	rupture.name = "CataclysmRupture"
	rupture.set_meta("combat_critical_visual", true)
	world.effects.add_child(rupture)
	rupture.setup(world, position, direction, radius, damage)
	return rupture


func spawn_eternal_storm(origin: Vector2, target_entries: Array[Dictionary]) -> Node:
	if world.effects.get_child_count() >= world.MAX_EFFECTS and not _replace_effect_for_critical_visual():
		return null
	var storm = EternalStormScript.new()
	storm.name = "EternalStorm"
	storm.set_meta("combat_critical_visual", true)
	world.effects.add_child(storm)
	storm.setup(origin, target_entries)
	return storm


func spawn_legion_focus(
	owner_player: Node2D, priority_target: Node, attack_entries: Array[Dictionary]
) -> Node:
	if world.effects.get_child_count() >= world.MAX_EFFECTS and not _replace_effect_for_critical_visual():
		return null
	var focus = LegionFocusScript.new()
	focus.name = "LegionFocus"
	focus.set_meta("combat_critical_visual", true)
	world.effects.add_child(focus)
	focus.setup(world, owner_player, priority_target, attack_entries)
	return focus


func spawn_abyssal_ballista_volley(
	owner_player: Node2D, direction: Vector2, projectile_entries: Array[Dictionary]
) -> Node:
	if world.effects.get_child_count() >= world.MAX_EFFECTS and not _replace_effect_for_critical_visual():
		return null
	var volley = AbyssalBallistaVolleyScript.new()
	volley.name = "AbyssalBallistaVolley"
	volley.set_meta("combat_critical_visual", true)
	world.effects.add_child(volley)
	volley.setup(world, owner_player, direction, projectile_entries)
	return volley


func spawn_spirit_devourer_release(
	origin: Vector2, target_positions: PackedVector2Array, charge_count: int
) -> Node:
	if world.effects.get_child_count() >= world.MAX_EFFECTS and not _replace_effect_for_critical_visual():
		return null
	var release = SpiritDevourerReleaseScript.new()
	release.name = "SpiritDevourerRelease"
	release.set_meta("combat_critical_visual", true)
	world.effects.add_child(release)
	release.setup(origin, target_positions, charge_count)
	return release


func spawn_shadow_dance_sequence(
	owner_player: Node2D, projectile_entries: Array[Dictionary]
) -> Node:
	if world.effects.get_child_count() >= world.MAX_EFFECTS and not _replace_effect_for_critical_visual():
		return null
	var sequence = ShadowDanceSequenceScript.new()
	sequence.name = "ShadowDanceSequence"
	sequence.set_meta("combat_critical_visual", true)
	world.effects.add_child(sequence)
	sequence.setup(world, owner_player, projectile_entries)
	return sequence


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
