extends CharacterBody2D

const GameDefs = preload("res://scripts/game_defs.gd")
const EnemyProjectileScene = preload("res://scenes/enemies/enemy_projectile.tscn")
const ENEMY_ANIMATIONS := {
	"prowler": preload("res://assets/generated/enemy_anim_prowler.png"),
	"bat": preload("res://assets/generated/enemy_anim_bat.png"),
	"mage": preload("res://assets/generated/enemy_anim_mage.png"),
	"brute": preload("res://assets/generated/enemy_anim_brute.png"),
	"ember": preload("res://assets/generated/enemy_anim_ember.png"),
	"void_knight": preload("res://assets/generated/enemy_anim_void_knight.png")
}

var enemy_type := "prowler"
var power := 1.0
var elite := false
var boss := false
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
var knockback_velocity := Vector2.ZERO
var movement_age := 0.0
var animation_clock := 0.0
var base_visual_scale := 0.14
var attack_pulse := 0.0
var cast_pulse := 0.0
var hit_squash := 0.0
var dead := false

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
	boss = bool(data.get("boss", false))
	max_hp = float(data.hp) * power
	move_speed = float(data.speed) * (1.0 + (power - 1.0) * 0.12)
	contact_damage = float(data.damage) * (1.0 + (power - 1.0) * 0.28)
	xp_value = maxi(1, int(round(float(data.xp) * sqrt(power))))
	hit_radius = float(data.radius)
	if elite and not boss:
		max_hp *= 3.2
		move_speed *= 1.08
		contact_damage *= 1.55
		xp_value *= 4
	hp = max_hp

	sprite.texture = ENEMY_ANIMATIONS[enemy_type]
	sprite.hframes = 4
	sprite.vframes = 1
	sprite.frame = 0
	base_visual_scale = float(data.visual_scale) * 0.72 * (1.13 if elite else 1.0)
	sprite.scale = Vector2.ONE * base_visual_scale
	sprite.modulate = Color("d8b7ff") if elite and not boss else Color.WHITE

	var circle := CircleShape2D.new()
	circle.radius = hit_radius
	collision_shape.shape = circle
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_bar.visible = elite or boss
	var style := StyleBoxFlat.new()
	style.bg_color = data.color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	health_bar.add_theme_stylebox_override("fill", style)
	cast_cooldown = randf_range(0.8, 2.2)


func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	movement_age += delta
	damage_cooldown -= delta
	cast_cooldown -= delta
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized()

	if enemy_type == "mage":
		if distance > 285.0:
			velocity = direction * move_speed
		elif distance < 190.0:
			velocity = -direction * move_speed
		else:
			velocity = direction.rotated(PI * 0.5) * move_speed * sin(movement_age * 1.7)
	elif enemy_type == "bat":
		velocity = direction.rotated(sin(movement_age * 5.5) * 0.28) * move_speed
	else:
		velocity = direction * move_speed

	velocity += knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 720.0 * delta)
	move_and_slide()
	sprite.flip_h = velocity.x < -2.0

	if bool(GameDefs.enemy_data(enemy_type).get("ranged", false)) and cast_cooldown <= 0.0:
		_cast_projectile(direction)
	if distance <= hit_radius + 22.0 and damage_cooldown <= 0.0:
		attack_pulse = 1.0
		player.take_damage(contact_damage, direction)
		damage_cooldown = 1.0 if not boss else 0.75

	_animate_sprite(delta)
	if distance > 1450.0 and world:
		global_position = world.get_spawn_position(690.0, 820.0)


func _animate_sprite(delta: float) -> void:
	attack_pulse = move_toward(attack_pulse, 0.0, delta * 2.7)
	cast_pulse = move_toward(cast_pulse, 0.0, delta * 2.4)
	hit_squash = move_toward(hit_squash, 0.0, delta * 7.5)
	var active_attack := maxf(attack_pulse, cast_pulse)
	if active_attack > 0.0:
		sprite.frame = 2 if active_attack > 0.48 else 3
	else:
		animation_clock += delta * _locomotion_fps()
		sprite.frame = int(floor(animation_clock)) % 2

	var lift := 0.0
	var target_rotation := 0.0
	match enemy_type:
		"bat":
			lift = sin(movement_age * 5.2) * 3.5
			target_rotation = sin(movement_age * 5.2) * 0.025
		"mage":
			lift = sin(movement_age * 2.35) * 4.0
		"ember":
			lift = sin(movement_age * 3.0) * 5.5
			target_rotation = sin(movement_age * 2.1) * 0.035
		"void_knight":
			lift = sin(movement_age * 1.75) * 1.2
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
	if elite or boss or enemy_type == "ember":
		queue_redraw()


func _locomotion_fps() -> float:
	match enemy_type:
		"bat":
			return 8.5
		"mage", "ember":
			return 3.8
		"brute", "void_knight":
			return 4.2
		_:
			return 6.5


func _cast_projectile(direction: Vector2) -> void:
	cast_pulse = 1.0
	cast_cooldown = 2.8 if enemy_type == "mage" else 1.55
	var count := 1 if not boss else 5
	for index in range(count):
		var projectile = EnemyProjectileScene.instantiate()
		var offset := float(index) - float(count - 1) * 0.5
		var shot_direction := direction.rotated(offset * 0.17)
		projectile.global_position = global_position + shot_direction * (hit_radius + 8.0)
		var color := Color("63c7ff") if enemy_type == "mage" else Color("b05cff")
		projectile.setup(shot_direction, contact_damage * 0.7, 235.0 if not boss else 275.0, color, 8.0 if not boss else 11.0)
		if world:
			world.add_enemy_projectile(projectile)
		else:
			get_tree().current_scene.add_child(projectile)


func take_damage(amount: float, force := Vector2.ZERO, critical := false) -> void:
	if dead:
		return
	hp -= amount
	knockback_velocity += force
	hit_squash = 1.0
	health_bar.value = hp
	health_bar.visible = true
	var flash_color := Color("fff2a8") if critical else Color.WHITE
	sprite.modulate = flash_color * 1.8
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color("d8b7ff") if elite and not boss else Color.WHITE, 0.12)
	if world:
		world.spawn_effect(global_position, GameDefs.enemy_data(enemy_type).color, hit_radius * 1.3, 0.16)
	if hp <= 0.0:
		_die()


func _die() -> void:
	if dead:
		return
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
	if enemy_type == "ember":
		var ember_alpha := 0.10 + (sin(movement_age * 3.2) + 1.0) * 0.035
		draw_circle(Vector2(0.0, -12.0), hit_radius * 1.30, Color(1.0, 0.25, 0.16, ember_alpha))
	if elite and not boss:
		draw_arc(Vector2(0.0, 1.0), hit_radius * 1.35, 0.0, TAU, 30, Color(0.76, 0.45, 1.0, 0.30), 2.0)
	if boss:
		var aura_radius := hit_radius * (1.40 + sin(movement_age * 1.75) * 0.06)
		draw_circle(Vector2(0.0, -5.0), aura_radius, Color(0.52, 0.12, 0.82, 0.09))
		draw_arc(Vector2(0.0, -5.0), aura_radius, movement_age * 0.55, movement_age * 0.55 + PI * 1.45, 48, Color(0.78, 0.44, 1.0, 0.42), 3.0)
