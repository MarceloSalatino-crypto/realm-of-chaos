extends Node2D

const BASE_GROUND_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_ground_base.png")
const GROUND_DETAIL_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_ground_details.png")
const DENSE_GROVE_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_dense_grove.png")
const DENSE_GROVE_B_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_dense_grove_b.png")
const DENSE_GROVE_C_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_dense_grove_c.png")
const ROOT_ALTAR_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_root_altar.png")

const OPEN_ARENA := "OPEN_ARENA"
const DENSE_REGION := "DENSE_REGION"
const NATURAL_CORRIDOR := "NATURAL_CORRIDOR"
const LANDMARK_REGION := "LANDMARK_REGION"
const TRANSITION := "TRANSITION"

const CAPTURE_POINTS := {
	OPEN_ARENA: Vector2.ZERO,
	DENSE_REGION: Vector2(1420.0, 0.0),
	NATURAL_CORRIDOR: Vector2(760.0, 0.0),
	LANDMARK_REGION: Vector2(-980.0, 650.0),
	TRANSITION: Vector2(720.0, -390.0),
}

const TERRAIN_MAP_ORIGIN := Vector2(-2800.0, -1800.0)
const TERRAIN_MAP_SIZE := Vector2(5600.0, 3600.0)
const TERRAIN_MAP_RESOLUTION := Vector2i(384, 247)

var world: Node
var semantic_regions: Array[Dictionary] = [
	{"id": OPEN_ARENA, "bounds": Rect2(-560.0, -420.0, 1120.0, 840.0), "density": 0.18},
	{"id": DENSE_REGION, "bounds": Rect2(760.0, -620.0, 1380.0, 1240.0), "density": 0.92},
	{"id": NATURAL_CORRIDOR, "bounds": Rect2(390.0, -190.0, 760.0, 380.0), "density": 0.30},
	{"id": LANDMARK_REGION, "bounds": Rect2(-1640.0, 300.0, 920.0, 900.0), "density": 0.56},
	{"id": TRANSITION, "bounds": Rect2(-620.0, -980.0, 1520.0, 520.0), "density": 0.42},
]
var prop_anchor_metadata := {
	"dense_grove": {
		"visual_anchor": Vector2(0.0, 365.0),
		"shadow_footprints": [
			{"offset": Vector2(-180.0, 8.0), "size": Vector2(210.0, 62.0)},
			{"offset": Vector2(55.0, 6.0), "size": Vector2(260.0, 70.0)},
		],
		"collision_footprints": [
			{"offset": Vector2(-170.0, 0.0), "radius": 42.0},
			{"offset": Vector2(75.0, 0.0), "radius": 48.0},
		],
	},
	"root_altar": {
		"visual_anchor": Vector2(0.0, 355.0),
		"shadow_footprints": [
			{"offset": Vector2(-30.0, 5.0), "size": Vector2(410.0, 105.0)},
		],
		"collision_footprints": [
			{"offset": Vector2(-105.0, 0.0), "radius": 58.0},
			{"offset": Vector2(78.0, 0.0), "radius": 52.0},
		],
	},
}

var _batched_nodes: Array[MultiMeshInstance2D] = []
var _large_props: Node2D
var _lights: Node2D
var _terrain_blend_map: ImageTexture


class ForestAtmosphereLayer:
	extends Node2D

	func _ready() -> void:
		queue_redraw()


	func _draw() -> void:
		_draw_fog_band(Vector2(1270.0, -470.0), Vector2(760.0, 175.0), Color(0.20, 0.33, 0.36, 0.045), 19)
		_draw_fog_band(Vector2(1640.0, 360.0), Vector2(640.0, 145.0), Color(0.17, 0.27, 0.31, 0.038), 61)
		_draw_fog_band(Vector2(-1120.0, 910.0), Vector2(530.0, 125.0), Color(0.31, 0.16, 0.35, 0.042), 103)
		for point in [Vector2(-1215.0, 555.0), Vector2(-1110.0, 610.0), Vector2(1530.0, -165.0), Vector2(1660.0, 205.0)]:
			draw_rect(Rect2(point - Vector2.ONE * 2.0, Vector2.ONE * 4.0), Color(0.42, 0.58, 0.55, 0.18))


	func _draw_fog_band(center: Vector2, radius: Vector2, color: Color, seed: int) -> void:
		var polygon := PackedVector2Array()
		for index in range(20):
			var angle := TAU * float(index) / 20.0
			var wobble := 0.84 + 0.13 * sin(float(index * 5 + seed))
			polygon.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * wobble)
		draw_colored_polygon(polygon, color)


