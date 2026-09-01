extends Node2D

const BASE_GROUND_TEXTURE := preload("res://assets/generated/frozen_vertical_slice/frozen_ground_base.png")
const BURIED_CAUSEWAY_TEXTURE := preload("res://assets/generated/frozen_vertical_slice/frozen_buried_causeway.png")
const RUIN_CLOISTER_TEXTURE := preload("res://assets/generated/frozen_vertical_slice/frozen_ruin_cloister.png")
const MONOLITH_GUARDIAN_TEXTURE := preload("res://assets/generated/frozen_vertical_slice/frozen_monolith_guardian.png")
const SIEGE_REMAINS_TEXTURE := preload("res://assets/generated/frozen_vertical_slice/frozen_siege_remains.png")
const LANDMARK_SANCTUM_TEXTURE := preload("res://assets/generated/frozen_vertical_slice/frozen_landmark_sanctum.png")

const OPEN_ARENA := "OPEN_ARENA"
const DENSE_REGION := "DENSE_REGION"
const NATURAL_CORRIDOR := "NATURAL_CORRIDOR"
const LANDMARK_REGION := "LANDMARK_REGION"
const TRANSITION := "TRANSITION"

const CAPTURE_POINTS := {
	OPEN_ARENA: Vector2.ZERO,
	NATURAL_CORRIDOR: Vector2(790.0, -40.0),
	DENSE_REGION: Vector2(1570.0, -410.0),
	LANDMARK_REGION: Vector2(-1080.0, 735.0),
	TRANSITION: Vector2(1160.0, -670.0),
}

const TERRAIN_MAP_ORIGIN := Vector2(-2800.0, -1800.0)
const TERRAIN_MAP_SIZE := Vector2(5600.0, 3600.0)
const TERRAIN_MAP_RESOLUTION := Vector2i(384, 247)

var world: Node
var semantic_regions: Array[Dictionary] = [
	{"id": OPEN_ARENA, "bounds": Rect2(-570.0, -420.0, 1140.0, 840.0), "density": 0.20},
	{"id": NATURAL_CORRIDOR, "bounds": Rect2(330.0, -260.0, 940.0, 470.0), "density": 0.34},
	{"id": DENSE_REGION, "bounds": Rect2(980.0, -930.0, 1280.0, 1130.0), "density": 0.90},
	{"id": LANDMARK_REGION, "bounds": Rect2(-1660.0, 250.0, 1120.0, 1040.0), "density": 0.58},
	{"id": TRANSITION, "bounds": Rect2(560.0, -1040.0, 1220.0, 590.0), "density": 0.46},
]
var prop_anchor_metadata := {
	"collapsed_cloister": {
		"visual_anchor": Vector2(0.0, 420.0),
		"shadow_footprints": [
			{"offset": Vector2(-165.0, 30.0), "size": Vector2(260.0, 70.0)},
			{"offset": Vector2(120.0, 20.0), "size": Vector2(310.0, 82.0)},
		],
	},
	"frozen_sanctum": {
		"visual_anchor": Vector2(0.0, 460.0),
		"shadow_footprints": [
			{"offset": Vector2(0.0, 24.0), "size": Vector2(520.0, 118.0)},
		],
	},
}

var _batched_nodes: Array[MultiMeshInstance2D] = []
var _terrain_blend_map: ImageTexture
var _composition_root: Node2D
var _lights: Node2D


class FrozenAtmosphereLayer:
	extends Node2D

	func _ready() -> void:
		queue_redraw()


	func _draw() -> void:
		_draw_fog_band(Vector2(1540.0, -640.0), Vector2(700.0, 145.0), Color(0.22, 0.34, 0.43, 0.035), 17)
		_draw_fog_band(Vector2(-1110.0, 970.0), Vector2(570.0, 118.0), Color(0.20, 0.29, 0.39, 0.032), 43)
		_draw_fog_band(Vector2(680.0, 250.0), Vector2(610.0, 92.0), Color(0.25, 0.32, 0.37, 0.022), 79)
		for point in [Vector2(-1180.0, 515.0), Vector2(1690.0, -560.0), Vector2(1840.0, -235.0)]:
			draw_rect(Rect2(point - Vector2.ONE * 2.0, Vector2.ONE * 4.0), Color(0.39, 0.68, 0.78, 0.12))


	func _draw_fog_band(center: Vector2, radius: Vector2, color: Color, seed: int) -> void:
		var polygon := PackedVector2Array()
		for index in range(20):
			var angle := TAU * float(index) / 20.0
			var wobble := 0.85 + 0.11 * sin(float(index * 5 + seed))
			polygon.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * wobble)
		draw_colored_polygon(polygon, color)


