extends RefCounted

const FOREST_LOBE_GROUP := "forest_collision_lobes"
const ORIGINAL_KIND_META := "environment_obstacle_kind"
const ORIGINAL_RADIUS_META := "environment_obstacle_radius"
const COLLISION_CATEGORY_META := "forest_collision_category"
const PROFILE_APPLIED_META := "forest_collision_profile_applied"

# Os perfis usam pixels da arte-fonte relativos ao ponto de assentamento do
# bosque. Apenas troncos, raízes grossas e blocos grandes entram nos perfis.
# Folhagem, galhos finos e os vazios entre as massas ficam deliberadamente fora.
const GROVE_PROFILES := {
	0: [
		{"center": Vector2(-303.0, -142.0), "radius": 130.0, "height": 360.0},
		{"center": Vector2(302.0, -157.0), "radius": 130.0, "height": 390.0},
	],
	1: [
		{"center": Vector2(-338.0, -235.0), "radius": 112.0, "height": 310.0},
		{"center": Vector2(342.0, -235.0), "radius": 112.0, "height": 310.0},
	],
	2: [
		{"center": Vector2(-508.0, -142.0), "radius": 125.0, "height": 330.0},
		{"center": Vector2(262.0, -157.0), "radius": 150.0, "height": 500.0},
	],
}
const DENSE_EXTRA_PROFILES := {
	0: {"center": Vector2(-33.0, -227.0), "radius": 120.0, "height": 280.0},
	1: {"center": Vector2(12.0, -287.0), "radius": 110.0, "height": 250.0},
	2: {"center": Vector2(-78.0, -222.0), "radius": 130.0, "height": 330.0},
}

var world
var grove_lobe_count := 0
var dense_lobe_count := 0
var landmark_shape_count := 0
var collision_records: Array[Dictionary] = []


func _init(owner_world) -> void:
	world = owner_world


func apply_forest_profiles(grove_visuals: Array) -> void:
	clear()
	if not is_instance_valid(world) or str(world.biome.id) != "forest":
		return
	_disable_legacy_tree_shapes()
	for grove_index in range(grove_visuals.size()):
		var descriptor: Dictionary = grove_visuals[grove_index]
		var texture_index := int(descriptor.get("texture_index", 0))
		var profiles: Array = GROVE_PROFILES.get(texture_index, GROVE_PROFILES[0])
		for profile_index in range(profiles.size()):
			_create_grove_lobe(descriptor, profiles[profile_index], grove_index, profile_index)
		if bool(descriptor.get("dense", false)):
			_create_grove_lobe(
				descriptor, DENSE_EXTRA_PROFILES.get(texture_index, DENSE_EXTRA_PROFILES[0]),
				grove_index, profiles.size()
			)
	_apply_landmark_profiles()
	_mark_stone_categories()


func clear() -> void:
	if not is_instance_valid(world):
		return
	_remove_generated_lobes()
	_restore_legacy_tree_shapes()
	_restore_landmark_shapes()
	grove_lobe_count = 0
	dense_lobe_count = 0
	landmark_shape_count = 0
	collision_records.clear()


func summary() -> Dictionary:
	return {
		"active": grove_lobe_count > 0,
		"grove_lobes": grove_lobe_count,
		"dense_lobes": dense_lobe_count,
		"landmark_shapes": landmark_shape_count,
		"records": collision_records.duplicate(true),
	}


func _disable_legacy_tree_shapes() -> void:
	if not is_instance_valid(world.obstacles):
		return
	for body in world.obstacles.get_children():
		if str(body.get_meta(ORIGINAL_KIND_META, "")) != "tree":
			continue
		body.set_meta(COLLISION_CATEGORY_META, "grove_anchor")
		_remove_collision_shapes(body)


func _restore_legacy_tree_shapes() -> void:
	if not is_instance_valid(world.obstacles):
		return
	for body in world.obstacles.get_children():
		if str(body.get_meta(ORIGINAL_KIND_META, "")) != "tree":
			continue
		if not body.find_children("*", "CollisionShape2D", true, false).is_empty():
			continue
		var radius := float(body.get_meta(ORIGINAL_RADIUS_META, 18.0))
		_add_circle_shape(body, Vector2(0.0, 7.0), radius, "LegacyTreeCollision")
		body.remove_meta(COLLISION_CATEGORY_META)


func _remove_generated_lobes() -> void:
	if not is_instance_valid(world.obstacles):
		return
	for child in world.obstacles.get_children():
		if child.is_in_group(FOREST_LOBE_GROUP):
			child.free()


func _create_grove_lobe(
	descriptor: Dictionary, profile: Dictionary, grove_index: int, profile_index: int
) -> void:
	var anchor := Vector2(descriptor.anchor)
	var scale_value := float(Vector2(descriptor.scale).x)
	var visual_rotation := float(descriptor.rotation)
	var source_offset := Vector2(profile.center)
	if bool(descriptor.flip_h):
		source_offset.x = -source_offset.x
	var world_offset := (source_offset * scale_value).rotated(visual_rotation)
	var lobe := StaticBody2D.new()
	lobe.name = "ForestGroveLobe_%02d_%02d" % [grove_index, profile_index]
	lobe.position = anchor + world_offset
	lobe.z_index = -3
	lobe.collision_layer = 1
	lobe.collision_mask = 1
	lobe.add_to_group("physical_obstacles")
	lobe.add_to_group(FOREST_LOBE_GROUP)
	var dense := bool(descriptor.get("dense", false))
	lobe.set_meta(COLLISION_CATEGORY_META, "dense" if dense else "grove")
	lobe.set_meta("grove_index", grove_index)
	lobe.set_meta("grove_profile_index", profile_index)
	world.obstacles.add_child(lobe)

	var radius := float(profile.radius) * scale_value
	var height := maxf(float(profile.height) * scale_value, radius * 2.0)
	_add_capsule_shape(
		lobe, Vector2.ZERO, radius, height, visual_rotation + PI * 0.5,
		"GroveSolid_%02d_%02d" % [grove_index, profile_index]
	)
	grove_lobe_count += 1
	if dense:
		dense_lobe_count += 1
	collision_records.append({
		"category": "dense" if dense else "grove",
		"center": lobe.position,
		"radius": radius,
		"height": height,
		"rotation": visual_rotation + PI * 0.5,
		"grove_index": grove_index,
		"profile_index": profile_index,
	})


