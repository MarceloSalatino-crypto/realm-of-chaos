extends CharacterBody2D

@export var speed: float = 300.0
var last_direction := Vector2.RIGHT

@onready var anim = $AnimatedSprite2D
@onready var sword_slash = $SwordSlash

func _ready():
	anim.play("idle")
	sword_slash.hide()
	var timer = Timer.new()
	timer.autostart = false
	timer.start(2.0)
	timer.timeout.connect(_on_attack_timer)
	add_child(timer)

func _on_attack_timer():
	var nearest = get_nearest_enemy()
	if nearest != null:
		_do_attack(nearest)

func get_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var nearest_dist = 200.0
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _physics_process(_delta):
	var direction = Vector2.ZERO
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	velocity = direction.normalized() * speed
	move_and_slide()
	if direction != Vector2.ZERO:
		anim.play("walk")
	else:
		anim.play("idle")
	if last_direction.x < 0:
		anim.flip_h = true
	else:
		anim.flip_h = false
	if direction != Vector2.ZERO:
		last_direction = direction.normalized()

func _do_attack(target):
	if last_direction.x < 0:
		sword_slash.position = Vector2(-55, 0)
	else:
		sword_slash.position = Vector2(55, 0)
	sword_slash.show()
	await get_tree().create_timer(0.1).timeout
	for body in sword_slash.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(1)
	await get_tree().create_timer(0.1).timeout
	sword_slash.hide()
