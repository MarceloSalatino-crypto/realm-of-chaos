extends CharacterBody2D

#region Dependências e estado

const EnemyAbilitiesScript = preload("res://scripts/enemies/enemy_abilities.gd")
const EnemyMotionScript = preload("res://scripts/enemies/enemy_motion.gd")
const EnemyVisualControllerScript = preload("res://scripts/enemies/enemy_visual_controller.gd")
const PROJECTILE_PREPARE_DURATION := 0.20
const PROJECTILE_RELEASE_DURATION := 0.12
const ATTACK_FACING_DEADZONE := 0.12
const CONTACT_ATTACK_VISUAL_DURATION := 0.18

var enemy_type := "prowler"
var behavior := "hunter"
var power := 1.0
var elite := false
var boss := false
var mini_boss := false
var final_boss := false
var boss_phase := 1
var hp := 30.0
var max_hp := 30.0
var move_speed := 90.0
var contact_damage := 10.0
var xp_value := 3
var hit_radius := 21.0
var world: Node
var player: Node2D
var damage_cooldown := 0.0
var cast_cooldown := 2.0
var special_cooldown := 2.5
var knockback_velocity := Vector2.ZERO
var dash_velocity := Vector2.ZERO
var movement_age := 0.0
var animation_clock := 0.0
var base_visual_scale := 0.14
var base_modulate := Color.WHITE
var attack_pulse := 0.0
var cast_pulse := 0.0
var hit_squash := 0.0
var hit_freeze := 0.0
var telegraph_time := 0.0
var telegraph_duration := 0.0
var pending_special := ""
var pending_projectile_attack := ""
var projectile_prepare_time := 0.0
var projectile_release_time := 0.0
var projectile_attack_direction := Vector2.RIGHT
var projectile_attack_count := 0
var projectile_attack_damage := 0.0
var projectile_attack_speed := 0.0
var projectile_attack_size := 0.0
var projectile_radial_phase := 0.0
var attack_facing_direction := Vector2.RIGHT
var contact_attack_visual_time := 0.0
var contact_attack_visual_direction := Vector2.RIGHT
var explosion_done := false
var dead := false
var separation_timer := 0.0
var separation_force := Vector2.ZERO
var obstacle_avoidance := Vector2.ZERO
var slow_multiplier := 1.0
var slow_time := 0.0
var boss_pattern_index := 0
var definition_color := Color.WHITE
var definition_speed := 90.0
var definition_animation := "prowler"
var definition_is_ranged := false
var visual_lod_elapsed := 0.0
var visual_lod_distance := 0.0
var abilities: RefCounted
var motion: EnemyMotionScript
var visual_controller: RefCounted

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Polygon2D = $Shadow
@onready var health_bar: ProgressBar = $HealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

#endregion

#region Ciclo de vida e orquestração própria


func setup(kind: String, difficulty_power := 1.0, is_elite := false, owner_world: Node = null) -> void:
	enemy_type = kind
	power = difficulty_power
	elite = is_elite
	world = owner_world


func _ready() -> void:
	abilities = EnemyAbilitiesScript.new(self)
	motion = EnemyMotionScript.new(self)
	visual_controller = EnemyVisualControllerScript.new(self)
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	movement_age = randf() * TAU
	animation_clock = randf() * 2.0
	_apply_definition()


func _apply_definition() -> void:
	var data: Dictionary = GameDefs.enemy_data(enemy_type)
	definition_color = Color(data.color)
	definition_speed = float(data.speed)
	definition_animation = str(data.get("animation", enemy_type))
	definition_is_ranged = bool(data.get("ranged", false))
	behavior = str(data.get("behavior", "hunter"))
	boss = bool(data.get("boss", false))
	mini_boss = bool(data.get("mini_boss", false))
	final_boss = bool(data.get("final_boss", false))
	max_hp = float(data.hp) * power
	move_speed = float(data.speed) * (1.0 + (power - 1.0) * (0.08 if boss else 0.12))
	contact_damage = float(data.damage) * (1.0 + (power - 1.0) * (0.18 if boss else 0.28))
	var xp_profile := GameDefs.enemy_xp_drop_profile(enemy_type)
	xp_value = maxi(1, int(round(float(xp_profile.value) * sqrt(power))))
	hit_radius = float(data.radius)
	if elite and not boss:
		max_hp *= 3.2
		move_speed *= 1.08
		contact_damage *= 1.55
		xp_value = maxi(1, int(round(xp_value * float(xp_profile.elite_value_multiplier))))
	hp = max_hp

	visual_controller.configure_sprite(data)
	var circle := CircleShape2D.new()
	circle.radius = hit_radius
	collision_shape.shape = circle
	visual_controller.configure_health_bar()
	cast_cooldown = randf_range(0.8, 2.2)
	special_cooldown = randf_range(1.8, 3.4)


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	if contact_attack_visual_time > 0.0:
		contact_attack_visual_time = maxf(0.0, contact_attack_visual_time - delta)
		queue_redraw()
	if hit_freeze > 0.0:
		hit_freeze -= delta
		velocity = Vector2.ZERO
		_update_visual_animation(delta * 0.25, 0.0)
		return

	movement_age += delta
	damage_cooldown -= delta
	cast_cooldown -= delta
	special_cooldown -= delta
	if not pending_projectile_attack.is_empty() or projectile_release_time > 0.0:
		_update_projectile_attack(delta)
	slow_time = maxf(0.0, slow_time - delta)
	if slow_time <= 0.0:
		slow_multiplier = 1.0
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized()
	_update_boss_phase()

	if telegraph_time > 0.0:
		telegraph_time -= delta
		velocity = direction * move_speed * 0.12
		if telegraph_time <= 0.0:
			_execute_special(direction)
	else:
		motion.prepare_velocity(direction, distance, delta)
		_try_begin_special(distance)

	var distance_moved: float = motion.integrate_motion(delta, direction)
	var contact_attack_ready := distance <= hit_radius + 22.0 and damage_cooldown <= 0.0 and telegraph_time <= 0.0
	if definition_is_ranged and not contact_attack_ready and cast_cooldown <= 0.0 and telegraph_time <= 0.0 and pending_projectile_attack.is_empty() and projectile_release_time <= 0.0 and not behavior in ["glacial", "sovereign"]:
		_cast_projectile(direction)
	if contact_attack_ready:
		attack_pulse = 1.0
		if definition_is_ranged:
			contact_attack_visual_time = CONTACT_ATTACK_VISUAL_DURATION
			contact_attack_visual_direction = direction if not direction.is_zero_approx() else Vector2.RIGHT
			queue_redraw()
		player.take_damage(contact_damage, direction)
		damage_cooldown = 1.0 if not boss else 0.72

	_update_visual_animation(delta, distance_moved)
	if distance > 1450.0 and world and not boss:
		motion.reposition_far()

