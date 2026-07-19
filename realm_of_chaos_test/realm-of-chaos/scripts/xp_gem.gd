extends Area2D

var value := 1
var pickup_kind := "xp"
var player: Node2D
var velocity := Vector2.ZERO
var age := 0.0
var attracted := false


func setup(amount: int, world_position: Vector2, kind := "xp") -> void:
	value = amount
	pickup_kind = kind
	global_position = world_position
	rotation = randf() * TAU
	queue_redraw()


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	age += delta
	if not is_instance_valid(player):
		return
	var distance := global_position.distance_to(player.global_position)
	var pickup_range: float = player.effective_pickup_radius() if player.has_method("effective_pickup_radius") else player.pickup_radius
	if distance <= pickup_range:
		attracted = true
	if attracted:
		var direction := (player.global_position - global_position).normalized()
		velocity = velocity.move_toward(direction * 720.0, 1050.0 * delta)
		global_position += velocity * delta
	if distance <= 24.0:
		if pickup_kind == "heal":
			player.heal(float(value))
		else:
			player.collect_xp(value)
		var world := get_tree().get_first_node_in_group("world")
		if world and (pickup_kind == "heal" or value >= 8):
			world.audio.play_pickup()
		queue_free()
	queue_redraw()


func _draw() -> void:
	var bob := sin(age * 5.0) * 2.0
	if pickup_kind == "heal":
		draw_circle(Vector2(0, bob), 10.0, Color("ff536b"))
		draw_rect(Rect2(-2.0, bob - 7.0, 4.0, 14.0), Color.WHITE)
		draw_rect(Rect2(-7.0, bob - 2.0, 14.0, 4.0), Color.WHITE)
		return
	var color := Color("63f2ff") if value < 8 else Color("d782ff")
	draw_circle(Vector2(0, bob), 13.0, Color(color, 0.12))
	var points := PackedVector2Array([
		Vector2(0, bob - 8), Vector2(6, bob), Vector2(0, bob + 8), Vector2(-6, bob)
	])
	draw_colored_polygon(points, color)
	draw_line(Vector2(0, bob - 5), Vector2(0, bob + 3), Color.WHITE, 2.0)
