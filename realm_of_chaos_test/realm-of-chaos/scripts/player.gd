extends CharacterBody2D

signal level_up_requested
signal died

const GameDefs = preload("res://scripts/game_defs.gd")
const WEAPON_IDS: Array[String] = ["chaos_bolt", "shadow_blades", "soul_orbit", "chaos_nova"]
const WEAPON_TEXTURES := {
	"chaos_bolt": preload("res://assets/generated/weapon_chaos_bolt.png"),
	"shadow_blades": preload("res://assets/generated/weapon_shadow_blades.png"),
	"soul_orbit": preload("res://assets/generated/weapon_soul_orbit.png"),
	"chaos_nova": preload("res://assets/generated/weapon_chaos_nova.png")
}
const WEAPON_VISUALS := {
	"chaos_bolt": {"scale": 0.044, "offset": Vector2(20.0, -6.0), "rotation": 0.0},
	"shadow_blades": {"scale": 0.043, "offset": Vector2(14.0, -13.0), "rotation": 0.0},
	"soul_orbit": {"scale": 0.044, "offset": Vector2(9.0, -14.0), "rotation": 0.0},
	"chaos_nova": {"scale": 0.044, "offset": Vector2(12.0, -17.0), "rotation": 0.0}
}
const WEAPON_TITLES := {
	"chaos_bolt": "BESTA DO CAOS",
	"shadow_blades": "LÂMINA SOMBRIA",
	"soul_orbit": "CETRO DAS ALMAS",
	"chaos_nova": "CAJADO DA NOVA"
}

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
var attack_direction := Vector2.RIGHT
var attack_recoil := 0.0
var attack_flash := 0.0
var hurt_recoil := 0.0
var death_started := false
var equipped_weapon_id := ""

