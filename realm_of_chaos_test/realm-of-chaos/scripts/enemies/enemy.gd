extends CharacterBody2D

const GameDefs = preload("res://scripts/game_defs.gd")
const EnemyProjectileScene = preload("res://scenes/enemies/enemy_projectile.tscn")
const ENEMY_ANIMATIONS := {
	"prowler": preload("res://assets/generated/enemy_anim_prowler.png"),
	"bat": preload("res://assets/generated/enemy_anim_bat.png"),
	"mage": preload("res://assets/generated/enemy_anim_mage.png"),
	"brute": preload("res://assets/generated/enemy_anim_brute.png"),
	"ember": preload("res://assets/generated/enemy_anim_ember.png"),
	"void_knight": preload("res://assets/generated/enemy_anim_void_knight.png"),
	"ossuary_colossus": preload("res://assets/generated/boss_ossuary_colossus.png"),
	"glacial_archon": preload("res://assets/generated/boss_glacial_archon.png"),
	"infernal_reaper": preload("res://assets/generated/boss_infernal_reaper.png"),
	"void_titan": preload("res://assets/generated/boss_void_titan.png"),
	"chaos_sovereign": preload("res://assets/generated/boss_chaos_sovereign.png")
}

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
var explosion_done := false
var dead := false
var separation_timer := 0.0
var separation_force := Vector2.ZERO
var obstacle_avoidance := Vector2.ZERO
var slow_multiplier := 1.0
var slow_time := 0.0
var boss_pattern_index := 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Polygon2D = $Shadow
@onready var health_bar: ProgressBar = $HealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func setup(kind: String, difficulty_power := 1.0, is_elite := false, owner_world: Node = null) -> void:
	enemy_type = kind
	power = difficulty_power
	elite = is_elite
	world = owner_world


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemies")
	movement_age = randf() * TAU
	animation_clock = randf() * 2.0
	_apply_definition()


func _apply_definition() -> void:
	var data: Dictionary = GameDefs.enemy_data(enemy_type)
	behavior = str(data.get("behavior", "hunter"))
	boss = bool(data.get("boss", false))
	mini_boss = bool(data.get("mini_boss", false))
	final_boss = bool(data.get("final_boss", false))
	max_hp = float(data.hp) * power
	move_speed = float(data.speed) * (1.0 + (power - 1.0) * (0.08 if boss else 0.12))
	contact_damage = float(data.damage) * (1.0 + (power - 1.0) * (0.18 if boss else 0.28))
	xp_value = maxi(1, int(round(float(data.xp) * sqrt(power))))
	hit_radius = float(data.radius)
	if elite and not boss:
		max_hp *= 3.2
		move_speed *= 1.08
		contact_damage *= 1.55
		xp_value *= 4
	hp = max_hp

	var animation_id := str(data.get("animation", enemy_type))
	sprite.texture = ENEMY_ANIMATIONS.get(animation_id, ENEMY_ANIMATIONS.prowler)
	sprite.hframes = 4
	sprite.vframes = 1
	sprite.frame = 0
	base_visual_scale = float(data.visual_scale) * (1.0 if boss else 0.72) * (1.13 if elite else 1.0)
	sprite.scale = Vector2.ONE * base_visual_scale
	base_modulate = Color("d8b7ff") if elite and not boss else Color.WHITE
	if enemy_type != animation_id and not boss:
		base_modulate = base_modulate.lerp(Color(data.color), 0.26)
	sprite.modulate = base_modulate

	var circle := CircleShape2D.new()
	circle.radius = hit_radius
	collision_shape.shape = circle
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_bar.visible = elite or boss
	if boss:
		health_bar.offset_left = -hit_radius
		health_bar.offset_right = hit_radius
		health_bar.offset_top = -hit_radius - 58.0
		health_bar.offset_bottom = health_bar.offset_top + 8.0
	var style := StyleBoxFlat.new()
	style.bg_color = data.color
	style.set_corner_radius_all(3)
	health_bar.add_theme_stylebox_override("fill", style)
	cast_cooldown = randf_range(0.8, 2.2)
	special_cooldown = randf_range(1.8, 3.4)


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	if hit_freeze > 0.0:
		hit_freeze -= delta
		velocity = Vector2.ZERO
		_animate_sprite(delta * 0.25)
		return

	movement_age += delta
	damage_cooldown -= delta
	cast_cooldown -= delta
	special_cooldown -= delta
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
		_update_movement(direction, distance)
		_apply_separation(delta)
		_try_begin_special(distance)

	velocity += knockback_velocity + dash_velocity + obstacle_avoidance
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 720.0 * delta)
	dash_velocity = dash_velocity.move_toward(Vector2.ZERO, 980.0 * delta)
	obstacle_avoidance = obstacle_avoidance.move_toward(Vector2.ZERO, 420.0 * delta)
	var event_speed := float(world.enemy_speed_multiplier) if world else 1.0
	velocity *= event_speed * slow_multiplier
	move_and_slide()
	if get_slide_collision_count() > 0 and dash_velocity.length_squared() < 10.0:
		var collision := get_slide_collision(0)
		var tangent := collision.get_normal().rotated(PI * 0.5)
		if tangent.dot(direction) < 0.0:
			tangent = -tangent
		obstacle_avoidance = tangent * move_speed * 0.62
	sprite.flip_h = velocity.x < -2.0

	var ranged := bool(GameDefs.enemy_data(enemy_type).get("ranged", false))
	if ranged and cast_cooldown <= 0.0 and telegraph_time <= 0.0 and not behavior in ["glacial", "sovereign"]:
		_cast_projectile(direction)
	if distance <= hit_radius + 22.0 and damage_cooldown <= 0.0 and telegraph_time <= 0.0:
		attack_pulse = 1.0
		player.take_damage(contact_damage, direction)
		damage_cooldown = 1.0 if not boss else 0.72

	_animate_sprite(delta)
	if distance > 1450.0 and world and not boss:
		global_position = world.get_spawn_position(690.0, 820.0)


