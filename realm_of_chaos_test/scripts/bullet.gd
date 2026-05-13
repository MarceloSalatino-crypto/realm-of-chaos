extends Area2D
@export var speed:float=520.0
@export var damage:int=1
var direction:=Vector2.RIGHT
func _physics_process(delta:float)->void: global_position+=direction*speed*delta
func _on_body_entered(body:Node)->void:
	if body.is_in_group("enemy") and body.has_method("hit"):
		body.hit(damage); queue_free()
func _on_timer_timeout()->void: queue_free()