var weapon_levels := {
	"chaos_bolt": 0,
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
@onready var rig: Node2D = $Visual/Rig
@onready var sprite: Sprite2D = $Visual/Rig/Body
@onready var cape: Sprite2D = $Visual/Rig/Cape
@onready var front_arm: Node2D = $Visual/Rig/FrontArm
@onready var back_arm: Node2D = $Visual/Rig/BackArm
@onready var front_leg: Node2D = $Visual/Rig/FrontLeg
@onready var back_leg: Node2D = $Visual/Rig/BackLeg
@onready var weapon_pivot: Node2D = $Visual/Rig/FrontArm/WeaponPivot
@onready var weapon_sprite: Sprite2D = $Visual/Rig/FrontArm/WeaponPivot/Weapon
@onready var shadow: Polygon2D = $Shadow
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	hp = max_hp
	_roll_starting_weapon()


func _roll_starting_weapon() -> void:
	for weapon_id in WEAPON_IDS:
		weapon_levels[weapon_id] = 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	equipped_weapon_id = WEAPON_IDS[rng.randi_range(0, WEAPON_IDS.size() - 1)]
	weapon_levels[equipped_weapon_id] = 1
	_equip_weapon_visual(equipped_weapon_id)
	bolt_timer = 0.12
	blades_timer = 0.18
	nova_timer = 0.65
	orbit_tick = 0.05


func _equip_weapon_visual(weapon_id: String) -> void:
	if not WEAPON_TEXTURES.has(weapon_id):
		return
	equipped_weapon_id = weapon_id
	var visual_data: Dictionary = WEAPON_VISUALS[weapon_id]
	weapon_sprite.texture = WEAPON_TEXTURES[weapon_id]
	weapon_sprite.scale = Vector2.ONE * float(visual_data.scale)
	weapon_sprite.position = visual_data.offset
	weapon_sprite.rotation = float(visual_data.rotation)


func equipped_weapon_title() -> String:
	return str(WEAPON_TITLES.get(equipped_weapon_id, "ARMA DO CAOS"))


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

	var is_moving := direction.length_squared() > 0.01
	_animate_character(delta, direction, is_moving)
	if invulnerability > 0.0:
		visual.modulate.a = 0.45 if int(invulnerability * 18.0) % 2 == 0 else 1.0
	else:
		visual.modulate.a = 1.0

	if regeneration > 0.0 and hp < max_hp:
		heal(regeneration * delta, false)
	_update_weapons(delta)


func _animate_character(delta: float, direction: Vector2, is_moving: bool) -> void:
	attack_recoil = move_toward(attack_recoil, 0.0, delta * 7.5)
	attack_flash = move_toward(attack_flash, 0.0, delta * 8.5)
	hurt_recoil = move_toward(hurt_recoil, 0.0, delta * 6.0)
	rig.scale.x = -1.0 if last_direction.x < 0.0 else 1.0
	rig.scale.y = 1.0

	var breathe := sin(motion_age * 2.35)
	var stride := sin(motion_age * 10.5)
	var hop: float = absf(sin(motion_age * 10.5)) if is_moving else (breathe + 1.0) * 0.5
	var target_scale := Vector2(1.0, 1.0)
	var target_rotation := 0.0
	var target_position := Vector2.ZERO
	if is_moving:
		target_scale = Vector2(1.0 + stride * 0.025, 1.0 - stride * 0.035)
		target_rotation = stride * 0.028 + direction.x * 0.018
		target_position = Vector2(-last_direction.x * attack_recoil * 3.5, -hop * 4.0)
	else:
		target_scale = Vector2(1.0 - breathe * 0.012, 1.0 + breathe * 0.018)
		target_rotation = breathe * 0.006
		target_position = Vector2(-last_direction.x * attack_recoil * 3.5, -hop * 1.4)
	if hurt_recoil > 0.0:
		target_scale += Vector2(hurt_recoil * 0.09, -hurt_recoil * 0.09)
		target_rotation += sin(motion_age * 42.0) * hurt_recoil * 0.055

	var smoothing := 1.0 - exp(-delta * 15.0)
	visual.scale = visual.scale.lerp(target_scale, smoothing)
	visual.rotation = lerpf(visual.rotation, target_rotation, smoothing)
	visual.position = visual.position.lerp(target_position, smoothing)

	var walk_weight := 1.0 if is_moving else 0.0
	var front_leg_target := stride * 0.30 * walk_weight
	var back_leg_target := -stride * 0.30 * walk_weight
	var front_arm_target := -stride * 0.20 * walk_weight + breathe * 0.025
	var back_arm_target := stride * 0.22 * walk_weight - breathe * 0.025
	var weapon_target := 0.0
	if attack_recoil > 0.0:
		var attack_progress := 1.0 - attack_recoil
		match equipped_weapon_id:
			"shadow_blades":
				front_arm_target += sin(attack_progress * PI) * 1.35 - attack_recoil * 0.42
				back_arm_target -= sin(attack_progress * PI) * 0.28
			"chaos_nova":
				front_arm_target -= attack_recoil * 1.05
				back_arm_target += attack_recoil * 0.62
				weapon_target = sin(attack_progress * PI) * 0.18
			"soul_orbit":
				front_arm_target += sin(attack_progress * TAU) * 0.58
			"chaos_bolt":
				front_arm_target -= attack_recoil * 0.58
				back_arm_target += attack_recoil * 0.20
				weapon_target = -front_arm_target * 0.55
	if equipped_weapon_id == "soul_orbit":
		weapon_target += sin(motion_age * 2.8) * 0.10
	front_leg.rotation = lerpf(front_leg.rotation, front_leg_target, smoothing)
	back_leg.rotation = lerpf(back_leg.rotation, back_leg_target, smoothing)
	front_arm.rotation = lerpf(front_arm.rotation, front_arm_target, smoothing)
	back_arm.rotation = lerpf(back_arm.rotation, back_arm_target, smoothing)
	weapon_pivot.rotation = lerpf(weapon_pivot.rotation, weapon_target, smoothing)
	cape.rotation = lerpf(cape.rotation, -stride * 0.035 * walk_weight + breathe * 0.012, smoothing)
	var shadow_scale := Vector2(1.0 + hop * 0.035, 1.0 - hop * 0.045)
	shadow.scale = shadow.scale.lerp(shadow_scale, 1.0 - exp(-delta * 10.0))
	shadow.color.a = lerpf(shadow.color.a, 0.40 - hop * 0.035, smoothing)
	if attack_flash > 0.0 or weapon_levels.soul_orbit > 0:
		queue_redraw()


func _update_weapons(delta: float) -> void:
	var bolt_level: int = weapon_levels.chaos_bolt
	if bolt_level > 0:
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
	attack_direction = direction
	attack_recoil = 1.0
	attack_flash = 1.0
	queue_redraw()
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
	attack_direction = last_direction
	attack_recoil = 1.0
	attack_flash = 1.0
	queue_redraw()
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


func take_damage(amount: float, source_direction := Vector2.ZERO) -> void:
	if disabled or invulnerability > 0.0:
		return
	var final_damage := maxf(1.0, amount - armor)
	hp = maxf(0.0, hp - final_damage)
	invulnerability = 0.58
	hurt_recoil = 1.0
	if source_direction.length_squared() > 0.01:
		last_direction = -source_direction.normalized()
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.on_player_damaged()
	if hp <= 0.0:
		_play_death_animation()


func _play_death_animation() -> void:
	if death_started:
		return
	death_started = true
	disabled = true
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "rotation", -0.46 if last_direction.x < 0.0 else 0.46, 0.48)
	tween.tween_property(visual, "position", Vector2(8.0 * signf(last_direction.x), 13.0), 0.48)
	tween.tween_property(visual, "scale", Vector2(1.12, 0.72), 0.34)
	tween.tween_property(visual, "modulate", Color(0.55, 0.30, 0.68, 0.0), 0.48)
	tween.tween_property(shadow, "scale", Vector2(1.35, 0.45), 0.48)
	tween.tween_property(shadow, "color", Color(0.01, 0.005, 0.02, 0.0), 0.48)
	tween.chain().tween_callback(func(): died.emit())


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
		names.append("Besta %d" % weapon_levels.chaos_bolt)
	if weapon_levels.shadow_blades > 0:
		names.append("Lâmina %d" % weapon_levels.shadow_blades)
	if weapon_levels.soul_orbit > 0:
		names.append("Cetro %d" % weapon_levels.soul_orbit)
	if weapon_levels.chaos_nova > 0:
		names.append("Cajado %d" % weapon_levels.chaos_nova)
	return "  ·  ".join(names)


func _draw() -> void:
	var orbit_level: int = weapon_levels.soul_orbit
	if orbit_level > 0:
		var radius := 72.0 + orbit_level * 8.0
		var blade_count := 2 + int(orbit_level / 2.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.63, 0.30, 1.0, 0.18), 2.0)
		for index in range(blade_count):
			var position := Vector2.RIGHT.rotated(orbit_angle + TAU * index / blade_count) * radius
			draw_circle(position, 14.0, Color(0.53, 0.20, 0.95, 0.18))
			draw_colored_polygon(PackedVector2Array([
				position + Vector2(-3, -12), position + Vector2(5, 0), position + Vector2(-3, 12), position + Vector2(-8, 0)
			]), Color("d9b3ff"))
	if attack_flash > 0.0:
		var muzzle := attack_direction * 39.0 + Vector2(0.0, -9.0)
		var glow := Color(0.78, 0.38, 1.0, attack_flash * 0.34)
		draw_circle(muzzle, 19.0 * attack_flash, glow)
		draw_line(muzzle - attack_direction * 9.0, muzzle + attack_direction * 16.0, Color(0.94, 0.76, 1.0, attack_flash), 3.0)
