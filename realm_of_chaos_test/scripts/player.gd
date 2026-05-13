extends CharacterBody2D
@export var speed: float = 300.0
@export var max_hp: int = 100
var hp:int=max_hp
var xp:int=0
var level:int=1
var xp_to_next:int=5
@onready var game:=get_tree().current_scene
func _physics_process(_delta: float)->void:
	var dir:=Vector2.ZERO
	dir.x=Input.get_action_strength("move_right")-Input.get_action_strength("move_left")
	dir.y=Input.get_action_strength("move_down")-Input.get_action_strength("move_up")
	velocity=dir.normalized()*speed
	move_and_slide()
func take_damage(amount:int)->void:
	hp-=amount
	if hp<=0: get_tree().reload_current_scene()
func add_xp(amount:int)->void:
	xp+=amount
	if xp>=xp_to_next:
		xp-=xp_to_next; level+=1; xp_to_next+=4; speed+=12
