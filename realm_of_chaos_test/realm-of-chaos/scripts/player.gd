extends CharacterBody2D

@export var speed: float = 300.0

var last_direction: Vector2 = Vector2.RIGHT

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	anim.play("idle")

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO

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

	if last_direction.x < 0:
		anim.flip_h = true
	elif last_direction.x > 0:
		anim.flip_h = false