func setup(owner_world: Node) -> void:
	world = owner_world
	name = "FrozenRuinsVerticalSlice"
	_disable_production_environment_for_preview()
	_configure_ground()
	_create_composition_root()
	_create_contact_shadows()
	_create_architectural_groups()
	_create_controlled_lighting()


func focus_region(region_id: String) -> void:
	if not CAPTURE_POINTS.has(region_id):
		return
	world.player.global_position = Vector2(CAPTURE_POINTS[region_id])
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()


func batch_count() -> int:
	return _batched_nodes.size()


func get_semantic_region_ids() -> Array[String]:
	var ids: Array[String] = []
	for region in semantic_regions:
		ids.append(str(region.id))
	return ids


func get_prop_anchor_metadata() -> Dictionary:
	return prop_anchor_metadata.duplicate(true)


func get_terrain_system_summary() -> Dictionary:
	return {
		"material_count": 4,
		"blend_map_resolution": TERRAIN_MAP_RESOLUTION,
		"causeway_representation": "continuous_material_mask",
		"prop_transition_aprons": 7,
		"cyan_is_accent_only": true,
	}


func _disable_production_environment_for_preview() -> void:
	for candidate in [world.decorations, world.obstacles, world.landmarks, world.hazards, world.map_overlay]:
		if is_instance_valid(candidate):
			candidate.visible = false
			candidate.process_mode = Node.PROCESS_MODE_DISABLED


func _configure_ground() -> void:
	world.ground.texture = _create_mirrored_texture(BASE_GROUND_TEXTURE)
	world.ground.modulate = Color(0.86, 0.90, 0.94, 1.0)
	world.ground.position = Vector2(367.0, -241.0)
	world.ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_terrain_blend_map = _create_terrain_blend_map()
	world.ground.material = _create_terrain_material()


func _create_mirrored_texture(source_texture: Texture2D) -> ImageTexture:
	var original := source_texture.get_image()
	if original.get_format() != Image.FORMAT_RGBA8:
		original.convert(Image.FORMAT_RGBA8)
	var source_size := original.get_size()
	var mirrored := Image.create(source_size.x * 2, source_size.y * 2, false, Image.FORMAT_RGBA8)
	var horizontal := original.duplicate()
	horizontal.flip_x()
	var vertical := original.duplicate()
	vertical.flip_y()
	var both := original.duplicate()
	both.flip_x()
	both.flip_y()
	mirrored.blit_rect(original, Rect2i(Vector2i.ZERO, source_size), Vector2i.ZERO)
	mirrored.blit_rect(horizontal, Rect2i(Vector2i.ZERO, source_size), Vector2i(source_size.x, 0))
	mirrored.blit_rect(vertical, Rect2i(Vector2i.ZERO, source_size), Vector2i(0, source_size.y))
	mirrored.blit_rect(both, Rect2i(Vector2i.ZERO, source_size), source_size)
	return ImageTexture.create_from_image(mirrored)


func _create_composition_root() -> void:
	_composition_root = Node2D.new()
	_composition_root.name = "FrozenArchitecturalCompositions"
	add_child(_composition_root)
	var atmosphere := FrozenAtmosphereLayer.new()
	atmosphere.name = "SparseFrozenAtmosphere"
	atmosphere.z_index = -2
	add_child(atmosphere)


