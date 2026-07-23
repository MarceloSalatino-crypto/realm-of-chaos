class_name BossArena
extends Node2D

const REDRAW_INTERVAL := 1.0 / 30.0

var world: Node
var boss: Node
var boss_kind := "ossuary_colossus"
var radius := 720.0
var phase := 1
var active := true
var animation_time := 0.0
var arena_color := Color("b86cff")
var redraw_timer := 0.0


func configure(owner_world: Node, arena_boss: Node, center: Vector2, kind: String, final_boss := false) -> void:
	world = owner_world
	boss = arena_boss
	global_position = center
	boss_kind = kind
	radius = 790.0 if final_boss else 690.0
	arena_color = _color_for_kind(kind)
	z_index = -1


func _process(delta: float) -> void:
	animation_time += delta
	if not active or not is_instance_valid(world) or not is_instance_valid(world.player):
		return
	var offset: Vector2 = world.player.global_position - global_position
	var limit := radius - 34.0
	if offset.length() > limit:
		var normal := offset.normalized()
		world.player.global_position = global_position + normal * limit
		if world.player.velocity.dot(normal) > 0.0:
			world.player.velocity -= normal * world.player.velocity.dot(normal)
	redraw_timer -= delta
	if redraw_timer <= 0.0:
		redraw_timer += REDRAW_INTERVAL
		queue_redraw()


func set_phase(new_phase: int) -> void:
	phase = new_phase
	queue_redraw()


func finish() -> void:
	if not active:
		return
	active = false
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.55)
	tween.tween_callback(queue_free)


func _color_for_kind(kind: String) -> Color:
	match kind:
		"ossuary_colossus": return Color("d6ad72")
		"glacial_archon": return Color("67ddff")
		"infernal_reaper": return Color("ff5d4f")
		"void_titan": return Color("ce63ff")
		"chaos_sovereign": return Color("ffd06a")
		_: return Color("b86cff")


func _draw() -> void:
	var pulse := (sin(animation_time * (1.5 + phase * 0.18)) + 1.0) * 0.5
	draw_circle(Vector2.ZERO, radius, Color(arena_color, 0.018 + phase * 0.008))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 128, Color(arena_color, 0.48 + pulse * 0.22), 7.0)
	draw_arc(Vector2.ZERO, radius - 18.0, -animation_time * 0.12, -animation_time * 0.12 + PI * 1.58, 96, Color(arena_color, 0.24), 2.0)
	for index in range(12):
		var angle := TAU * index / 12.0 + animation_time * 0.08
		var position := Vector2.RIGHT.rotated(angle) * (radius - 7.0)
		draw_colored_polygon(PackedVector2Array([
			position + Vector2.RIGHT.rotated(angle) * 13.0,
			position + Vector2.RIGHT.rotated(angle + 2.35) * 8.0,
			position + Vector2.RIGHT.rotated(angle - 2.35) * 8.0
		]), Color(arena_color, 0.32 + pulse * 0.18))