func _update_movement(direction: Vector2, distance: float) -> void:
	match behavior:
		"ranged", "archer", "necromancer", "glacial":
			var desired_min := 220.0 if behavior == "archer" else 185.0
			var desired_max := 340.0 if behavior == "archer" else 285.0
			if distance > desired_max:
				velocity = direction * move_speed
			elif distance < desired_min:
				velocity = -direction * move_speed
			else:
				velocity = direction.rotated(PI * 0.5) * move_speed * sin(movement_age * 1.7)
		"swarm_flight":
			velocity = direction.rotated(sin(movement_age * 5.5) * 0.28) * move_speed
		"assassin":
			velocity = direction.rotated(sin(movement_age * 3.2) * 0.12) * move_speed
		"sovereign":
			velocity = direction.rotated(sin(movement_age * 1.5) * 0.15) * move_speed
		_:
			velocity = direction * move_speed


func _apply_separation(delta: float) -> void:
	if not world or boss or not world.has_method("get_enemies_near"):
		return
	separation_timer -= delta
	if separation_timer > 0.0:
		velocity += separation_force
		return
	separation_timer = 0.10 + fmod(float(get_instance_id()), 7.0) * 0.006
	var separation := Vector2.ZERO
	var checked := 0
	for neighbor in world.get_enemies_near(global_position, hit_radius * 2.4 + 16.0):
		if neighbor == self or not is_instance_valid(neighbor):
			continue
		var away: Vector2 = global_position - neighbor.global_position
		var distance_squared := maxf(away.length_squared(), 16.0)
		separation += away.normalized() / sqrt(distance_squared)
		checked += 1
		if checked >= 8:
			break
	if separation.length_squared() > 0.0001:
		separation_force = separation.normalized() * move_speed * minf(0.52, checked * 0.08)
	else:
		separation_force = Vector2.ZERO
	velocity += separation_force


func _try_begin_special(distance: float) -> void:
	if special_cooldown > 0.0:
		return
	match behavior:
		"bomber":
			if distance <= 105.0:
				_begin_special("explode", 0.62)
		"assassin":
			_begin_special("dash", 0.42)
		"necromancer":
			_begin_special("summon", 0.82)
		"guardian":
			_begin_special("ward", 0.66)
		"ossuary":
			_begin_special("slam", 0.82)
		"glacial":
			_begin_special("radial", 0.78)
		"reaper":
			_begin_special("reaper_dash", 0.52)
		"titan":
			_begin_special("titan_slam", 0.92)
		"sovereign":
			_begin_special("sovereign", 0.68)
		_:
			special_cooldown = 3.0


