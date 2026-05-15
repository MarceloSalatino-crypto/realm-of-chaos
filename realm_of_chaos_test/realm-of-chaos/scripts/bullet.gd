extends Area2D

var speed = 400.0
var direction = Vector2.ZERO
var damage = 1

func init(dir: Vector2):
	direction = dir

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		queue_free()
