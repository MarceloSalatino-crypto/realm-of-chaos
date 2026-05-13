extends CharacterBody2D

@export var speed: float = 300.0

var attacking := false
var last_direction := Vector2.RIGHT

@onready var anim = $AnimatedSprite2D
@onready var sword_slash = $SwordSlash

func _ready():
	anim.play("idle")
	sword_slash.hide()

func _physics_process(delta):

	var direction = Vector2.ZERO

	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if direction != Vector2.ZERO:
		last_direction = direction.normalized()

	if Input.is_action_just_pressed("ui_accept"):
		attack()

	if attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	velocity = direction.normalized() * speed

	move_and_slide()

	if direction != Vector2.ZERO:
		anim.play("walk")
	else:
		anim.play("idle")

	if last_direction.x < 0:
		anim.flip_h = true
		sword_slash.position = Vector2(-55, 0)
	elif last_direction.x > 0:
		anim.flip_h = false
		sword_slash.position = Vector2(55, 0)

func attack():

	if attacking:
		return

	attacking = true

	sword_slash.show()

	var start_pos = Vector2(35, -20)
	var end_pos = Vector2(70, 20)

	if last_direction.x < 0:
		start_pos = Vector2(-35, -20)
		end_pos = Vector2(-70, 20)

	sword_slash.position = start_pos
	sword_slash.rotation_degrees = -45

	var tween = create_tween()
	tween.tween_property(sword_slash, "position", end_pos, 0.12)
	tween.parallel().tween_property(sword_slash, "rotation_degrees", 45, 0.12)

	await tween.finished

	sword_slash.hide()
	sword_slash.rotation_degrees = 0

	await get_tree().create_timer(0.10).timeout

	attacking = false