func _begin_special(special_id: String, duration: float) -> void:
	pending_special = special_id
	telegraph_time = duration
	telegraph_duration = duration
	attack_pulse = 1.0
	velocity *= 0.2
	queue_redraw()
	if world:
		var radius := _special_radius()
		world.spawn_effect(global_position, GameDefs.enemy_data(enemy_type).color, radius, duration, false)


func _execute_special(direction: Vector2) -> void:
	var executed := pending_special
	pending_special = ""
	attack_pulse = 0.46
	match executed:
		"explode":
			_bomber_burst()
		"dash":
			dash_velocity = direction * 560.0
			special_cooldown = 3.0
		"summon":
			_summon_minions(3 + boss_phase)
			special_cooldown = 6.5
		"ward":
			_cast_guardian_ward()
			special_cooldown = 5.4
		"slam":
			_ground_slam(165.0, 0.82)
			if boss_phase >= 2:
				_spawn_radial_projectiles(5 + boss_phase * 2, 220.0, 0.45)
			if boss_phase >= 3:
				_summon_minions(2)
			special_cooldown = maxf(1.6, 3.8 - boss_phase * 0.45)
		"radial":
			_spawn_radial_projectiles(9 + boss_phase * 3, 235.0 + boss_phase * 18.0, 0.62)
			if boss_phase >= 2:
				_ground_slam(145.0 + boss_phase * 18.0, 0.52)
			special_cooldown = maxf(1.5, 3.5 - boss_phase * 0.42)
		"reaper_dash":
			dash_velocity = direction * (690.0 + boss_phase * 80.0)
			_spawn_radial_projectiles(5 + boss_phase * 2, 285.0, 0.48)
			if boss_phase >= 3:
				_summon_minions(3)
			special_cooldown = maxf(1.25, 3.0 - boss_phase * 0.42)
		"titan_slam":
			_ground_slam(225.0 + boss_phase * 18.0, 1.0)
			_spawn_radial_projectiles(8 + boss_phase * 2, 210.0, 0.55)
			if boss_phase >= 2:
				_cast_guardian_ward()
			if boss_phase >= 3:
				_summon_minions(4)
			special_cooldown = maxf(1.7, 4.0 - boss_phase * 0.5)
		"sovereign":
			_execute_sovereign_pattern(direction)
			special_cooldown = maxf(1.0, 2.8 - boss_phase * 0.48)
	queue_redraw()


func _execute_sovereign_pattern(direction: Vector2) -> void:
	boss_pattern_index += 1
	if boss_phase == 1:
		if boss_pattern_index % 2 == 0:
			_spawn_radial_projectiles(14, 275.0, 0.58)
		else:
			dash_velocity = direction * 620.0
			_ground_slam(155.0, 0.48)
	elif boss_phase == 2:
		if boss_pattern_index % 2 == 0:
			_spawn_radial_projectiles(18, 305.0, 0.62)
			_summon_minions(4)
		else:
			dash_velocity = direction * 690.0
			_ground_slam(215.0, 0.62)
	else:
		dash_velocity = direction * 760.0
		_spawn_radial_projectiles(24, 340.0, 0.68)
		_ground_slam(250.0, 0.72)


func _ground_slam(radius: float, damage_scale: float) -> void:
	if global_position.distance_to(player.global_position) <= radius + 20.0:
		player.take_damage(contact_damage * damage_scale, (player.global_position - global_position).normalized())
	if world:
		world.spawn_effect(global_position, GameDefs.enemy_data(enemy_type).color, radius, 0.48, true)
		world.audio.play_explosion()
		world.shake_camera(8.0 if boss else 4.0, 0.24)


func _bomber_burst() -> void:
	if explosion_done:
		return
	explosion_done = true
	_ground_slam(128.0, 0.86)
	hp = 0.0
	_die()


