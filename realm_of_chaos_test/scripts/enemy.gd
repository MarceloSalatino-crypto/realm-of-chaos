extends CharacterBody2D
@export var speed:float=95.0
@export var hp:int=3
@export var damage:int=5
var player:Node2D
func _ready()->void: player=get_tree().get_first_node_in_group("player")
func _physics_process(_delta:float)->void:
	if player:
		velocity=global_position.direction_to(player.global_position)*speed
		move_and_slide()
func hit(amount:int)->void:
	hp-=amount
	if hp<=0:
		var gem=preload("res://scenes/xp_gem.tscn").instantiate()
		get_tree().current_scene.add_child(gem); gem.global_position=global_position; queue_free()
func _on_hitbox_body_entered(body:Node)->void:
	if body.is_in_group("player") and body.has_method("take_damage"): body.take_damage(damage)
