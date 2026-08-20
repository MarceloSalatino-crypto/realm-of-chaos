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
var batch_renderer: Node

@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func setup(amount: int, world_position: Vector2, kind := "xp") -> void:
	value = amount
	pickup_kind = kind
	global_position = world_position
	rotation = randf() * TAU if pickup_kind == "xp" else 0.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	var world := get_tree().get_first_node_in_group("world")
	if is_instance_valid(world):
		batch_renderer = world.get("pickup_batch_renderer")
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
		_mark_batch_transform_dirty()
	if distance <= 24.0:
		if pickup_kind == "heal":
			player.heal(float(value))
		else:
			player.collect_xp(value)
		var world := get_tree().get_first_node_in_group("world")
		if world and (pickup_kind == "heal" or value >= 8):
			world.audio.play_pickup(pickup_kind)
		visual_on_screen = false
		_set_batch_visibility(false)
		queue_free()
		return


func request_visual_refresh() -> void:
	_refresh_batch_visual()
	if visual_on_screen:
		_request_canvas_redraw()


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
		_refresh_batch_bob()
		_request_canvas_redraw()


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
	_refresh_batch_visual()
	_request_canvas_redraw()
	redraw_timer = redraw_interval * (0.25 + _visual_phase() * 0.75)


func _on_screen_exited() -> void:
	visual_on_screen = false
	_set_batch_visibility(false)


func _draw() -> void:
	if _uses_batch_renderer():
		return
	var bob := sin(age * 5.0) * 2.0
	if pickup_kind == "heal":
		var heal_center := Vector2(0.0, bob)
		var outline := PackedVector2Array([
			heal_center + Vector2(0.0, -13.0), heal_center + Vector2(9.0, -9.0),
			heal_center + Vector2(12.0, -2.0), heal_center + Vector2(10.0, 8.0),
			heal_center + Vector2(0.0, 14.0), heal_center + Vector2(-10.0, 8.0),
			heal_center + Vector2(-12.0, -2.0), heal_center + Vector2(-9.0, -9.0),
		])
		var fill := PackedVector2Array([
			heal_center + Vector2(0.0, -10.0), heal_center + Vector2(6.5, -7.0),
			heal_center + Vector2(8.5, -1.5), heal_center + Vector2(7.0, 5.5),
			heal_center + Vector2(0.0, 10.5), heal_center + Vector2(-7.0, 5.5),
			heal_center + Vector2(-8.5, -1.5), heal_center + Vector2(-6.5, -7.0),
		])
		draw_colored_polygon(outline, Color("240d18"))
		draw_colored_polygon(fill, Color("d93652"))
		draw_colored_polygon(PackedVector2Array([
			heal_center + Vector2(0.0, 0.0), heal_center + Vector2(7.0, -1.5),
			heal_center + Vector2(6.0, 4.8), heal_center + Vector2(0.0, 9.0),
		]), Color("a61f3e"))
		draw_rect(Rect2(heal_center + Vector2(-3.0, -8.0), Vector2(6.0, 16.0)), Color("240d18"))
		draw_rect(Rect2(heal_center + Vector2(-8.0, -3.0), Vector2(16.0, 6.0)), Color("240d18"))
		draw_rect(Rect2(heal_center + Vector2(-1.75, -6.5), Vector2(3.5, 13.0)), Color("fff3e8"))
		draw_rect(Rect2(heal_center + Vector2(-6.5, -1.75), Vector2(13.0, 3.5)), Color("fff3e8"))
		return
	var color := Color("83ed63") if value < 8 else Color("ffd45f")
	var highlight := Color("dcffb2") if value < 8 else Color("fff2ad")
	var center := Vector2(0.0, bob)
	var crystal_size := 10.5 if value < 8 else 12.0
	var crystal_outline := PackedVector2Array([
		center + Vector2(0.0, -crystal_size),
		center + Vector2(crystal_size * 0.66, -crystal_size * 0.32),
		center + Vector2(crystal_size * 0.52, crystal_size * 0.54),
		center + Vector2(0.0, crystal_size),
		center + Vector2(-crystal_size * 0.52, crystal_size * 0.54),
		center + Vector2(-crystal_size * 0.66, -crystal_size * 0.32),
	])
	var crystal_fill := PackedVector2Array([
		center + Vector2(0.0, -crystal_size * 0.72),
		center + Vector2(crystal_size * 0.44, -crystal_size * 0.22),
		center + Vector2(crystal_size * 0.35, crystal_size * 0.38),
		center + Vector2(0.0, crystal_size * 0.72),
		center + Vector2(-crystal_size * 0.35, crystal_size * 0.38),
		center + Vector2(-crystal_size * 0.44, -crystal_size * 0.22),
	])
	draw_colored_polygon(crystal_outline, Color("12220f") if value < 8 else Color("2c210b"))
	draw_colored_polygon(crystal_fill, color.darkened(0.14))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -crystal_size * 0.68),
		center + Vector2(crystal_size * 0.40, -crystal_size * 0.20),
		center + Vector2(0.0, crystal_size * 0.62),
	]), color)
	draw_line(
		center + Vector2(-crystal_size * 0.18, -crystal_size * 0.38),
		center + Vector2(-crystal_size * 0.18, crystal_size * 0.28),
		highlight, 1.6
	)


func _request_canvas_redraw() -> void:
	if not _uses_batch_renderer():
		queue_redraw()


func _refresh_batch_visual() -> void:
	if is_instance_valid(batch_renderer):
		batch_renderer.register_pickup(self)


func _refresh_batch_bob() -> void:
	if is_instance_valid(batch_renderer):
		batch_renderer.update_pickup_bob(self, pickup_batch_bob())


func _set_batch_visibility(visible_state: bool) -> void:
	if is_instance_valid(batch_renderer):
		batch_renderer.set_pickup_visible(self, visible_state)


func _mark_batch_transform_dirty() -> void:
	if not visual_on_screen:
		return
	if is_instance_valid(batch_renderer):
		batch_renderer.mark_pickup_transform_dirty(self)


func _uses_batch_renderer() -> bool:
	return is_instance_valid(batch_renderer) and bool(batch_renderer.get("rendering_enabled"))


func pickup_batch_style() -> String:
	if pickup_kind == "heal":
		return "heal"
	return "xp_common" if value < 8 else "xp_high"


func pickup_batch_bob() -> float:
	return sin(age * 5.0) * 2.0