func _summon_minions(count: int) -> void:
	if not world:
		return
	for index in range(count):
		var kind := "swarm" if index % 3 == 0 else "prowler"
		var minion = world.spawn_enemy(kind, false)
		if minion:
			minion.global_position = global_position + Vector2.RIGHT.rotated(TAU * index / count) * randf_range(54.0, 92.0)
	world.spawn_effect(global_position, Color("9d72ff"), 115.0, 0.5, true)


func _cast_guardian_ward() -> void:
	if not world:
		return
	for ally in world.get_enemies_near(global_position, 190.0):
		if ally == self:
			continue
		ally.hp = minf(ally.max_hp, ally.hp + ally.max_hp * 0.09)
		ally.health_bar.value = ally.hp
	world.spawn_effect(global_position, Color("e0b779"), 190.0, 0.55, false)


func apply_slow(multiplier: float, duration: float) -> void:
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.35, 1.0))
	slow_time = maxf(slow_time, duration * (0.45 if boss else 1.0))
	if world:
		world.spawn_effect(global_position, Color("69dcff"), hit_radius * 1.4, 0.28)


func _special_radius() -> float:
	match pending_special:
		"explode": return 128.0
		"slam": return 165.0
		"titan_slam": return 225.0 + boss_phase * 18.0
		"ward": return 190.0
		"sovereign": return 250.0
		_: return hit_radius * 2.4


func _update_boss_phase() -> void:
	if not boss or max_hp <= 0.0:
		return
	var ratio := hp / max_hp
	var new_phase := 3 if ratio <= 0.34 else (2 if ratio <= 0.67 else 1)
	if new_phase == boss_phase:
		return
	boss_phase = new_phase
	move_speed *= 1.13
	contact_damage *= 1.08
	special_cooldown = 0.35
	if world:
		world.on_boss_phase_changed(self, boss_phase)


func _animate_sprite(delta: float) -> void:
	attack_pulse = move_toward(attack_pulse, 0.0, delta * 2.7)
	cast_pulse = move_toward(cast_pulse, 0.0, delta * 2.4)
	hit_squash = move_toward(hit_squash, 0.0, delta * 7.5)
	var active_attack := maxf(attack_pulse, cast_pulse)
	if telegraph_time > 0.0:
		sprite.frame = 2
	elif active_attack > 0.0:
		sprite.frame = 2 if active_attack > 0.48 else 3
	else:
		animation_clock += delta * _locomotion_fps()
		sprite.frame = int(floor(animation_clock)) % 2

	var lift := 0.0
	var target_rotation := 0.0
	var animation_id := str(GameDefs.enemy_data(enemy_type).get("animation", enemy_type))
	match animation_id:
		"bat":
			lift = sin(movement_age * 5.2) * 3.5
			target_rotation = sin(movement_age * 5.2) * 0.025
		"mage", "glacial_archon":
			lift = sin(movement_age * 2.35) * 4.0
		"ember":
			lift = sin(movement_age * 3.0) * 5.5
			target_rotation = sin(movement_age * 2.1) * 0.035
		"chaos_sovereign":
			lift = sin(movement_age * 1.9) * 2.0
	var target_scale := Vector2.ONE * base_visual_scale
	if hit_squash > 0.0:
		target_scale *= Vector2(1.0 + hit_squash * 0.07, 1.0 - hit_squash * 0.06)
	var smoothing := 1.0 - exp(-delta * 14.0)
	sprite.scale = sprite.scale.lerp(target_scale, smoothing)
	sprite.position = sprite.position.lerp(Vector2(0.0, -16.0 + lift), smoothing)
	sprite.rotation = lerpf(sprite.rotation, target_rotation, smoothing)
	var altitude := absf(lift)
	shadow.scale = shadow.scale.lerp(Vector2(1.0 + altitude * 0.012, 1.0 - altitude * 0.018), 1.0 - exp(-delta * 9.0))
	shadow.color.a = lerpf(shadow.color.a, 0.48 - altitude * 0.016, smoothing)
	if elite or boss or behavior in ["ember", "bomber", "guardian"] or telegraph_time > 0.0:
		queue_redraw()


func _locomotion_fps() -> float:
	match behavior:
		"swarm_flight", "assassin", "reaper": return 8.5
		"ranged", "archer", "necromancer", "glacial": return 3.8
		"brute", "guardian", "ossuary", "titan", "sovereign": return 4.2
		_: return 6.5