func _create_terrain_blend_map() -> ImageTexture:
	var image := Image.create(TERRAIN_MAP_RESOLUTION.x, TERRAIN_MAP_RESOLUTION.y, false, Image.FORMAT_RGBA8)
	var broad_noise := FastNoiseLite.new()
	broad_noise.seed = 83741
	broad_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	broad_noise.frequency = 0.00110
	broad_noise.fractal_octaves = 3
	broad_noise.fractal_gain = 0.46
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 41597
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.0045
	detail_noise.fractal_octaves = 2
	var fracture_noise := FastNoiseLite.new()
	fracture_noise.seed = 26033
	fracture_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	fracture_noise.frequency = 0.0030
	var routes := _terrain_routes()
	var aprons: Array[Dictionary] = [
		{"center": Vector2(1450.0, -610.0), "radius": Vector2(580.0, 390.0), "strength": 0.82},
		{"center": Vector2(1830.0, -215.0), "radius": Vector2(440.0, 330.0), "strength": 0.72},
		{"center": Vector2(1320.0, 20.0), "radius": Vector2(560.0, 290.0), "strength": 0.64},
		{"center": Vector2(720.0, 310.0), "radius": Vector2(420.0, 230.0), "strength": 0.52},
		{"center": Vector2(990.0, -790.0), "radius": Vector2(390.0, 250.0), "strength": 0.48},
		{"center": Vector2(-1080.0, 665.0), "radius": Vector2(720.0, 500.0), "strength": 0.92},
		{"center": Vector2(430.0, -45.0), "radius": Vector2(330.0, 190.0), "strength": 0.38},
	]

	for y in range(TERRAIN_MAP_RESOLUTION.y):
		for x in range(TERRAIN_MAP_RESOLUTION.x):
			var uv := Vector2((float(x) + 0.5) / TERRAIN_MAP_RESOLUTION.x, (float(y) + 0.5) / TERRAIN_MAP_RESOLUTION.y)
			var world_position := TERRAIN_MAP_ORIGIN + uv * TERRAIN_MAP_SIZE
			var broad := broad_noise.get_noise_2d(world_position.x, world_position.y) * 0.5 + 0.5
			var detail := detail_noise.get_noise_2d(world_position.x, world_position.y) * 0.5 + 0.5
			var fractured := fracture_noise.get_noise_2d(world_position.x, world_position.y) * 0.5 + 0.5
			var snow := 0.04 + maxf(0.0, broad - 0.55) * 0.30
			var black_ice := maxf(0.0, 0.42 - broad) * 0.30 + maxf(0.0, fractured - 0.73) * 0.15
			var rubble := maxf(0.0, detail - 0.57) * 0.18
			var causeway := 0.0

			for route_index in range(routes.size()):
				var route_result := _distance_to_route(world_position, routes[route_index], 18)
				var distance := route_result.x
				var progress := route_result.y
				var width := 132.0 + 38.0 * sin(progress * TAU * 1.65 + float(route_index) * 0.91)
				width += (detail - 0.5) * 34.0
				var core := 1.0 - smoothstep(width * 0.52, width * 1.38, distance)
				var buried_state := 0.42 + 0.32 * sin(progress * TAU * 2.1 + float(route_index) * 1.17)
				var continuity := smoothstep(0.31, 0.69, detail)
				var route_strength := core * clampf(buried_state + continuity * 0.38, 0.16, 0.92)
				var shoulder := (1.0 - smoothstep(width * 0.95, width * 2.35, distance)) * (1.0 - core * 0.65)
				black_ice = maxf(black_ice, route_strength * 0.38)
				rubble = maxf(rubble, route_strength * 0.72 + shoulder * (0.18 + detail * 0.18))
				snow = maxf(snow, shoulder * (0.18 + broad * 0.22))
				causeway = maxf(causeway, route_strength)

			var dense_factor := _ellipse_falloff(world_position, Vector2(1540.0, -410.0), Vector2(1160.0, 830.0), 0.42, 1.0)
			var open_factor := _ellipse_falloff(world_position, Vector2.ZERO, Vector2(640.0, 470.0), 0.28, 1.0)
			rubble = maxf(rubble, dense_factor * (0.16 + detail * 0.22))
			snow = maxf(snow, dense_factor * (0.10 + broad * 0.20))
			rubble *= 1.0 - open_factor * 0.46
			black_ice *= 1.0 - open_factor * 0.34

			for apron in aprons:
				var apron_strength := _ellipse_falloff(world_position, Vector2(apron.center), Vector2(apron.radius), 0.22, 1.0) * float(apron.strength)
				rubble = maxf(rubble, apron_strength * (0.28 + detail * 0.30))
				snow = maxf(snow, apron_strength * (0.18 + broad * 0.24))
				black_ice = maxf(black_ice, apron_strength * 0.20)

			image.set_pixel(x, y, Color(clampf(snow, 0.0, 0.58), clampf(black_ice, 0.0, 0.48), clampf(rubble, 0.0, 0.78), clampf(causeway, 0.0, 0.88)))
	return ImageTexture.create_from_image(image)


