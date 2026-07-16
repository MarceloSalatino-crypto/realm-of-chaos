extends CharacterBody2D

signal level_up_requested
signal died

const GameDefs = preload("res://scripts/game_defs.gd")

@export var bullet_scene: PackedScene

var move_speed := 235.0
var hp := 125.0
var max_hp := 125.0
var armor := 0.0
var regeneration := 0.0
var damage_multiplier := 1.0
var cooldown_multiplier := 1.0
var crit_chance := 0.05
var pickup_radius := 105.0

var level := 1
var experience := 0
var experience_needed := 12
var disabled := false
var invulnerability := 0.0
var motion_age := 0.0
var last_direction := Vector2.RIGHT

var weapon_levels := {
	"chaos_bolt": 1,
	"shadow_blades": 0,
	"soul_orbit": 0,
	"chaos_nova": 0
}
var passive_levels := {
	"might": 0, "haste": 0, "vitality": 0, "swiftness": 0,
	"magnet": 0, "armor": 0, "regeneration": 0, "critical": 0
}
var bolt_timer := 0.15
var blades_timer := 1.0
var nova_timer := 4.0
var orbit_tick := 0.0
var orbit_angle := 0.0
var orbit_hit_times: Dictionary = {}

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D


func _ready() -> void:
	hp = max_hp


func _physics_process(delta: float) -> void:
	if disabled:
		velocity = Vector2.ZERO
		return
	motion_age += delta
	invulnerability = maxf(0.0, invulnerability - delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() > 0.01:
		last_direction = direction.normalized()
	velocity = direction * move_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, -5550.0, 5550.0)
	global_position.y = clampf(global_position.y, -5550.0, 5550.0)

	sprite.flip_h = last_direction.x < 0.0
	var is_moving := direction.length_squared() > 0.01
	visual.position.y = sin(motion_age * (8.0 if is_moving else 3.0)) * (2.3 if is_moving else 1.2)
	visual.rotation = sin(motion_age * 6.0) * 0.018 if is_moving else 0.0
	if invulnerability > 0.0:
		visual.modulate.a = 0.45 if int(invulnerability * 18.0) % 2 == 0 else 1.0
	else:
		visual.modulate.a = 1.0

	if regeneration > 0.0 and hp < max_hp:
		heal(regeneration * delta, false)
	_update_weapons(delta)


func _update_weapons(delta: float) -> void:
	bolt_timer -= delta
	if bolt_timer <= 0.0:
		_fire_chaos_bolt()

	var blade_level: int = weapon_levels.shadow_blades
	if blade_level > 0:
		blades_timer -= delta
		if blades_timer <= 0.0:
			_fire_shadow_blades(blade_level)

	var orbit_level: int = weapon_levels.soul_orbit
	if orbit_level > 0:
		orbit_angle += delta * (1.8 + orbit_level * 0.16)
		orbit_tick -= delta
		if orbit_tick <= 0.0:
			_damage_orbit(orbit_level)
		queue_redraw()

	var nova_level: int = weapon_levels.chaos_nova
	if nova_level > 0:
		nova_timer -= delta
		if nova_timer <= 0.0:
			_cast_nova(nova_level)


func _fire_chaos_bolt() -> void:
	var target := _nearest_enemy()
	var weapon_level: int = weapon_levels.chaos_bolt
	bolt_timer = maxf(0.16, (0.68 - weapon_level * 0.045) * cooldown_multiplier)
	if not target:
		return
	var count := 1 + int((weapon_level - 1) / 3.0)
	var base_direction := (target.global_position - global_position).normalized()
	for index in range(count):
		var offset := float(index) - float(count - 1) * 0.5
		_spawn_player_projectile(
			base_direction.rotated(offset * 0.12),
			(14.0 + weapon_level * 4.2) * damage_multiplier,
			650.0, int(weapon_level / 3.0), 8.0 + weapon_level * 0.7, Color("a96cff")
		)


func _fire_shadow_blades(weapon_level: int) -> void:
	var target := _nearest_enemy()
	blades_timer = maxf(0.45, (2.0 - weapon_level * 0.16) * cooldown_multiplier)
	if not target:
		return
	var count := 2 + weapon_level
	var base_direction := (target.global_position - global_position).normalized()
	for index in range(count):
		var offset := float(index) - float(count - 1) * 0.5
		_spawn_player_projectile(
			base_direction.rotated(offset * 0.13),
			(10.0 + weapon_level * 3.0) * damage_multiplier,
			760.0, 1, 6.0, Color("ff557d")
		)


func _spawn_player_projectile(
	direction: Vector2, amount: float, projectile_speed: float,
	pierce: int, size: float, color: Color
) -> void:
	if not bullet_scene:
		return
	var bullet = bullet_scene.instantiate()
	var is_critical := randf() < crit_chance
	if is_critical:
		amount *= 2.0
	bullet.global_position = global_position + direction * 22.0
	bullet.setup(direction, amount, projectile_speed, pierce, size, color, is_critical)
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.add_player_projectile(bullet)
	else:
		bullet.queue_free()