func _cast_projectile(direction: Vector2) -> void:
	cast_pulse = 1.0
	cast_cooldown = 2.7 if behavior in ["ranged", "necromancer"] else 1.65
	var count := 3 if behavior == "archer" else 1
	for index in range(count):
		var offset := float(index) - float(count - 1) * 0.5
		_spawn_enemy_projectile(direction.rotated(offset * 0.13), contact_damage * 0.70, 245.0, 8.0)


func _spawn_radial_projectiles(count: int, projectile_speed: float, damage_scale: float) -> void:
	cast_pulse = 1.0
	for index in range(count):
		_spawn_enemy_projectile(Vector2.RIGHT.rotated(TAU * index / count + movement_age * 0.08), contact_damage * damage_scale, projectile_speed, 9.0 if not final_boss else 12.0)


func _spawn_enemy_projectile(direction: Vector2, amount: float, projectile_speed: float, size: float) -> void:
	var projectile = EnemyProjectileScene.instantiate()
	projectile.global_position = global_position + direction * (hit_radius + 8.0)
	var color: Color = GameDefs.enemy_data(enemy_type).color
	projectile.setup(direction, amount, projectile_speed, color, size)
	if world:
		world.add_enemy_projectile(projectile)
	else:
		get_tree().current_scene.add_child(projectile)


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
	health_bar.value = hp
	health_bar.visible = true
	if world:
		world.on_enemy_hit(global_position + Vector2(0.0, -hit_radius), amount, critical, boss)
		world.spawn_effect(global_position, GameDefs.enemy_data(enemy_type).color, hit_radius * 1.3, 0.16)
		if not source_id.is_empty():
			world.record_damage(source_id, actual_damage, boss)
	var flash_color := Color("fff2a8") if critical else Color.WHITE
	sprite.modulate = flash_color * 1.8
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", base_modulate, 0.12)
	if hp <= 0.0:
		_die()


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
	health_bar.hide()
	if world:
		world.handle_enemy_death(self, xp_value, elite, boss)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale", Vector2.ONE * base_visual_scale * 0.86, 0.26)
	tween.tween_property(sprite, "rotation", sprite.rotation + (0.18 if randf() > 0.5 else -0.18), 0.26)
	tween.tween_property(sprite, "modulate", Color(0.42, 0.16, 0.55, 0.0), 0.28)
	tween.tween_property(shadow, "scale", Vector2(1.25, 0.45), 0.28)
	tween.tween_property(shadow, "color", Color(0.01, 0.005, 0.02, 0.0), 0.28)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	if behavior in ["ember", "bomber"]:
		var ember_alpha := 0.10 + (sin(movement_age * 3.2) + 1.0) * 0.035
		draw_circle(Vector2(0.0, -12.0), hit_radius * 1.30, Color(1.0, 0.25, 0.16, ember_alpha))
	if behavior == "guardian":
		draw_arc(Vector2.ZERO, 190.0, 0.0, TAU, 48, Color(0.88, 0.70, 0.36, 0.16), 2.0)
	if telegraph_time > 0.0:
		var progress := 1.0 - clampf(telegraph_time / maxf(telegraph_duration, 0.01), 0.0, 1.0)
		var radius := _special_radius()
		draw_circle(Vector2.ZERO, radius, Color(0.95, 0.16, 0.20, 0.045 + progress * 0.055))
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, Color(1.0, 0.35, 0.30, 0.82), 4.0)
	if elite and not boss:
		draw_arc(Vector2(0.0, 1.0), hit_radius * 1.35, 0.0, TAU, 30, Color(0.76, 0.45, 1.0, 0.30), 2.0)
	if boss:
		var aura_radius := hit_radius * (1.40 + sin(movement_age * 1.75) * 0.06)
		draw_circle(Vector2(0.0, -5.0), aura_radius, Color(0.52, 0.12, 0.82, 0.09))
		draw_arc(Vector2(0.0, -5.0), aura_radius, movement_age * 0.55, movement_age * 0.55 + PI * 1.45, 48, Color(0.78, 0.44, 1.0, 0.42), 3.0)
