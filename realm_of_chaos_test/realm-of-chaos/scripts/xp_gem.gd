extends Area2D

const MEDIUM_VISUAL_LOAD := 160
const HIGH_VISUAL_LOAD := 360
const NORMAL_REDRAW_INTERVAL := 1.0 / 30.0
const MEDIUM_REDRAW_INTERVAL := 1.0 / 20.0
const HIGH_REDRAW_INTERVAL := 1.0 / 15.0
const VISUAL_LOAD_REFRESH_INTERVAL := 0.50

var value := 1
var pickup_kind := "xp"
var player: Node2D
var velocity := Vector2.ZERO
var age := 0.0
var attracted := false
var visual_on_screen := false
var redraw_interval := NORMAL_REDRAW_INTERVAL
var redraw_timer := 0.0
var visual_load_timer := 0.0

@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func setup(amount: int, world_position: Vector2, kind := "xp") -> void:
	value = amount
	pickup_kind = kind
	global_position = world_position
	rotation = randf() * TAU


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	screen_notifier.screen_entered.connect(_on_screen_entered)
	screen_notifier.screen_exited.connect(_on_screen_exited)
	var visual_phase := _visual_phase()
	redraw_timer = NORMAL_REDRAW_INTERVAL * (0.25 + visual_phase * 0.75)
	visual_load_timer = VISUAL_LOAD_REFRESH_INTERVAL * visual_phase
	_refresh_visual_load()


func _physics_process(delta: float) -> void:
	age += delta
	_update_visual_animation(delta)
	if not is_instance_valid(player):
		return
	var distance := global_position.distance_to(player.global_position)
	if pickup_kind == "xp" and (age >= 34.0 or (value >= 64 and age >= 6.0)):
		attracted = true
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
			world.audio.play_pickup(pickup_kind)
		queue_free()
		return


func request_visual_refresh() -> void:
	if visual_on_screen:
		queue_redraw()


func _update_visual_animation(delta: float) -> void:
	visual_load_timer -= delta
	if visual_load_timer <= 0.0:
		visual_load_timer += VISUAL_LOAD_REFRESH_INTERVAL
		_refresh_visual_load()
	if not visual_on_screen:
		return
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer += redraw_interval
		queue_redraw()


func _refresh_visual_load() -> void:
	var pickup_count := get_parent().get_child_count() if is_instance_valid(get_parent()) else 0
	if pickup_count >= HIGH_VISUAL_LOAD:
		redraw_interval = HIGH_REDRAW_INTERVAL
	elif pickup_count >= MEDIUM_VISUAL_LOAD:
		redraw_interval = MEDIUM_REDRAW_INTERVAL
	else:
		redraw_interval = NORMAL_REDRAW_INTERVAL
	redraw_timer = minf(redraw_timer, redraw_interval)


func _visual_phase() -> float:
	return float(get_instance_id() % 997) / 997.0


func _on_screen_entered() -> void:
	visual_on_screen = true
	_refresh_visual_load()
	queue_redraw()
	redraw_timer = redraw_interval * (0.25 + _visual_phase() * 0.75)


func _on_screen_exited() -> void:
	visual_on_screen = false


func _draw() -> void:
	var bob := sin(age * 5.0) * 2.0
	if pickup_kind == "heal":
		draw_circle(Vector2(0, bob), 10.0, Color("ff536b"))
		draw_rect(Rect2(-2.0, bob - 7.0, 4.0, 14.0), Color.WHITE)
		draw_rect(Rect2(-7.0, bob - 2.0, 14.0, 4.0), Color.WHITE)
		return
	var color := Color("83ed63") if value < 8 else Color("ffd45f")
	var highlight := Color("dcffb2") if value < 8 else Color("fff2ad")
	var center := Vector2(0, bob)
	# A silhueta redonda e o aro comunicam pickup mesmo durante combates cheios.
	draw_circle(center, 15.0, Color(color, 0.13))
	draw_circle(center, 9.0, Color("18351b") if value < 8 else Color("49330e"))
	draw_circle(center, 7.0, color)
	draw_arc(center, 10.0, 0.0, TAU, 24, Color(color, 0.92), 2.0)
	draw_circle(center + Vector2(-2.4, -2.6), 2.2, highlight)
	var sparkle := PackedVector2Array([
		center + Vector2(7.0, -10.0), center + Vector2(8.2, -7.2),
		center + Vector2(11.0, -6.0), center + Vector2(8.2, -4.8),
		center + Vector2(7.0, -2.0), center + Vector2(5.8, -4.8),
		center + Vector2(3.0, -6.0), center + Vector2(5.8, -7.2)
	])
	draw_colored_polygon(sparkle, highlight)