func _damage_orbit(weapon_level: int) -> void:
	orbit_tick = 0.10
	var radius := 72.0 + weapon_level * 8.0
	var blade_count := 2 + int(weapon_level / 2.0)
	var now := Time.get_ticks_msec()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > radius + enemy.hit_radius:
			continue
		var enemy_id := enemy.get_instance_id()
		if now - int(orbit_hit_times.get(enemy_id, 0)) < 430:
			continue
		for index in range(blade_count):
			var blade_position := global_position + Vector2.RIGHT.rotated(orbit_angle + TAU * index / blade_count) * radius
			if blade_position.distance_to(enemy.global_position) <= 28.0 + enemy.hit_radius:
				orbit_hit_times[enemy_id] = now
				enemy.take_damage((8.0 + weapon_level * 3.0) * damage_multiplier, (enemy.global_position - global_position).normalized() * 8.0)
				break


func _cast_nova(weapon_level: int) -> void:
	var radius := 155.0 + weapon_level * 24.0
	nova_timer = maxf(2.4, (6.2 - weapon_level * 0.48) * cooldown_multiplier)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= radius + enemy.hit_radius:
			var force: Vector2 = (enemy.global_position - global_position).normalized() * 85.0
			enemy.take_damage((25.0 + weapon_level * 9.0) * damage_multiplier, force)
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.spawn_effect(global_position, Color("bd72ff"), radius, 0.55, true)


func _nearest_enemy() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func take_damage(amount: float, _source_direction := Vector2.ZERO) -> void:
	if disabled or invulnerability > 0.0:
		return
	var final_damage := maxf(1.0, amount - armor)
	hp = maxf(0.0, hp - final_damage)
	invulnerability = 0.58
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.on_player_damaged()
	if hp <= 0.0:
		disabled = true
		died.emit()


func heal(amount: float, show_effect := true) -> void:
	var old_hp := hp
	hp = minf(max_hp, hp + amount)
	if show_effect and hp > old_hp:
		var world := get_tree().get_first_node_in_group("world")
		if world:
			world.spawn_effect(global_position, Color("65ff9a"), 55.0, 0.35)


func collect_xp(amount: int) -> void:
	experience += amount
	while experience >= experience_needed:
		experience -= experience_needed
		level += 1
		experience_needed = int(round(10.0 + pow(level, 1.34) * 5.2))
		level_up_requested.emit()


func get_upgrade_options(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for definition in GameDefs.upgrades():
		if get_upgrade_level(definition.id) < int(definition.max):
			pool.append(definition.duplicate())
	pool.shuffle()
	var options: Array[Dictionary] = []
	for definition in pool.slice(0, mini(count, pool.size())):
		var current := get_upgrade_level(definition.id)
		definition["level"] = current + 1
		definition["rarity"] = _roll_rarity()
		options.append(definition)
	return options


func _roll_rarity() -> String:
	var roll := randf()
	if roll < 0.08:
		return "LENDÁRIO"
	if roll < 0.28:
		return "RARO"
	return "COMUM"


func get_upgrade_level(upgrade_id: String) -> int:
	if weapon_levels.has(upgrade_id):
		return int(weapon_levels[upgrade_id])
	return int(passive_levels.get(upgrade_id, 0))


func apply_upgrade(upgrade_id: String, rarity := "COMUM") -> void:
	var bonus := 2 if rarity == "LENDÁRIO" else 1
	if weapon_levels.has(upgrade_id):
		weapon_levels[upgrade_id] = mini(8, int(weapon_levels[upgrade_id]) + bonus)
		return
	passive_levels[upgrade_id] = int(passive_levels.get(upgrade_id, 0)) + 1
	match upgrade_id:
		"might":
			damage_multiplier *= 1.15 if rarity == "COMUM" else 1.22
		"haste":
			cooldown_multiplier *= 0.90 if rarity == "COMUM" else 0.84
		"vitality":
			var gain := 25.0 if rarity == "COMUM" else 40.0
			max_hp += gain
			heal(gain)
		"swiftness":
			move_speed *= 1.08 if rarity == "COMUM" else 1.13
		"magnet":
			pickup_radius *= 1.35 if rarity == "COMUM" else 1.55
		"armor":
			armor += 2.0 if rarity == "COMUM" else 3.0
		"regeneration":
			regeneration += 0.65 if rarity == "COMUM" else 1.0
		"critical":
			crit_chance += 0.07 if rarity == "COMUM" else 0.11


func weapon_summary() -> String:
	var names: Array[String] = []
	if weapon_levels.chaos_bolt > 0:
		names.append("Seta %d" % weapon_levels.chaos_bolt)
	if weapon_levels.shadow_blades > 0:
		names.append("Lâminas %d" % weapon_levels.shadow_blades)
	if weapon_levels.soul_orbit > 0:
		names.append("Órbita %d" % weapon_levels.soul_orbit)
	if weapon_levels.chaos_nova > 0:
		names.append("Nova %d" % weapon_levels.chaos_nova)
	return "  ·  ".join(names)


func _draw() -> void:
	var orbit_level: int = weapon_levels.soul_orbit
	if orbit_level <= 0:
		return
	var radius := 72.0 + orbit_level * 8.0
	var blade_count := 2 + int(orbit_level / 2.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.63, 0.30, 1.0, 0.18), 2.0)
	for index in range(blade_count):
		var position := Vector2.RIGHT.rotated(orbit_angle + TAU * index / blade_count) * radius
		draw_circle(position, 14.0, Color(0.53, 0.20, 0.95, 0.18))
		draw_colored_polygon(PackedVector2Array([
			position + Vector2(-3, -12), position + Vector2(5, 0), position + Vector2(-3, 12), position + Vector2(-8, 0)
		]), Color("d9b3ff"))
