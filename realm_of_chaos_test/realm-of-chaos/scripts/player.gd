extends CharacterBody2D

signal level_up_requested
signal died

const GameDefs = preload("res://scripts/game_defs.gd")
const WEAPON_IDS: Array[String] = ["chaos_bolt", "shadow_blades", "soul_orbit", "chaos_nova"]
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
	"chaos_nova": "CAJADO DA NOVA"
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
var relic_levels: Dictionary = {}
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
	"chaos_nova": 0
}
var passive_levels := {
	"might": 0, "haste": 0, "vitality": 0, "swiftness": 0,
	"magnet": 0, "armor": 0, "regeneration": 0, "critical": 0
}
var evolved_weapons := {
	"chaos_bolt": false,
	"shadow_blades": false,
	"soul_orbit": false,
	"chaos_nova": false
}
var bolt_timer := 0.15
var blades_timer := 1.0
var nova_timer := 4.0
var orbit_tick := 0.0
var orbit_angle := 0.0
var orbit_hit_times: Dictionary = {}

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


func _animate_character(delta: float, direction: Vector2, is_moving: bool) -> void:
	attack_recoil = move_toward(attack_recoil, 0.0, delta * 4.0)
	attack_flash = move_toward(attack_flash, 0.0, delta * 8.5)
	hurt_recoil = move_toward(hurt_recoil, 0.0, delta * 6.0)
	sprite.flip_h = last_direction.x < 0.0

	if attack_recoil > 0.0:
		var attack_progress := clampf(1.0 - attack_recoil, 0.0, 0.999)
		sprite.frame_coords = Vector2i(mini(3, int(attack_progress * 4.0)), 1)
	elif is_moving:
		walk_animation_clock += delta * 8.2
		sprite.frame_coords = Vector2i(int(floor(walk_animation_clock)) % 4, 0)
	else:
		walk_animation_clock = 0.0
		sprite.frame_coords = Vector2i.ZERO

	var breathe := sin(motion_age * 2.35)
	var stride := sin(motion_age * 8.2)
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


func _fire_chaos_bolt() -> void:
	var target := _nearest_enemy()
	var weapon_level: int = weapon_levels.chaos_bolt
	var evolved := bool(evolved_weapons.chaos_bolt)
	bolt_timer = maxf(0.12 if evolved else 0.16, (0.48 if evolved else 0.68 - weapon_level * 0.045) * effective_cooldown_multiplier())
	if not target:
		return
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
	pierce: int, size: float, color: Color, weapon_id := "unknown"
) -> void:
	if not bullet_scene:
		return
	attack_direction = direction
	attack_recoil = 1.0
	attack_flash = 1.0
	queue_redraw()
	var bullet = bullet_scene.instantiate()
	var is_critical := randf() < effective_crit_chance()
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
	var final_damage := maxf(1.0, amount - armor - temporary_armor)
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
		weapon_levels[upgrade_id] = mini(_upgrade_max(upgrade_id), int(weapon_levels[upgrade_id]) + bonus)
		_check_weapon_evolutions()
		return
	passive_levels[upgrade_id] = mini(_upgrade_max(upgrade_id), int(passive_levels.get(upgrade_id, 0)) + bonus)
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
	for weapon_id in WEAPON_IDS:
		if not bool(evolved_weapons.get(weapon_id, false)):
			return false
	return true


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
	return "  ·  ".join(names)


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