func _mark_stone_categories() -> void:
	for body in world.obstacles.get_children():
		if str(body.get_meta(ORIGINAL_KIND_META, "")) == "stone":
			body.set_meta(COLLISION_CATEGORY_META, "stone")


func _apply_landmark_profiles() -> void:
	if not is_instance_valid(world.landmarks):
		return
	for landmark in world.landmarks.get_children():
		_remove_collision_shapes(landmark)
		landmark.set_meta(PROFILE_APPLIED_META, true)
		landmark.set_meta(COLLISION_CATEGORY_META, "landmark")
		if landmark.has_method("set_contact_activation_enabled"):
			landmark.set_contact_activation_enabled(true)
		match str(landmark.landmark_kind):
			"altar":
				_add_horizontal_capsule(landmark, Vector2(0.0, -34.0), 34.0, 208.0, "AltarDais")
				_add_horizontal_capsule(landmark, Vector2(0.0, -91.0), 28.0, 168.0, "AltarTable")
				_add_capsule_shape(landmark, Vector2(-82.0, -143.0), 28.0, 198.0, -0.10, "AltarLeftArch")
				_add_capsule_shape(landmark, Vector2(65.0, -157.0), 32.0, 246.0, 0.08, "AltarRightTrunk")
				_add_horizontal_capsule(landmark, Vector2(-10.0, -226.0), 24.0, 170.0, "AltarCrown")
			"obelisk":
				_add_horizontal_capsule(landmark, Vector2(0.0, -18.0), 32.0, 196.0, "ObeliskBase")
				_add_capsule_shape(landmark, Vector2(0.0, -137.0), 25.0, 236.0, 0.0, "ObeliskSpire")
				_add_capsule_shape(landmark, Vector2(-75.0, -50.0), 21.0, 112.0, -0.06, "ObeliskLeftPillar")
				_add_capsule_shape(landmark, Vector2(75.0, -50.0), 21.0, 112.0, 0.06, "ObeliskRightPillar")
			"tree":
				_add_horizontal_capsule(landmark, Vector2(0.0, -9.0), 36.0, 224.0, "SoulTreeRoots")
				_add_capsule_shape(landmark, Vector2(0.0, -125.0), 38.0, 250.0, 0.0, "SoulTreeTrunk")
				_add_capsule_shape(landmark, Vector2(-55.0, -169.0), 22.0, 150.0, -0.48, "SoulTreeLeftBranch")
				_add_capsule_shape(landmark, Vector2(57.0, -166.0), 22.0, 150.0, 0.48, "SoulTreeRightBranch")
				_add_horizontal_capsule(landmark, Vector2(0.0, -226.0), 22.0, 190.0, "SoulTreeCrown")
			"portal":
				_add_capsule_shape(landmark, Vector2(-71.0, -98.0), 27.0, 250.0, -0.03, "PortalLeftPillar")
				_add_capsule_shape(landmark, Vector2(71.0, -98.0), 27.0, 250.0, 0.03, "PortalRightPillar")
				_add_horizontal_capsule(landmark, Vector2(0.0, -207.0), 25.0, 170.0, "PortalArch")
		landmark_shape_count += landmark.find_children("*", "CollisionShape2D", true, false).size()


func _restore_landmark_shapes() -> void:
	if not is_instance_valid(world.landmarks):
		return
	for landmark in world.landmarks.get_children():
		if not bool(landmark.get_meta(PROFILE_APPLIED_META, false)):
			continue
		_remove_collision_shapes(landmark)
		_add_circle_shape(landmark, Vector2(0.0, -4.0), 43.0, "LandmarkCollision")
		if landmark.has_method("set_contact_activation_enabled"):
			landmark.set_contact_activation_enabled(false)
		landmark.remove_meta(PROFILE_APPLIED_META)
		landmark.remove_meta(COLLISION_CATEGORY_META)


func _remove_collision_shapes(body: Node) -> void:
	for shape in body.find_children("*", "CollisionShape2D", true, false):
		shape.free()


func _add_horizontal_capsule(
	body: Node, position: Vector2, radius: float, height: float, shape_name: String
) -> void:
	_add_capsule_shape(body, position, radius, height, PI * 0.5, shape_name)


func _add_capsule_shape(
	body: Node, position: Vector2, radius: float, height: float,
	rotation: float, shape_name: String
) -> CollisionShape2D:
	var collision := CollisionShape2D.new()
	collision.name = shape_name
	collision.position = position
	collision.rotation = rotation
	var capsule := CapsuleShape2D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	collision.shape = capsule
	body.add_child(collision)
	return collision


func _add_circle_shape(
	body: Node, position: Vector2, radius: float, shape_name: String
) -> CollisionShape2D:
	var collision := CollisionShape2D.new()
	collision.name = shape_name
	collision.position = position
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	body.add_child(collision)
	return collision