func setup(owner_world: Node) -> void:
	world = owner_world
	name = "ForestVerticalSlice"
	_disable_production_environment_for_preview()
	_configure_ground()
	_create_composition_layers()
	_create_contact_shadows()
	_create_large_props()
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
		"trail_representation": "continuous_material_mask",
		"prop_transition_aprons": 4,
	}


func _disable_production_environment_for_preview() -> void:
	for candidate in [world.decorations, world.obstacles, world.landmarks, world.hazards, world.map_overlay]:
		if is_instance_valid(candidate):
			candidate.visible = false
			candidate.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(world.map_overlay):
		world.map_overlay.visible = false


func _configure_ground() -> void:
	world.ground.texture = _create_mirrored_texture(BASE_GROUND_TEXTURE)
	world.ground.modulate = Color(0.86, 0.92, 0.91, 1.0)
	# Desloca os eixos do espelhamento para fora do centro jogável; as emendas
	# continuam contínuas, sem criar uma composição simétrica ao redor do player.
	world.ground.position = Vector2(431.0, -287.0)
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


func _create_composition_layers() -> void:
	var atmosphere := ForestAtmosphereLayer.new()
	atmosphere.name = "ForestAtmosphere"
	atmosphere.z_index = -2
	add_child(atmosphere)


func _create_terrain_blend_map() -> ImageTexture:
	var image := Image.create(
		TERRAIN_MAP_RESOLUTION.x, TERRAIN_MAP_RESOLUTION.y, false, Image.FORMAT_RGBA8
	)
	var broad_noise := FastNoiseLite.new()
	broad_noise.seed = 92831
	broad_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	broad_noise.frequency = 0.00115
	broad_noise.fractal_octaves = 3
	broad_noise.fractal_gain = 0.48
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 51607
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.0042
	detail_noise.fractal_octaves = 2
	var interruption_noise := FastNoiseLite.new()
	interruption_noise.seed = 37139
	interruption_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	interruption_noise.frequency = 0.0019
	interruption_noise.fractal_octaves = 2
	var routes := _terrain_routes()
	var prop_aprons: Array[Dictionary] = [
		{"center": Vector2(1080.0, -250.0), "radius": Vector2(520.0, 285.0), "strength": 0.74},
		{"center": Vector2(1450.0, 260.0), "radius": Vector2(470.0, 255.0), "strength": 0.70},
		{"center": Vector2(1785.0, -60.0), "radius": Vector2(540.0, 300.0), "strength": 0.76},
		{"center": Vector2(-1180.0, 720.0), "radius": Vector2(660.0, 390.0), "strength": 0.82},
	]

	for y in range(TERRAIN_MAP_RESOLUTION.y):
		for x in range(TERRAIN_MAP_RESOLUTION.x):
			var normalized := Vector2(
				(float(x) + 0.5) / float(TERRAIN_MAP_RESOLUTION.x),
				(float(y) + 0.5) / float(TERRAIN_MAP_RESOLUTION.y)
			)
			var world_position := TERRAIN_MAP_ORIGIN + normalized * TERRAIN_MAP_SIZE
			var broad := broad_noise.get_noise_2d(world_position.x, world_position.y) * 0.5 + 0.5
			var detail := detail_noise.get_noise_2d(world_position.x, world_position.y) * 0.5 + 0.5
			var soil := 0.025 + maxf(0.0, broad - 0.52) * 0.24
			var litter := maxf(0.0, detail - 0.58) * 0.10
			var rooted := 0.0

			for route_index in range(routes.size()):
				var route_result := _distance_to_route(world_position, routes[route_index], 18)
				var distance := route_result.x
				var progress := route_result.y
				var width := 154.0 + 50.0 * sin(progress * TAU * 1.7 + float(route_index) * 1.31)
				width += (detail - 0.5) * 52.0
				var core := 1.0 - smoothstep(width * 0.46, width * 1.36, distance)
				var interrupted := interruption_noise.get_noise_2d(
					world_position.x + float(route_index) * 731.0,
					world_position.y - float(route_index) * 419.0
				)
				var route_state := 0.48 + 0.26 * sin(progress * TAU * 2.35 + float(route_index) * 0.87)
				var continuity := smoothstep(-0.34, 0.16, interrupted)
				var path_strength := core * clampf(route_state + continuity * 0.44, 0.22, 0.98)
				var shoulder := (1.0 - smoothstep(width * 0.95, width * 2.25, distance)) * (1.0 - core * 0.72)
				soil = maxf(soil, path_strength * 0.94)
				litter = maxf(litter, shoulder * (0.22 + detail * 0.22) + path_strength * 0.08)

			var dense_factor := _ellipse_falloff(
				world_position, Vector2(1460.0, 0.0), Vector2(1450.0, 910.0), 0.55, 1.0
			)
			var transition_factor := _ellipse_falloff(
				world_position, Vector2(140.0, -760.0), Vector2(1280.0, 430.0), 0.48, 1.0
			)
			litter = maxf(litter, dense_factor * (0.14 + broad * 0.20))
			litter = maxf(litter, transition_factor * (0.10 + detail * 0.16))
			soil = maxf(soil, transition_factor * (0.08 + broad * 0.16))

			for apron in prop_aprons:
				var apron_strength := _ellipse_falloff(
					world_position, Vector2(apron.center), Vector2(apron.radius), 0.22, 1.0
				) * float(apron.strength)
				rooted = maxf(rooted, apron_strength)
				soil = maxf(soil, apron_strength * 0.40)
				litter = maxf(litter, apron_strength * (0.20 + detail * 0.16))

			image.set_pixel(
				x, y,
				Color(
					clampf(soil, 0.0, 0.82),
					clampf(litter, 0.0, 0.58),
					clampf(rooted, 0.0, 0.78),
					1.0
				)
			)
	return ImageTexture.create_from_image(image)


