class_name WeaponFlash
extends Sprite2D

const WEAPON_ATLAS = preload("res://assets/generated/weapon_atlas_v1.png")


func _ready() -> void:
	texture = WEAPON_ATLAS
	hframes = 5
	z_index = 18


func setup(
	world_position: Vector2, atlas_frame: int, angle: float,
	target_scale: float, duration: float, tint := Color.WHITE
) -> void:
	global_position = world_position
	frame = atlas_frame
	rotation = angle
	scale = Vector2.ONE * target_scale * 0.72
	modulate = tint
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * target_scale, duration * 0.32)
	tween.tween_property(self, "rotation", angle + 0.18, duration)
	tween.tween_property(self, "modulate", Color(tint, 0.0), duration).set_delay(duration * 0.38)
	tween.chain().tween_callback(queue_free)