func _terrain_routes() -> Array[Dictionary]:
	return [
		{"start": Vector2(-720.0, 210.0), "control_a": Vector2(-260.0, -170.0), "control_b": Vector2(520.0, 130.0), "finish": Vector2(1290.0, -60.0)},
		{"start": Vector2(270.0, -30.0), "control_a": Vector2(-40.0, 210.0), "control_b": Vector2(-620.0, 430.0), "finish": Vector2(-1070.0, 735.0)},
		{"start": Vector2(570.0, -740.0), "control_a": Vector2(940.0, -610.0), "control_b": Vector2(1320.0, -920.0), "finish": Vector2(1770.0, -560.0)},
		{"start": Vector2(740.0, 25.0), "control_a": Vector2(1000.0, -180.0), "control_b": Vector2(1370.0, -285.0), "finish": Vector2(1780.0, -390.0)},
	]


func _distance_to_route(point: Vector2, route: Dictionary, segments: int) -> Vector2:
	var closest_distance := INF
	var closest_progress := 0.0
	var previous := Vector2(route.start)
	for segment_index in range(1, segments + 1):
		var segment_progress := float(segment_index) / float(segments)
		var current := _cubic_bezier(Vector2(route.start), Vector2(route.control_a), Vector2(route.control_b), Vector2(route.finish), segment_progress)
		var segment_vector := current - previous
		var segment_length_squared := segment_vector.length_squared()
		var local_progress := 0.0
		if segment_length_squared > 0.001:
			local_progress = clampf((point - previous).dot(segment_vector) / segment_length_squared, 0.0, 1.0)
		var closest_point := previous + segment_vector * local_progress
		var distance := point.distance_to(closest_point)
		if distance < closest_distance:
			closest_distance = distance
			closest_progress = (float(segment_index - 1) + local_progress) / float(segments)
		previous = current
	return Vector2(closest_distance, closest_progress)


func _ellipse_falloff(point: Vector2, center: Vector2, radius: Vector2, inner_edge: float, outer_edge: float) -> float:
	return 1.0 - smoothstep(inner_edge, outer_edge, ((point - center) / radius).length())


func _create_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D base_material : repeat_enable, filter_nearest;
uniform sampler2D causeway_material : repeat_enable, filter_nearest;
uniform sampler2D terrain_blend_map : filter_linear, repeat_disable;
uniform vec2 terrain_map_origin;
uniform vec2 terrain_map_size;
varying vec2 terrain_world_position;
varying vec4 terrain_vertex_tint;

void vertex() {
	terrain_world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	terrain_vertex_tint = COLOR;
}

vec4 sample_world_material(vec2 world_position, vec2 offset, float scale_value) {
	vec2 texture_size = vec2(textureSize(base_material, 0));
	return texture(base_material, world_position * scale_value / texture_size + offset);
}

