extends CharacterBody2D

signal level_up_requested
signal died

const GameDefs = preload("res://scripts/game_defs.gd")
const HomingEyeScript = preload("res://scripts/homing_eye.gd")
const STARTING_WEAPON_IDS: Array[String] = ["chaos_bolt", "shadow_blades", "soul_orbit", "chaos_nova"]
const WEAPON_IDS: Array[String] = [
	"chaos_bolt", "shadow_blades", "soul_orbit", "chaos_nova",
	"blood_scythe", "forbidden_grimoire", "rune_hammer", "storm_relic", "swarm_idol"
]
const MAX_WEAPONS := 6
const WALK_FRAME_DISTANCE := 21.5
const WALK_MIN_SPEED := 6.0
const WALK_MAX_FPS := 15.0
const WEAPON_TEXTURES := {
	"chaos_bolt": preload("res://assets/generated/hero_anim_chaos_bolt.png"),
	"shadow_blades": preload("res://assets/generated/hero_anim_shadow_blades.png"),
	"soul_orbit": preload("res://assets/generated/hero_anim_soul_orbit.png"),
	"chaos_nova": preload("res://assets/generated/hero_anim_chaos_nova.png")
}
const WEAPON_TITLES := {
	"chaos_bolt": "BESTA DO CAOS",
	"shadow_blades": "LÂMINA SOMBRIA",
	"soul_orbit": "CETRO DAS ALMAS",
	"chaos_nova": "CAJADO DA NOVA",
	"blood_scythe": "FOICE HEMÁTICA",
	"forbidden_grimoire": "GRIMÓRIO PROIBIDO",
	"rune_hammer": "MARTELO RÚNICO",
	"storm_relic": "RELÍQUIA DA TEMPESTADE",
	"swarm_idol": "ÍDOLO DO ENXAME"
}

@export var bullet_scene: PackedScene

var move_speed := 235.0
var movement_acceleration := 1450.0
var movement_deceleration := 1850.0
var hp := 125.0
var max_hp := 125.0
var armor := 0.0
var regeneration := 0.0
var damage_multiplier := 1.0
var cooldown_multiplier := 1.0
var crit_chance := 0.05
var critical_multiplier := 2.0
var pickup_radius := 105.0
var projectile_bonus := 0
var life_steal := 0.0
var boss_damage_multiplier := 1.0
var dodge_chance := 0.0
var revive_charges := 0
var character_id := "eclipse_hunter"
var character_applied := false
var character_color := Color.WHITE
var character_skill_name := "RAJADA DO ECLIPSE"
var character_guard_time := 0.0
var relic_levels: Dictionary = {}
var banished_upgrades: Dictionary = {}
var hazard_tick := 0.0
var dash_cooldown := 0.0
var dash_duration := 0.0
var dash_direction := Vector2.RIGHT
var dash_speed := 760.0
var blessing_time := 0.0
var blessing_title := ""
var temporary_damage_multiplier := 1.0
var temporary_cooldown_multiplier := 1.0
var temporary_move_multiplier := 1.0
var temporary_pickup_multiplier := 1.0
var temporary_crit_bonus := 0.0
var temporary_armor := 0.0

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
var walk_animation_clock := 0.0

var weapon_levels := {
	"chaos_bolt": 0,
	"shadow_blades": 0,
	"soul_orbit": 0,
	"chaos_nova": 0,
	"blood_scythe": 0,
	"forbidden_grimoire": 0,
	"rune_hammer": 0,
	"storm_relic": 0,
	"swarm_idol": 0
}
var passive_levels := {
	"might": 0, "haste": 0, "vitality": 0, "swiftness": 0,
	"magnet": 0, "armor": 0, "regeneration": 0, "critical": 0
}
var evolved_weapons := {
	"chaos_bolt": false,
	"shadow_blades": false,
	"soul_orbit": false,
	"chaos_nova": false,
	"blood_scythe": false,
	"forbidden_grimoire": false,
	"rune_hammer": false,
	"storm_relic": false,
	"swarm_idol": false
}
var bolt_timer := 0.15
var blades_timer := 1.0
var nova_timer := 4.0
var orbit_tick := 0.0
var orbit_angle := 0.0
var orbit_hit_times: Dictionary = {}
var scythe_timer := 0.8
var grimoire_timer := 1.6
var hammer_timer := 1.4
var storm_timer := 0.9
var swarm_timer := 1.2

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D
@onready var shadow: Polygon2D = $Shadow
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_ensure_gameplay_actions()
	hp = max_hp
	_roll_starting_weapon()


func _ensure_gameplay_actions() -> void:
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var dash_key := InputEventKey.new()
		dash_key.physical_keycode = KEY_SPACE
		InputMap.action_add_event("dash", dash_key)
		var dash_button := InputEventJoypadButton.new()
		dash_button.button_index = JOY_BUTTON_A
		InputMap.action_add_event("dash", dash_button)
	if not InputMap.has_action("map_toggle"):
		InputMap.add_action("map_toggle")
		var map_key := InputEventKey.new()
		map_key.physical_keycode = KEY_M
		InputMap.action_add_event("map_toggle", map_key)


func _roll_starting_weapon() -> void:
	for weapon_id in WEAPON_IDS:
		weapon_levels[weapon_id] = 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	equipped_weapon_id = STARTING_WEAPON_IDS[rng.randi_range(0, STARTING_WEAPON_IDS.size() - 1)]
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
	sprite.texture = WEAPON_TEXTURES[weapon_id]
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.frame_coords = Vector2i.ZERO