func _terrain_routes() -> Array[Dictionary]:
	return [
		{
			"start": Vector2(-870.0, 190.0), "control_a": Vector2(-410.0, -150.0),
			"control_b": Vector2(480.0, 145.0), "finish": Vector2(1260.0, -30.0),
		},
		{
			"start": Vector2(-40.0, 125.0), "control_a": Vector2(-310.0, 260.0),
			"control_b": Vector2(-700.0, 480.0), "finish": Vector2(-930.0, 700.0),
		},
		{
			"start": Vector2(-570.0, -760.0), "control_a": Vector2(-140.0, -570.0),
			"control_b": Vector2(440.0, -880.0), "finish": Vector2(930.0, -555.0),
		},
		{
			"start": Vector2(700.0, 75.0), "control_a": Vector2(980.0, -130.0),
			"control_b": Vector2(1320.0, -310.0), "finish": Vector2(1770.0, -115.0),
		},
	]


func _distance_to_route(point: Vector2, route: Dictionary, segments: int) -> Vector2:
	var closest_distance := INF
	var closest_progress := 0.0
	var previous := Vector2(route.start)
	for segment_index in range(1, segments + 1):
		var segment_progress := float(segment_index) / float(segments)
		var current := _cubic_bezier(
			Vector2(route.start), Vector2(route.control_a), Vector2(route.control_b),
			Vector2(route.finish), segment_progress
		)
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


func _ellipse_falloff(
	point: Vector2, center: Vector2, radius: Vector2, inner_edge: float, outer_edge: float
) -> float:
	var distance := ((point - center) / radius).length()
	return 1.0 - smoothstep(inner_edge, outer_edge, distance)


func _create_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D base_material : repeat_enable, filter_nearest;
uniform sampler2D integrated_details : repeat_enable, filter_nearest;
uniform sampler2D terrain_blend_map : filter_linear, repeat_disable;
uniform vec2 terrain_map_origin;
uniform vec2 terrain_map_size;
varying vec2 terrain_world_position;
varying vec4 terrain_vertex_tint;

void vertex() {
	terrain_world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	terrain_vertex_tint = COLOR;
}

vec4 sample_world_material(sampler2D material_texture, vec2 world_position, vec2 offset) {
	vec2 texture_size = vec2(textureSize(material_texture, 0));
	return texture(material_texture, world_position / texture_size + offset);
}