#endregion

#region Fachada de movimento


func _update_movement(direction: Vector2, distance: float) -> void:
	motion.update_movement(direction, distance)


func _apply_separation(delta: float) -> void:
	if not world or boss or not world.has_method("get_enemies_near"):
		return
	motion.apply_separation(delta)


func _try_begin_special(distance: float) -> void:
	if special_cooldown > 0.0:
		return
	abilities.try_begin_special(distance)

#endregion

#region Fachada de habilidades


func _begin_special(special_id: String, duration: float) -> void:
	abilities.begin_special(special_id, duration)


func _execute_special(direction: Vector2) -> void:
	abilities.execute_special(direction)


func _execute_sovereign_pattern(direction: Vector2) -> void:
	abilities.execute_sovereign_pattern(direction)


func _ground_slam(radius: float, damage_scale: float) -> void:
	abilities.ground_slam(radius, damage_scale)


func _bomber_burst() -> void:
	abilities.bomber_burst()


func _summon_minions(count: int) -> void:
	abilities.summon_minions(count)


func _cast_guardian_ward() -> void:
	abilities.cast_guardian_ward()


func apply_slow(multiplier: float, duration: float) -> void:
	motion.apply_slow(multiplier, duration)


func _special_radius() -> float:
	return abilities.special_radius()


func _update_boss_phase() -> void:
	if not boss or max_hp <= 0.0:
		return
	abilities.update_boss_phase()

#endregion

#region Fachada visual


func _update_visual_animation(delta: float, distance_moved: float) -> void:
	visual_controller.update_visual_animation(delta, distance_moved)


func _animate_sprite(delta: float, distance_moved := -1.0, allow_custom_redraw := true) -> void:
	visual_controller.animate_sprite(delta, distance_moved, allow_custom_redraw)


func _locomotion_fps() -> float:
	return visual_controller.locomotion_fps()

#endregion

#region Fachada de projéteis inimigos


func _cast_projectile(direction: Vector2) -> void:
	abilities.cast_projectile(direction)


func _update_projectile_attack(delta: float) -> void:
	abilities.update_projectile_attack(delta)


func _spawn_radial_projectiles(count: int, projectile_speed: float, damage_scale: float) -> void:
	abilities.spawn_radial_projectiles(count, projectile_speed, damage_scale)


func _spawn_enemy_projectile(direction: Vector2, amount: float, projectile_speed: float, size: float) -> void:
	abilities.spawn_enemy_projectile(direction, amount, projectile_speed, size)

#endregion

#region Dano e morte próprios


func take_damage(amount: float, force := Vector2.ZERO, critical := false, source_id := "") -> void:
	if dead:
		return
	if boss and not source_id.is_empty() and is_instance_valid(player):
		amount *= float(player.boss_damage_multiplier)
	var actual_damage := minf(hp, amount)
	hp -= amount
	knockback_velocity += force * (0.34 if boss else 1.0)
	hit_squash = 1.0
	hit_freeze = 0.052 if critical else (0.026 if boss else 0.016)
	_update_health_visual(true)
	if world:
		world.on_enemy_hit(global_position + Vector2(0.0, -hit_radius), amount, critical, boss)
		world.spawn_effect(global_position, definition_color, hit_radius * 1.3, 0.16)
		if not source_id.is_empty():
			world.record_damage(source_id, actual_damage, boss)
	visual_controller.play_damage_flash(critical)
	if hp <= 0.0:
		_die()


func _update_health_visual(show_health := false) -> void:
	visual_controller.update_health_bar(show_health)


func _die() -> void:
	if dead:
		return
	if behavior == "bomber" and not explosion_done:
		explosion_done = true
		_ground_slam(112.0, 0.58)
	dead = true
	remove_from_group("enemies")
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)
	visual_controller.hide_health_bar()
	if world:
		world.handle_enemy_death(self, xp_value, elite, boss)
	visual_controller.play_death_animation()

#endregion

#region Desenho delegado


func _draw() -> void:
	if visual_controller:
		visual_controller.draw()

#endregion