func equipped_weapon_title() -> String:
	return str(WEAPON_TITLES.get(equipped_weapon_id, "ARMA DO CAOS"))


func _physics_process(delta: float) -> void:
	if disabled:
		velocity = Vector2.ZERO
		return
	motion_age += delta
	invulnerability = maxf(0.0, invulnerability - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_duration = maxf(0.0, dash_duration - delta)
	character_guard_time = maxf(0.0, character_guard_time - delta)
	_update_temporary_blessing(delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() > 0.01:
		last_direction = direction.normalized()
	var environment := {"speed": 1.0, "traction": 1.0, "damage": 0.0, "name": ""}
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_environment_effect"):
		environment = world.get_environment_effect(global_position)
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		_start_dash(direction, world)
	var desired_velocity := direction * move_speed * temporary_move_multiplier * float(environment.get("speed", 1.0))
	var traction := float(environment.get("traction", 1.0))
	if dash_duration > 0.0:
		velocity = dash_direction * dash_speed
	elif direction.length_squared() > 0.01:
		velocity = velocity.move_toward(desired_velocity, movement_acceleration * traction * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, movement_deceleration * traction * delta)
	var movement_start_position := global_position
	move_and_slide()
	global_position.x = clampf(global_position.x, -5550.0, 5550.0)
	global_position.y = clampf(global_position.y, -5550.0, 5550.0)
	var distance_moved := movement_start_position.distance_to(global_position)
	var actual_speed := distance_moved / maxf(delta, 0.0001)
	var is_moving := actual_speed > WALK_MIN_SPEED

	_animate_character(delta, direction, is_moving, distance_moved)
	if invulnerability > 0.0:
		visual.modulate.a = 0.45 if int(invulnerability * 18.0) % 2 == 0 else 1.0
	else:
		visual.modulate.a = 1.0

	if regeneration > 0.0 and hp < max_hp:
		heal(regeneration * delta, false)
	hazard_tick -= delta
	var hazard_damage := float(environment.get("damage", 0.0))
	if hazard_damage > 0.0 and hazard_tick <= 0.0:
		hazard_tick = 0.5
		take_damage(hazard_damage * 0.5, Vector2.ZERO, true)
	_update_weapons(delta)


func _start_dash(input_direction: Vector2, world: Node) -> void:
	dash_direction = input_direction.normalized() if input_direction.length_squared() > 0.01 else last_direction
	dash_duration = 0.18
	dash_cooldown = 3.2
	invulnerability = maxf(invulnerability, 0.34)
	attack_direction = dash_direction
	if world and world.has_method("on_player_dash"):
		world.on_player_dash(dash_direction)
	_activate_character_skill(world)


func _activate_character_skill(world: Node) -> void:
	if not world:
		return
	attack_recoil = 1.0
	match character_id:
		"glacial_oracle":
			for enemy in _enemies_near(245.0):
				if not is_instance_valid(enemy):
					continue
				enemy.take_damage(18.0 * effective_damage_multiplier(), (enemy.global_position - global_position).normalized() * 24.0, false, "oracle_skill")
				if enemy.has_method("apply_slow"):
					enemy.apply_slow(0.45, 2.5)
			world.spawn_effect(global_position, Color("70dcff"), 245.0, 0.48, true)
		"crimson_knight":
			var hits := 0
			for enemy in _enemies_near(175.0):
				if not is_instance_valid(enemy):
					continue
				enemy.take_damage(26.0 * effective_damage_multiplier(), (enemy.global_position - global_position).normalized() * 55.0, false, "knight_skill")
				hits += 1
			character_guard_time = 1.8
			heal(minf(18.0, hits * 2.2), false)
			world.spawn_weapon_flash(global_position + dash_direction * 34.0, 0, dash_direction.angle() - 0.65, 0.34, 0.28, Color("ff6b72"))
		"void_automaton":
			var candidates := _enemies_near(520.0)
			candidates.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
			var points := PackedVector2Array([global_position])
			for enemy in candidates.slice(0, mini(7, candidates.size())):
				if is_instance_valid(enemy):
					enemy.take_damage(15.0 * effective_damage_multiplier(), Vector2.ZERO, false, "automaton_skill")
					points.append(enemy.global_position)
			world.spawn_lightning(points, Color("b873ff"))
		_:
			var base_direction := dash_direction
			var target := _nearest_enemy()
			if target:
				base_direction = (target.global_position - global_position).normalized()
			for index in range(5):
				var offset := float(index) - 2.0
				_spawn_player_projectile(base_direction.rotated(offset * 0.14), 19.0 * effective_damage_multiplier(), 830.0, 2, 7.0, Color("f0d2ff"), "hunter_skill", true)


func _update_temporary_blessing(delta: float) -> void:
	if blessing_time <= 0.0:
		return
	blessing_time = maxf(0.0, blessing_time - delta)
	if blessing_time <= 0.0:
		blessing_title = ""
		temporary_damage_multiplier = 1.0
		temporary_cooldown_multiplier = 1.0
		temporary_move_multiplier = 1.0
		temporary_pickup_multiplier = 1.0
		temporary_crit_bonus = 0.0
		temporary_armor = 0.0


func _animate_character(delta: float, direction: Vector2, is_moving: bool, distance_moved := 0.0) -> void:
	attack_recoil = move_toward(attack_recoil, 0.0, delta * 4.0)
	attack_flash = move_toward(attack_flash, 0.0, delta * 8.5)
	hurt_recoil = move_toward(hurt_recoil, 0.0, delta * 6.0)
	sprite.flip_h = last_direction.x < 0.0
	if is_moving:
		var actual_speed := distance_moved / maxf(delta, 0.0001)
		var walk_fps := minf(actual_speed / WALK_FRAME_DISTANCE, WALK_MAX_FPS)
		walk_animation_clock += delta * walk_fps
	elif attack_recoil <= 0.0:
		walk_animation_clock = 0.0

	if attack_recoil > 0.0:
		var attack_progress := clampf(1.0 - attack_recoil, 0.0, 0.999)
		sprite.frame_coords = Vector2i(mini(3, int(attack_progress * 4.0)), 1)
	elif is_moving:
		sprite.frame_coords = Vector2i(int(floor(walk_animation_clock)) % 4, 0)
	else:
		sprite.frame_coords = Vector2i.ZERO

	var breathe := sin(motion_age * 2.35)
	var stride := sin(walk_animation_clock * TAU / 4.0)
	var hop: float = absf(stride) if is_moving else (breathe + 1.0) * 0.5
	var target_scale := Vector2(1.0, 1.0)
	var target_rotation := 0.0
	var target_position := Vector2.ZERO
	if is_moving:
		target_rotation = direction.x * 0.008
		target_position = Vector2(-last_direction.x * attack_recoil * 1.5, -hop * 0.65)
	else:
		target_scale = Vector2(1.0 - breathe * 0.004, 1.0 + breathe * 0.006)
		target_rotation = breathe * 0.002
		target_position = Vector2(-last_direction.x * attack_recoil * 1.5, -hop * 0.35)
	if hurt_recoil > 0.0:
		target_scale += Vector2(hurt_recoil * 0.035, -hurt_recoil * 0.035)
		target_rotation += sin(motion_age * 42.0) * hurt_recoil * 0.025

	var smoothing := 1.0 - exp(-delta * 15.0)
	visual.scale = visual.scale.lerp(target_scale, smoothing)
	visual.rotation = lerpf(visual.rotation, target_rotation, smoothing)
	visual.position = visual.position.lerp(target_position, smoothing)
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

	var scythe_level: int = weapon_levels.blood_scythe
	if scythe_level > 0:
		scythe_timer -= delta
		if scythe_timer <= 0.0:
			_swing_blood_scythe(scythe_level)

	var grimoire_level: int = weapon_levels.forbidden_grimoire
	if grimoire_level > 0:
		grimoire_timer -= delta
		if grimoire_timer <= 0.0:
			_cast_forbidden_grimoire(grimoire_level)

	var hammer_level: int = weapon_levels.rune_hammer
	if hammer_level > 0:
		hammer_timer -= delta
		if hammer_timer <= 0.0:
			_slam_rune_hammer(hammer_level)

	var storm_level: int = weapon_levels.storm_relic
	if storm_level > 0:
		storm_timer -= delta
		if storm_timer <= 0.0:
			_cast_storm_chain(storm_level)

	var swarm_level: int = weapon_levels.swarm_idol
	if swarm_level > 0:
		swarm_timer -= delta
		if swarm_timer <= 0.0:
			_release_swarm_eyes(swarm_level)


func _fire_chaos_bolt() -> void:
	var target := _nearest_enemy()
	var weapon_level: int = weapon_levels.chaos_bolt
	var evolved := bool(evolved_weapons.chaos_bolt)
	bolt_timer = maxf(0.12 if evolved else 0.16, (0.48 if evolved else 0.68 - weapon_level * 0.045) * effective_cooldown_multiplier())
	if not target:
		return
	_notify_weapon_fired("chaos_bolt")
	var count := ((3 + int(weapon_level / 4.0)) if evolved else (1 + int((weapon_level - 1) / 3.0))) + projectile_bonus
	var base_direction := (target.global_position - global_position).normalized()
	for index in range(count):
		var offset := float(index) - float(count - 1) * 0.5
		_spawn_player_projectile(
			base_direction.rotated(offset * (0.09 if evolved else 0.12)),
			(14.0 + weapon_level * 4.2) * effective_damage_multiplier() * (2.05 if evolved else 1.0),
			760.0 if evolved else 650.0, 8 if evolved else int(weapon_level / 3.0),
			14.0 if evolved else 8.0 + weapon_level * 0.7, Color("ffd36b") if evolved else Color("a96cff"), "chaos_bolt"
		)


func _fire_shadow_blades(weapon_level: int) -> void:
	var target := _nearest_enemy()
	var evolved := bool(evolved_weapons.shadow_blades)
	blades_timer = maxf(0.36 if evolved else 0.45, (0.78 if evolved else 2.0 - weapon_level * 0.16) * effective_cooldown_multiplier())
	if not target:
		return
	_notify_weapon_fired("shadow_blades")
	var count := (16 if evolved else 2 + weapon_level) + projectile_bonus
	var base_direction := (target.global_position - global_position).normalized()
	for index in range(count):
		var direction := Vector2.RIGHT.rotated(TAU * index / count) if evolved else base_direction.rotated((float(index) - float(count - 1) * 0.5) * 0.13)
		_spawn_player_projectile(
			direction, (10.0 + weapon_level * 3.0) * effective_damage_multiplier() * (1.62 if evolved else 1.0),
			820.0 if evolved else 760.0, 3 if evolved else 1, 8.0 if evolved else 6.0,
			Color("df63ff") if evolved else Color("ff557d"), "shadow_blades"
		)


func _spawn_player_projectile(
	direction: Vector2, amount: float, projectile_speed: float,
	pierce: int, size: float, color: Color, weapon_id := "unknown", force_critical := false
) -> void:
	if not bullet_scene:
		return
	attack_direction = direction
	attack_recoil = 1.0
	attack_flash = 1.0
	queue_redraw()
	var bullet = bullet_scene.instantiate()
	var is_critical := force_critical or randf() < effective_crit_chance()
	if is_critical:
		amount *= critical_multiplier
	bullet.global_position = global_position + direction * 22.0
	bullet.setup(direction, amount, projectile_speed, pierce, size, color, is_critical, weapon_id)
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.add_player_projectile(bullet)
	else:
		bullet.queue_free()


func _damage_orbit(weapon_level: int) -> void:
	orbit_tick = 0.10
	var evolved := bool(evolved_weapons.soul_orbit)
	var radius := 122.0 + weapon_level * 8.0 if evolved else 72.0 + weapon_level * 8.0
	var blade_count := 6 + int(weapon_level / 2.0) if evolved else 2 + int(weapon_level / 2.0)
	var now := Time.get_ticks_msec()
	var sound_played := false
	for enemy in _enemies_near(radius + 60.0):
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
				if not sound_played:
					_notify_weapon_fired("soul_orbit")
					sound_played = true
				orbit_hit_times[enemy_id] = now
				attack_recoil = 1.0
				var is_critical := randf() < effective_crit_chance()
				var amount := (8.0 + weapon_level * 3.0) * effective_damage_multiplier() * (1.85 if evolved else 1.0) * (critical_multiplier if is_critical else 1.0)
				enemy.take_damage(amount, (enemy.global_position - global_position).normalized() * (18.0 if evolved else 8.0), is_critical, "soul_orbit")
				if evolved:
					heal(0.35, false)
				break


func _cast_nova(weapon_level: int) -> void:
	var evolved := bool(evolved_weapons.chaos_nova)
	var radius := 275.0 + weapon_level * 26.0 if evolved else 155.0 + weapon_level * 24.0
	nova_timer = maxf(1.35 if evolved else 2.4, (3.1 if evolved else 6.2 - weapon_level * 0.48) * effective_cooldown_multiplier())
	attack_direction = last_direction
	attack_recoil = 1.0
	attack_flash = 1.0
	queue_redraw()
	_notify_weapon_fired("chaos_nova")
	for enemy in _enemies_near(radius + 70.0):
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= radius + enemy.hit_radius:
			var force: Vector2 = (enemy.global_position - global_position).normalized() * (155.0 if evolved else 85.0)
			var is_critical := randf() < effective_crit_chance()
			var amount := (25.0 + weapon_level * 9.0) * effective_damage_multiplier() * (2.1 if evolved else 1.0) * (critical_multiplier if is_critical else 1.0)
			enemy.take_damage(amount, force, is_critical, "chaos_nova")
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.spawn_effect(global_position, Color("ffd36b") if evolved else Color("bd72ff"), radius, 0.72 if evolved else 0.55, true)
		if evolved:
			world.shake_camera(6.0, 0.24)


func _swing_blood_scythe(weapon_level: int) -> void:
	var evolved := bool(evolved_weapons.blood_scythe)
	scythe_timer = maxf(0.42, (1.55 - weapon_level * 0.10) * effective_cooldown_multiplier() * (0.72 if evolved else 1.0))
	var target := _nearest_enemy()
	var direction := (target.global_position - global_position).normalized() if target else last_direction
	var radius := 245.0 if evolved else 145.0 + weapon_level * 10.0
	var hits := 0
	_notify_weapon_fired("blood_scythe")
	for enemy in _enemies_near(radius + 70.0):
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() > radius + enemy.hit_radius:
			continue
		if not evolved and direction.dot(to_enemy.normalized()) < 0.08:
			continue
		var critical := randf() < effective_crit_chance()
		var amount := (22.0 + weapon_level * 6.0) * effective_damage_multiplier() * (1.85 if evolved else 1.0) * (critical_multiplier if critical else 1.0)
		enemy.take_damage(amount, to_enemy.normalized() * (72.0 if evolved else 38.0), critical, "blood_scythe")
		hits += 1
	if hits > 0:
		heal(minf(10.0 if evolved else 4.0, hits * (0.75 if evolved else 0.32)), false)
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.spawn_weapon_flash(global_position + direction * 50.0, 0, direction.angle() - 0.68, 0.42 if evolved else 0.30, 0.34, Color("ff6878"))
		world.spawn_effect(global_position, Color("ff405d"), radius, 0.24, false)
	attack_recoil = 1.0


func _cast_forbidden_grimoire(weapon_level: int) -> void:
	var target := _nearest_enemy()
	var evolved := bool(evolved_weapons.forbidden_grimoire)
	grimoire_timer = maxf(0.80, (3.25 - weapon_level * 0.24) * effective_cooldown_multiplier() * (0.72 if evolved else 1.0))
	if not target:
		return
	var center: Vector2 = target.global_position
	var radius := 205.0 if evolved else 92.0 + weapon_level * 11.0
	var world := get_tree().get_first_node_in_group("world")
	if not world:
		return
	_notify_weapon_fired("forbidden_grimoire")
	for enemy in world.get_enemies_near(center, radius + 65.0):
		if is_instance_valid(enemy) and center.distance_to(enemy.global_position) <= radius + enemy.hit_radius:
			var critical := randf() < effective_crit_chance()
			var amount := (28.0 + weapon_level * 7.5) * effective_damage_multiplier() * (1.82 if evolved else 1.0) * (critical_multiplier if critical else 1.0)
			enemy.take_damage(amount, (enemy.global_position - center).normalized() * 34.0, critical, "forbidden_grimoire")
	world.spawn_weapon_flash(center + Vector2(0, -18), 1, 0.0, 0.25 if evolved else 0.19, 0.52, Color("d28cff"))
	world.spawn_effect(center, Color("a34cff"), radius, 0.58, true)
	attack_recoil = 1.0


func _slam_rune_hammer(weapon_level: int) -> void:
	var target := _nearest_enemy()
	var evolved := bool(evolved_weapons.rune_hammer)
	hammer_timer = maxf(0.92, (3.6 - weapon_level * 0.23) * effective_cooldown_multiplier() * (0.74 if evolved else 1.0))
	if not target:
		return
	var direction := (target.global_position - global_position).normalized()
	var strike_position := global_position + direction * minf(235.0, global_position.distance_to(target.global_position))
	var radius := 230.0 if evolved else 105.0 + weapon_level * 12.0
	var world := get_tree().get_first_node_in_group("world")
	if not world:
		return
	_notify_weapon_fired("rune_hammer")
	for enemy in world.get_enemies_near(strike_position, radius + 65.0):
		if is_instance_valid(enemy) and strike_position.distance_to(enemy.global_position) <= radius + enemy.hit_radius:
			var amount := (38.0 + weapon_level * 9.0) * effective_damage_multiplier() * (2.0 if evolved else 1.0)
			enemy.take_damage(amount, (enemy.global_position - strike_position).normalized() * (185.0 if evolved else 105.0), false, "rune_hammer")
	world.spawn_weapon_flash(strike_position + Vector2(0, -42), 2, direction.angle() + 0.72, 0.30 if evolved else 0.23, 0.38, Color("ffd56c"))
	world.spawn_effect(strike_position, Color("ffd064"), radius, 0.50, true)
	world.shake_camera(7.0 if evolved else 4.0, 0.20)
	attack_recoil = 1.0


func _cast_storm_chain(weapon_level: int) -> void:
	var evolved := bool(evolved_weapons.storm_relic)
	storm_timer = maxf(0.32, (1.75 - weapon_level * 0.11) * effective_cooldown_multiplier() * (0.65 if evolved else 1.0))
	var candidates := _enemies_near(720.0)
	if candidates.is_empty():
		return
	_notify_weapon_fired("storm_relic")
	candidates.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	var count := mini(candidates.size(), 11 if evolved else 2 + weapon_level)
	var points := PackedVector2Array([global_position])
	for enemy in candidates.slice(0, count):
		if not is_instance_valid(enemy):
			continue
		var critical := randf() < effective_crit_chance()
		var amount := (15.0 + weapon_level * 4.0) * effective_damage_multiplier() * (1.72 if evolved else 1.0) * (critical_multiplier if critical else 1.0)
		enemy.take_damage(amount, Vector2.ZERO, critical, "storm_relic")
		points.append(enemy.global_position)
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.spawn_weapon_flash(global_position + Vector2(25, -34), 3, -0.35, 0.17, 0.32, Color("7eefff"))
		world.spawn_lightning(points, Color("68eaff") if not evolved else Color("f5e57c"))
	attack_recoil = 1.0


func _release_swarm_eyes(weapon_level: int) -> void:
	var evolved := bool(evolved_weapons.swarm_idol)
	swarm_timer = maxf(0.55, (2.7 - weapon_level * 0.16) * effective_cooldown_multiplier() * (0.70 if evolved else 1.0))
	var candidates := _enemies_near(900.0)
	if candidates.is_empty():
		return
	var count := 2 + int(weapon_level / 2.0) + (3 if evolved else 0)
	var world := get_tree().get_first_node_in_group("world")
	if not world:
		return
	_notify_weapon_fired("swarm_idol")
	for index in range(count):
		var target: Node2D = candidates[index % candidates.size()]
		var critical := randf() < effective_crit_chance()
		var amount := (18.0 + weapon_level * 5.0) * effective_damage_multiplier() * (1.68 if evolved else 1.0) * (critical_multiplier if critical else 1.0)
		var eye = HomingEyeScript.new()
		eye.setup(global_position + Vector2.RIGHT.rotated(TAU * index / count) * 28.0, target, amount, 430.0 if evolved else 350.0, critical)
		world.add_player_projectile(eye)
	world.spawn_weapon_flash(global_position + Vector2(-24, -42), 4, 0.0, 0.16, 0.42, Color("d592ff"))
	attack_recoil = 1.0


func _notify_weapon_fired(weapon_id: String) -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("on_weapon_fired"):
		world.on_weapon_fired(weapon_id)


func _nearest_enemy() -> Node2D:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_nearest_enemy"):
		return world.get_nearest_enemy(global_position)
	return null


func _enemies_near(radius: float) -> Array[Node]:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_enemies_near"):
		return world.get_enemies_near(global_position, radius)
	var fallback: Array[Node] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= radius:
			fallback.append(enemy)
	return fallback


func take_damage(amount: float, source_direction := Vector2.ZERO, environmental := false) -> void:
	if disabled or (invulnerability > 0.0 and not environmental):
		return
	if not environmental and randf() < dodge_chance:
		var dodge_world := get_tree().get_first_node_in_group("world")
		if dodge_world:
			dodge_world.spawn_damage_number(global_position, 0.0, false, false, "ESQUIVA")
		return
	var guard_armor := 8.0 if character_guard_time > 0.0 else 0.0
	var final_damage := maxf(1.0, amount - armor - temporary_armor - guard_armor)
	hp = maxf(0.0, hp - final_damage)
	invulnerability = 0.20 if environmental else 0.58
	hurt_recoil = 1.0
	if source_direction.length_squared() > 0.01:
		last_direction = -source_direction.normalized()
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.record_player_damage(final_damage)
		world.on_player_damaged()
	if hp <= 0.0:
		if revive_charges > 0:
			revive_charges -= 1
			hp = max_hp * 0.55
			invulnerability = 3.0
			if world:
				world.on_player_revived()
		else:
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
			world.spawn_damage_number(global_position, hp - old_hp, false, true)


func collect_xp(amount: int) -> void:
	experience += amount
	while experience >= experience_needed:
		experience -= experience_needed
		level += 1
		experience_needed = int(round(10.0 + pow(level, 1.34) * 5.2))
		level_up_requested.emit()


func get_upgrade_options(count: int, excluded_ids: Array[String] = []) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var fallback_pool: Array[Dictionary] = []
	for definition in GameDefs.upgrades():
		var upgrade_id := str(definition.id)
		if banished_upgrades.has(upgrade_id):
			continue
		if weapon_levels.has(upgrade_id) and int(weapon_levels[upgrade_id]) <= 0 and active_weapon_count() >= MAX_WEAPONS:
			continue
		if get_upgrade_level(definition.id) < int(definition.max):
			var candidate := definition.duplicate()
			if upgrade_id in excluded_ids:
				fallback_pool.append(candidate)
			else:
				pool.append(candidate)
	if pool.size() < count:
		fallback_pool.shuffle()
		pool.append_array(fallback_pool.slice(0, count - pool.size()))
	pool.shuffle()
	var options: Array[Dictionary] = []
	for definition in pool.slice(0, mini(count, pool.size())):
		var upgrade_id := str(definition.id)
		var current := get_upgrade_level(upgrade_id)
		var rarity := _roll_rarity()
		var levels_gained := 2 if rarity == "LENDÁRIO" else 1
		definition["current_level"] = current
		definition["level"] = mini(int(definition.max), current + levels_gained)
		definition["levels_gained"] = mini(levels_gained, int(definition.max) - current)
		definition["rarity"] = rarity
		definition["category"] = "NOVA ARMA" if weapon_levels.has(upgrade_id) and current == 0 else ("ARMA" if weapon_levels.has(upgrade_id) else "PASSIVO")
		definition["evolution_hint"] = _evolution_hint_for(upgrade_id)
		options.append(definition)
	return options


func _evolution_hint_for(upgrade_id: String) -> String:
	if weapon_levels.has(upgrade_id):
		var evolution := GameDefs.evolution_data(upgrade_id)
		if evolution.is_empty():
			return ""
		return "EVOLUI COM %s NV.%d" % [GameDefs.upgrade_title(str(evolution.passive)).to_upper(), int(evolution.passive_level)]
	var synergies: Array[String] = []
	for weapon_id in WEAPON_IDS:
		if int(weapon_levels.get(weapon_id, 0)) <= 0 or bool(evolved_weapons.get(weapon_id, false)):
			continue
		var evolution := GameDefs.evolution_data(weapon_id)
		if str(evolution.get("passive", "")) == upgrade_id:
			synergies.append(str(WEAPON_TITLES.get(weapon_id, weapon_id)).capitalize())
	if synergies.is_empty():
		return ""
	return "COMBINA COM %s" % ", ".join(synergies)


func active_weapon_count() -> int:
	var count := 0
	for weapon_id in WEAPON_IDS:
		if int(weapon_levels.get(weapon_id, 0)) > 0:
			count += 1
	return count


func banish_upgrade(upgrade_id: String) -> void:
	banished_upgrades[upgrade_id] = true


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
		if int(weapon_levels[upgrade_id]) <= 0 and active_weapon_count() >= MAX_WEAPONS:
			return
		weapon_levels[upgrade_id] = mini(_upgrade_max(upgrade_id), int(weapon_levels[upgrade_id]) + bonus)
		_check_weapon_evolutions()
		return
	var previous_level := int(passive_levels.get(upgrade_id, 0))
	var new_level := mini(_upgrade_max(upgrade_id), previous_level + bonus)
	var applied_levels := new_level - previous_level
	if applied_levels <= 0:
		return
	passive_levels[upgrade_id] = new_level
	var rare_upgrade := rarity == "RARO"
	match upgrade_id:
		"might":
			damage_multiplier *= 1.22 if rare_upgrade else pow(1.15, applied_levels)
		"haste":
			cooldown_multiplier *= 0.84 if rare_upgrade else pow(0.90, applied_levels)
		"vitality":
			var gain := 40.0 if rare_upgrade else 25.0 * applied_levels
			max_hp += gain
			heal(gain)
		"swiftness":
			move_speed *= 1.13 if rare_upgrade else pow(1.08, applied_levels)
		"magnet":
			pickup_radius *= 1.55 if rare_upgrade else pow(1.35, applied_levels)
		"armor":
			armor += 3.0 if rare_upgrade else 2.0 * applied_levels
		"regeneration":
			regeneration += 1.0 if rare_upgrade else 0.65 * applied_levels
		"critical":
			crit_chance += 0.11 if rare_upgrade else 0.07 * applied_levels
	_check_weapon_evolutions()


func _upgrade_max(upgrade_id: String) -> int:
	for definition in GameDefs.upgrades():
		if str(definition.id) == upgrade_id:
			return int(definition.max)
	return 8


func _check_weapon_evolutions() -> void:
	for weapon_id in WEAPON_IDS:
		if bool(evolved_weapons[weapon_id]):
			continue
		var evolution := GameDefs.evolution_data(weapon_id)
		if evolution.is_empty():
			continue
		if int(weapon_levels[weapon_id]) < int(evolution.weapon_level):
			continue
		if int(passive_levels.get(str(evolution.passive), 0)) < int(evolution.passive_level):
			continue
		evolved_weapons[weapon_id] = true
		var world := get_tree().get_first_node_in_group("world")
		if world:
			world.on_weapon_evolved(str(evolution.title))


func apply_meta_bonuses(meta: Dictionary) -> void:
	var power_level := int(meta.get("power", 0))
	var vitality_level := int(meta.get("vitality", 0))
	var speed_level := int(meta.get("speed", 0))
	var fortune_level := int(meta.get("fortune", 0))
	damage_multiplier *= 1.0 + power_level * 0.05
	max_hp += vitality_level * 10.0
	hp = max_hp
	move_speed *= 1.0 + speed_level * 0.03
	crit_chance += fortune_level * 0.015


func apply_landmark_blessing(kind: String, duration := 40.0) -> String:
	blessing_time = duration
	temporary_damage_multiplier = 1.0
	temporary_cooldown_multiplier = 1.0
	temporary_move_multiplier = 1.0
	temporary_pickup_multiplier = 1.0
	temporary_crit_bonus = 0.0
	temporary_armor = 0.0
	match kind:
		"altar":
			blessing_title = "FÚRIA RUBRA"
			temporary_damage_multiplier = 1.32
			heal(max_hp * 0.25)
		"obelisk":
			blessing_title = "FLUXO CRONAL"
			temporary_cooldown_multiplier = 0.72
			temporary_crit_bonus = 0.12
		"tree":
			blessing_title = "CHAMADO DAS ALMAS"
			temporary_move_multiplier = 1.24
			temporary_pickup_multiplier = 2.6
			heal(max_hp * 0.12)
		"portal":
			blessing_title = "PELE DO VAZIO"
			temporary_armor = 7.0
			temporary_move_multiplier = 1.12
		_:
			blessing_title = "BÊNÇÃO DO MAPA"
	return blessing_title


func effective_damage_multiplier() -> float:
	return damage_multiplier * temporary_damage_multiplier


func effective_cooldown_multiplier() -> float:
	return cooldown_multiplier * temporary_cooldown_multiplier


func effective_crit_chance() -> float:
	return crit_chance + temporary_crit_bonus


func effective_pickup_radius() -> float:
	return pickup_radius * temporary_pickup_multiplier


func dash_status() -> String:
	return "PRONTA" if dash_cooldown <= 0.0 else "%.1fs" % dash_cooldown


func apply_character(selected_id: String) -> void:
	if character_applied:
		return
	character_applied = true
	character_id = selected_id
	var definition := GameDefs.character_data(selected_id)
	character_color = definition.color
	character_skill_name = str(definition.get("skill", "HABILIDADE DO CAÇADOR"))
	sprite.modulate = character_color
	match character_id:
		"glacial_oracle":
			armor += 3.0
			cooldown_multiplier *= 0.90
		"crimson_knight":
			max_hp += 35.0
			life_steal += 0.004
		"void_automaton":
			damage_multiplier *= 1.18
			move_speed *= 1.08
			max_hp -= 15.0
		_:
			damage_multiplier *= 1.08
			crit_chance += 0.05
	hp = max_hp


func get_relic_options(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for definition in GameDefs.relics():
		if int(relic_levels.get(str(definition.id), 0)) < int(definition.max):
			var option := definition.duplicate()
			option["level"] = int(relic_levels.get(str(definition.id), 0)) + 1
			pool.append(option)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


func apply_relic(relic_id: String) -> void:
	var current := int(relic_levels.get(relic_id, 0))
	var maximum := 1
	for definition in GameDefs.relics():
		if str(definition.id) == relic_id:
			maximum = int(definition.max)
			break
	if current >= maximum:
		return
	relic_levels[relic_id] = current + 1
	match relic_id:
		"glass_cannon":
			damage_multiplier *= 1.30
			max_hp *= 0.88
			hp = minf(hp, max_hp)
		"blood_fang":
			life_steal += 0.0045
		"storm_crown":
			projectile_bonus += 1
			damage_multiplier *= 1.08
		"void_boots":
			move_speed *= 1.12
			dodge_chance += 0.06
		"magnet_core":
			pickup_radius *= 1.55
			move_speed *= 1.08
		"boss_hunter":
			boss_damage_multiplier *= 1.25
		"phoenix_feather":
			revive_charges += 1
		"chrono_shard":
			cooldown_multiplier *= 0.88
		"iron_heart":
			max_hp += 30.0
			armor += 2.0
			heal(30.0)
		"soul_lens":
			crit_chance += 0.10
			critical_multiplier += 0.20


func on_damage_dealt(amount: float, target_is_boss: bool) -> void:
	if life_steal <= 0.0 or amount <= 0.0:
		return
	var multiplier := 1.65 if target_is_boss else 1.0
	heal(minf(6.0, amount * life_steal * multiplier), false)


func all_weapons_evolved() -> bool:
	var owned_weapons := 0
	for weapon_id in WEAPON_IDS:
		if int(weapon_levels.get(weapon_id, 0)) <= 0:
			continue
		owned_weapons += 1
		if not bool(evolved_weapons.get(weapon_id, false)):
			return false
	return owned_weapons >= MAX_WEAPONS


func relic_summary() -> String:
	var names: Array[String] = []
	for definition in GameDefs.relics():
		var relic_level := int(relic_levels.get(str(definition.id), 0))
		if relic_level > 0:
			names.append("%s %d" % [str(definition.title).capitalize(), relic_level])
	return "Nenhuma" if names.is_empty() else ", ".join(names)


func grant_boss_reward(final_reward := false) -> void:
	damage_multiplier *= 1.08 if final_reward else 1.045
	max_hp += 12.0 if final_reward else 5.0
	heal(max_hp * (0.35 if final_reward else 0.18))


func weapon_summary() -> String:
	var names: Array[String] = []
	if weapon_levels.chaos_bolt > 0:
		names.append("BALISTA ✦" if evolved_weapons.chaos_bolt else "Besta %d" % weapon_levels.chaos_bolt)
	if weapon_levels.shadow_blades > 0:
		names.append("DANÇA ◆" if evolved_weapons.shadow_blades else "Lâmina %d" % weapon_levels.shadow_blades)
	if weapon_levels.soul_orbit > 0:
		names.append("DEVORADOR ◉" if evolved_weapons.soul_orbit else "Cetro %d" % weapon_levels.soul_orbit)
	if weapon_levels.chaos_nova > 0:
		names.append("COLAPSO ☼" if evolved_weapons.chaos_nova else "Cajado %d" % weapon_levels.chaos_nova)
	if weapon_levels.blood_scythe > 0:
		names.append("CEIFADORA ☾" if evolved_weapons.blood_scythe else "Foice %d" % weapon_levels.blood_scythe)
	if weapon_levels.forbidden_grimoire > 0:
		names.append("CÓDICE ▤" if evolved_weapons.forbidden_grimoire else "Grimório %d" % weapon_levels.forbidden_grimoire)
	if weapon_levels.rune_hammer > 0:
		names.append("CATACLISMO ◆" if evolved_weapons.rune_hammer else "Martelo %d" % weapon_levels.rune_hammer)
	if weapon_levels.storm_relic > 0:
		names.append("TEMPESTADE ϟ" if evolved_weapons.storm_relic else "Relíquia %d" % weapon_levels.storm_relic)
	if weapon_levels.swarm_idol > 0:
		names.append("LEGIÃO ◉" if evolved_weapons.swarm_idol else "Ídolo %d" % weapon_levels.swarm_idol)
	if names.size() <= 3:
		return "  ·  ".join(names)
	return "%s\n%s" % ["  ·  ".join(names.slice(0, 3)), "  ·  ".join(names.slice(3))]


func _draw() -> void:
	var orbit_level: int = weapon_levels.soul_orbit
	if orbit_level > 0:
		var evolved := bool(evolved_weapons.soul_orbit)
		var radius := 122.0 + orbit_level * 8.0 if evolved else 72.0 + orbit_level * 8.0
		var blade_count := 6 + int(orbit_level / 2.0) if evolved else 2 + int(orbit_level / 2.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.72, 0.28, 0.24) if evolved else Color(0.63, 0.30, 1.0, 0.18), 3.0 if evolved else 2.0)
		for index in range(blade_count):
			var position := Vector2.RIGHT.rotated(orbit_angle + TAU * index / blade_count) * radius
			draw_circle(position, 14.0, Color(0.53, 0.20, 0.95, 0.18))
			draw_colored_polygon(PackedVector2Array([
				position + Vector2(-3, -12), position + Vector2(5, 0), position + Vector2(-3, 12), position + Vector2(-8, 0)
			]), Color("ffd36b") if evolved else Color("d9b3ff"))
	if attack_flash > 0.0:
		var muzzle := attack_direction * 39.0 + Vector2(0.0, -9.0)
		var glow := Color(0.78, 0.38, 1.0, attack_flash * 0.34)
		draw_circle(muzzle, 19.0 * attack_flash, glow)
		draw_line(muzzle - attack_direction * 9.0, muzzle + attack_direction * 16.0, Color(0.94, 0.76, 1.0, attack_flash), 3.0)
