extends CharacterBody2D

@export var speed: float = 300.0
@export var bullet_scene: PackedScene

var last_direction := Vector2.RIGHT
var hp := 100
var max_hp := 100
var shoot_timer := 0.0
var shoot_interval := 0.5

@onready var anim = $AnimatedSprite2D

func _ready():
	anim.play("idle")

func _physics_process(delta):
	var direction = Vector2.ZERO
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if direction != Vector2.ZERO:
		last_direction = direction.normalized()

	velocity = direction.normalized() * speed
	move_and_slide()

	if direction != Vector2.ZERO:
		anim.play("walk")
	else:
		anim.play("idle")

	anim.flip_h = last_direction.x < 0

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_hp(hp, max_hp)

	shoot_timer -= delta
	if shoot_timer <= 0:
		shoot_timer = shoot_interval
		shoot_at_nearest_enemy()

func shoot_at_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var nearest = null
	var min_dist = INF
	for enemy in enemies:
		var d = global_position.distance_to(enemy.global_position)
		if d < min_dist:
			min_dist = d
			nearest = enemy

	if nearest == null:
		return

	var dir = (nearest.global_position - global_position).normalized()
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.init(dir)
	get_parent().add_child(bullet)

func take_damage(amount):
	hp -= amount
	if hp <= 0:
		hp = 0
		die()

func die():
	var world = get_tree().get_first_node_in_group("world")
	if world:
		world.show_game_over()
	queue_free()