void fragment() {
	vec2 blend_uv = (terrain_world_position - terrain_map_origin) / terrain_map_size;
	float inside_map = step(0.0, blend_uv.x) * step(blend_uv.x, 1.0) * step(0.0, blend_uv.y) * step(blend_uv.y, 1.0);
	vec4 weights = texture(terrain_blend_map, clamp(blend_uv, vec2(0.0), vec2(1.0))) * inside_map;
	vec4 base = sample_world_material(terrain_world_position, vec2(0.0), 1.0);
	vec4 shifted = sample_world_material(terrain_world_position, vec2(0.317, 0.173), 0.91);
	vec4 detail = sample_world_material(terrain_world_position, vec2(0.079, 0.521), 1.72);
	float luma = dot(shifted.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 dirty_snow = vec3(luma * 0.62 + 0.155, luma * 0.69 + 0.175, luma * 0.76 + 0.205);
	vec3 black_ice = mix(base.rgb * vec3(0.56, 0.69, 0.83), shifted.rgb * vec3(0.42, 0.62, 0.80), 0.48);
	vec3 rubble = mix(base.rgb * vec3(0.74, 0.77, 0.81), detail.rgb * vec3(0.68, 0.72, 0.77), 0.43);
	vec3 ground = mix(base.rgb, dirty_snow, weights.r);
	ground = mix(ground, black_ice, weights.g * (1.0 - weights.r * 0.38));
	ground = mix(ground, rubble, weights.b * (1.0 - weights.r * 0.22));
	vec2 causeway_size = vec2(textureSize(causeway_material, 0));
	vec4 causeway = texture(causeway_material, terrain_world_position / causeway_size + vec2(0.13, 0.27));
	float causeway_amount = weights.a * causeway.a * 0.74;
	ground = mix(ground, causeway.rgb * vec3(0.74, 0.80, 0.86), causeway_amount);
	COLOR = vec4(ground, base.a) * terrain_vertex_tint;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_material", _create_mirrored_texture(BASE_GROUND_TEXTURE))
	material.set_shader_parameter("causeway_material", BURIED_CAUSEWAY_TEXTURE)
	material.set_shader_parameter("terrain_blend_map", _terrain_blend_map)
	material.set_shader_parameter("terrain_map_origin", TERRAIN_MAP_ORIGIN)
	material.set_shader_parameter("terrain_map_size", TERRAIN_MAP_SIZE)
	return material


func _cubic_bezier(start: Vector2, control_a: Vector2, control_b: Vector2, finish: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return start * inverse * inverse * inverse + control_a * 3.0 * inverse * inverse * progress + control_b * 3.0 * inverse * progress * progress + finish * progress * progress * progress


func _create_contact_shadows() -> void:
	var shadow_texture := _create_contact_shadow_texture()
	var shadows: Array[Dictionary] = [
		{"position": Vector2(1450.0, -405.0), "size": Vector2(500.0, 108.0), "rotation": -0.02, "color": Color(0.010, 0.018, 0.032, 0.48)},
		{"position": Vector2(1835.0, -35.0), "size": Vector2(390.0, 92.0), "rotation": 0.05, "color": Color(0.010, 0.018, 0.032, 0.42)},
		{"position": Vector2(1320.0, 185.0), "size": Vector2(470.0, 88.0), "rotation": -0.06, "color": Color(0.010, 0.018, 0.032, 0.40)},
		{"position": Vector2(710.0, 445.0), "size": Vector2(340.0, 72.0), "rotation": 0.03, "color": Color(0.010, 0.018, 0.032, 0.34)},
		{"position": Vector2(980.0, -650.0), "size": Vector2(310.0, 70.0), "rotation": -0.04, "color": Color(0.010, 0.018, 0.032, 0.34)},
		{"position": Vector2(-1080.0, 940.0), "size": Vector2(570.0, 122.0), "rotation": 0.0, "color": Color(0.008, 0.014, 0.029, 0.52)},
	]
	_batched_nodes.append(_create_textured_batch("FrozenContactShadows", shadow_texture, shadows, -6, true))


func _create_architectural_groups() -> void:
	_add_prop("CollapsedCloister", RUIN_CLOISTER_TEXTURE, Vector2(1450.0, -650.0), 0.46, -0.025, false, Color(0.83, 0.88, 0.92, 1.0), -3)
	_add_prop("GuardianMonoliths", MONOLITH_GUARDIAN_TEXTURE, Vector2(1840.0, -285.0), 0.38, 0.025, true, Color(0.81, 0.87, 0.92, 1.0), -3)
	_add_prop("SiegeRemainsDense", SIEGE_REMAINS_TEXTURE, Vector2(1310.0, 20.0), 0.40, -0.04, false, Color(0.80, 0.86, 0.91, 1.0), -3)
	_add_prop("SiegeRemainsCorridor", SIEGE_REMAINS_TEXTURE, Vector2(710.0, 320.0), 0.27, 0.055, true, Color(0.75, 0.82, 0.88, 0.86), -4)
	_add_prop("TransitionMonolith", MONOLITH_GUARDIAN_TEXTURE, Vector2(980.0, -790.0), 0.29, -0.04, false, Color(0.77, 0.84, 0.90, 0.90), -4)
	_add_prop("FrozenSanctumLandmark", LANDMARK_SANCTUM_TEXTURE, Vector2(-1080.0, 665.0), 0.48, 0.0, false, Color(0.85, 0.90, 0.94, 1.0), -3)


func _add_prop(prop_name: String, texture: Texture2D, position: Vector2, scale_value: float, rotation: float, flip_h: bool, tint: Color, z_layer: int) -> void:
	var prop := Sprite2D.new()
	prop.name = prop_name
	prop.texture = texture
	prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prop.position = position
	prop.scale = Vector2(-scale_value if flip_h else scale_value, scale_value)
	prop.rotation = rotation
	prop.modulate = tint
	prop.z_index = z_layer
	_composition_root.add_child(prop)


func _create_controlled_lighting() -> void:
	var ambient := CanvasModulate.new()
	ambient.name = "FrozenAmbientGrade"
	ambient.color = Color(0.75, 0.82, 0.89, 1.0)
	add_child(ambient)
	_lights = Node2D.new()
	_lights.name = "RestrainedCyanAccents"
	add_child(_lights)
	var light_texture := _create_light_texture()
	_add_light(Vector2(-1080.0, 600.0), Color(0.26, 0.58, 0.72, 1.0), 0.31, 3.25, light_texture)
	_add_light(Vector2(1780.0, -315.0), Color(0.22, 0.48, 0.62, 1.0), 0.18, 2.35, light_texture)


func _add_light(position: Vector2, color: Color, energy: float, texture_scale: float, texture: Texture2D) -> void:
	var light := PointLight2D.new()
	light.position = position
	light.color = color
	light.energy = energy
	light.texture = texture
	light.texture_scale = texture_scale
	light.height = 1.0
	_lights.add_child(light)


func _create_textured_batch(batch_name: String, texture: Texture2D, instances: Array, z_layer: int, use_explicit_size := false) -> MultiMeshInstance2D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = _create_unit_quad_mesh()
	multimesh.instance_count = instances.size()
	multimesh.visible_instance_count = instances.size()
	var source_size := Vector2(texture.get_size())
	for index in range(instances.size()):
		var instance: Dictionary = instances[index]
		var rendered_size := Vector2(instance.get("size", source_size)) if use_explicit_size else source_size * Vector2(instance.scale)
		var angle := float(instance.get("rotation", 0.0))
		var x_axis := Vector2.RIGHT.rotated(angle) * rendered_size.x
		var y_axis := Vector2.DOWN.rotated(angle) * rendered_size.y
		multimesh.set_instance_transform_2d(index, Transform2D(x_axis, y_axis, Vector2(instance.position)))
		multimesh.set_instance_color(index, Color(instance.color))
	var batch := MultiMeshInstance2D.new()
	batch.name = batch_name
	batch.multimesh = multimesh
	batch.texture = texture
	batch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	batch.z_index = z_layer
	add_child(batch)
	return batch


func _create_unit_quad_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _create_contact_shadow_texture() -> ImageTexture:
	var image := Image.create(96, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var normalized := Vector2((float(x) + 0.5 - 48.0) / 46.0, (float(y) + 0.5 - 24.0) / 21.0)
			var distance := normalized.length()
			var alpha := 0.0
			if distance <= 0.56:
				alpha = 0.92
			elif distance <= 0.78:
				alpha = 0.58
			elif distance <= 1.0 and (x + y * 3) % 3 != 0:
				alpha = 0.26
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _create_light_texture() -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var normalized := Vector2(float(x) + 0.5 - 64.0, float(y) + 0.5 - 64.0) / 63.0
			var distance := normalized.length()
			var alpha := 0.0
			if distance <= 0.28:
				alpha = 0.76
			elif distance <= 0.52:
				alpha = 0.44
			elif distance <= 0.76:
				alpha = 0.20
			elif distance <= 1.0 and (x + y) % 2 == 0:
				alpha = 0.07
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
