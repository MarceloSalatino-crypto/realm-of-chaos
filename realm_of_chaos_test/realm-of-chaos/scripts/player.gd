extends CharacterBody2D

@export var speed: float = 300.0

@onready var anim = $AnimatedSprite2D
@onready var sword_slash = $SwordSlash

func _ready():
	anim.play("idle")
	sword_slash.hide()

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