void fragment() {
	vec2 blend_uv = (terrain_world_position - terrain_map_origin) / terrain_map_size;
	float inside_map = step(0.0, blend_uv.x) * step(blend_uv.x, 1.0)
		* step(0.0, blend_uv.y) * step(blend_uv.y, 1.0);
	vec3 blend_weights = texture(terrain_blend_map, clamp(blend_uv, vec2(0.0), vec2(1.0))).rgb * inside_map;
	vec4 base = sample_world_material(base_material, terrain_world_position, vec2(0.0));
	vec4 shifted_base = sample_world_material(base_material, terrain_world_position * 0.91, vec2(0.173, 0.291));
	float soil_luma = dot(shifted_base.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 soil_palette = vec3(
		soil_luma * 1.16 + 0.038,
		soil_luma * 0.75 + 0.020,
		soil_luma * 0.53 + 0.010
	);
	vec4 soil = vec4(mix(shifted_base.rgb, soil_palette, 0.84), 1.0);
	vec4 detail_a = sample_world_material(integrated_details, terrain_world_position * 2.15, vec2(0.417, 0.119));
	vec4 detail_b = sample_world_material(integrated_details, terrain_world_position * 1.85, vec2(0.067, 0.533));
	float litter_luma = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 litter_palette = vec3(
		litter_luma * 0.88 + 0.014,
		litter_luma * 0.84 + 0.013,
		litter_luma * 0.58 + 0.007
	);
	vec4 litter = vec4(mix(base.rgb, litter_palette, 0.62), 1.0);
	litter.rgb = mix(litter.rgb, detail_a.rgb * 0.92, detail_a.a * 0.27);
	vec4 rooted = vec4(mix(soil.rgb, litter.rgb, 0.32), 1.0);
	rooted.rgb = mix(rooted.rgb, detail_b.rgb * 0.90, detail_b.a * 0.36);
	vec4 ground = mix(base, soil, blend_weights.r);
	ground = mix(ground, litter, blend_weights.g * (1.0 - blend_weights.r * 0.28));
	ground = mix(ground, rooted, blend_weights.b);
	COLOR = ground * terrain_vertex_tint;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_material", _create_mirrored_texture(BASE_GROUND_TEXTURE))
	material.set_shader_parameter("integrated_details", _create_mirrored_texture(GROUND_DETAIL_TEXTURE))
	material.set_shader_parameter("terrain_blend_map", _terrain_blend_map)
	material.set_shader_parameter("terrain_map_origin", TERRAIN_MAP_ORIGIN)
	material.set_shader_parameter("terrain_map_size", TERRAIN_MAP_SIZE)
	return material

func _cubic_bezier(start: Vector2, control_a: Vector2, control_b: Vector2, finish: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return (
		start * inverse * inverse * inverse
		+ control_a * 3.0 * inverse * inverse * progress
		+ control_b * 3.0 * inverse * progress * progress
		+ finish * progress * progress * progress
	)

func _create_contact_shadows() -> void:
	var shadow_texture := _create_contact_shadow_texture()
	var shadows: Array[Dictionary] = [
		{"position": Vector2(1080.0, -260.0), "size": Vector2(440.0, 108.0), "rotation": -0.04, "color": Color(0.015, 0.022, 0.026, 0.42)},
		{"position": Vector2(1455.0, 250.0), "size": Vector2(390.0, 92.0), "rotation": 0.08, "color": Color(0.015, 0.022, 0.026, 0.38)},
		{"position": Vector2(1780.0, -70.0), "size": Vector2(470.0, 116.0), "rotation": -0.08, "color": Color(0.015, 0.022, 0.026, 0.44)},
		{"position": Vector2(-1180.0, 735.0), "size": Vector2(510.0, 118.0), "rotation": 0.03, "color": Color(0.018, 0.012, 0.028, 0.46)},
	]
	_batched_nodes.append(_create_textured_batch("ContactShadows", shadow_texture, shadows, -5, true))


func _create_large_props() -> void:
	_large_props = Node2D.new()
	_large_props.name = "AnchoredEnvironmentProps"
	add_child(_large_props)
	var grove_instances: Array[Dictionary] = [
		_prop_instance(Vector2(1080.0, -250.0), 0.35, false, -0.025, 0),
		_prop_instance(Vector2(1450.0, 260.0), 0.31, true, 0.035, 1),
		_prop_instance(Vector2(1785.0, -60.0), 0.34, false, -0.045, 2),
	]
	var grove_batch := _create_grove_atlas_batch(grove_instances)
	_large_props.add_child(grove_batch)
	_batched_nodes.append(grove_batch)

	var landmark := Sprite2D.new()
	landmark.name = "RootAltarLandmark"
	landmark.texture = ROOT_ALTAR_TEXTURE
	landmark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	landmark.scale = Vector2.ONE * 0.40
	landmark.position = Vector2(-1180.0, 720.0) - Vector2(0.0, 355.0) * landmark.scale
	landmark.modulate = Color(0.87, 0.91, 0.92, 1.0)
	landmark.z_index = -3
	_large_props.add_child(landmark)


func _prop_instance(
	ground_position: Vector2, scale_value: float, flip_h: bool, rotation: float,
	texture_index: int
) -> Dictionary:
	return {
		"position": ground_position - Vector2(0.0, 365.0) * scale_value,
		"scale": Vector2(scale_value, scale_value),
		"rotation": rotation,
		"flip_h": flip_h,
		"color": Color(0.86, 0.91, 0.90, 1.0),
		"texture_index": texture_index,
	}


func _create_grove_atlas_batch(instances: Array[Dictionary]) -> MultiMeshInstance2D:
	var textures: Array[Texture2D] = [DENSE_GROVE_TEXTURE, DENSE_GROVE_B_TEXTURE, DENSE_GROVE_C_TEXTURE]
	var source_size := Vector2i(textures[0].get_size())
	var atlas_size := Vector2i(source_size.x * textures.size(), source_size.y)
	var atlas := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for texture_index in range(textures.size()):
		var source_image := textures[texture_index].get_image()
		if source_image.get_format() != Image.FORMAT_RGBA8:
			source_image.convert(Image.FORMAT_RGBA8)
		atlas.blit_rect(source_image, Rect2i(Vector2i.ZERO, source_size), Vector2i(texture_index * source_size.x, 0))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _create_unit_quad_mesh()
	multimesh.instance_count = instances.size()
	multimesh.visible_instance_count = instances.size()
	for index in range(instances.size()):
		var instance: Dictionary = instances[index]
		var visual_scale := Vector2(instance.scale)
		if bool(instance.flip_h):
			visual_scale.x *= -1.0
		var rendered_size := Vector2(source_size) * visual_scale
		var angle := float(instance.rotation)
		var x_axis := Vector2.RIGHT.rotated(angle) * rendered_size.x
		var y_axis := Vector2.DOWN.rotated(angle) * rendered_size.y
		multimesh.set_instance_transform_2d(index, Transform2D(x_axis, y_axis, Vector2(instance.position)))
		multimesh.set_instance_color(index, Color(instance.color))
		var texture_index := int(instance.texture_index)
		multimesh.set_instance_custom_data(index, Color(float(texture_index) / 3.0, 0.0, 1.0 / 3.0, 1.0))

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
varying vec4 atlas_region;
varying vec4 instance_tint;
void vertex() {
	atlas_region = INSTANCE_CUSTOM;
	instance_tint = COLOR;
}
void fragment() {
	vec2 atlas_uv = atlas_region.xy + UV * atlas_region.zw;
	COLOR = texture(TEXTURE, atlas_uv) * instance_tint;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var batch := MultiMeshInstance2D.new()
	batch.name = "DenseGroveAtlasBatch"
	batch.multimesh = multimesh
	batch.texture = ImageTexture.create_from_image(atlas)
	batch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	batch.material = material
	batch.z_index = -3
	return batch


func _create_controlled_lighting() -> void:
	var ambient := CanvasModulate.new()
	ambient.name = "ForestAmbientGrade"
	ambient.color = Color(0.78, 0.84, 0.86, 1.0)
	add_child(ambient)
	_lights = Node2D.new()
	_lights.name = "ControlledLightPools"
	add_child(_lights)
	var light_texture := _create_light_texture()
	_add_light(Vector2(-1180.0, 610.0), Color(0.39, 0.17, 0.52, 1.0), 0.42, 3.4, light_texture)
	_add_light(Vector2(35.0, -40.0), Color(0.18, 0.32, 0.29, 1.0), 0.22, 4.6, light_texture)


func _add_light(position: Vector2, color: Color, energy: float, texture_scale: float, texture: Texture2D) -> void:
	var light := PointLight2D.new()
	light.position = position
	light.color = color
	light.energy = energy
	light.texture = texture
	light.texture_scale = texture_scale
	light.height = 1.0
	_lights.add_child(light)


func _create_textured_batch(
	batch_name: String, texture: Texture2D, instances: Array[Dictionary], z_index: int,
	use_explicit_size := false
) -> MultiMeshInstance2D:
	var mesh := _create_unit_quad_mesh()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = instances.size()
	multimesh.visible_instance_count = instances.size()
	var source_size := Vector2(texture.get_size())
	for index in range(instances.size()):
		var instance: Dictionary = instances[index]
		var rendered_size := Vector2(instance.get("size", source_size)) if use_explicit_size else source_size * Vector2(instance.scale)
		if not use_explicit_size and bool(instance.get("flip_h", false)):
			rendered_size.x *= -1.0
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
	batch.z_index = z_index
	add_child(batch)
	return batch


func _create_unit_quad_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5),
		Vector2(0.5, 0.5), Vector2(-0.5, 0.5),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _create_contact_shadow_texture() -> ImageTexture:
	var image := Image.create(96, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var normalized := Vector2(
				(float(x) + 0.5 - 48.0) / 46.0,
				(float(y) + 0.5 - 24.0) / 21.0
			)
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
				alpha = 0.78
			elif distance <= 0.52:
				alpha = 0.46
			elif distance <= 0.76:
				alpha = 0.22
			elif distance <= 1.0 and (x + y) % 2 == 0:
				alpha = 0.08
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
