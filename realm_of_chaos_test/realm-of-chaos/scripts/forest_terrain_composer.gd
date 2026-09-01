extends RefCounted

const BASE_GROUND_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_ground_base.png")
const GROUND_DETAIL_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_ground_details.png")
const DENSE_GROVE_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_dense_grove.png")
const DENSE_GROVE_B_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_dense_grove_b.png")
const DENSE_GROVE_C_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_dense_grove_c.png")
const ROOT_ALTAR_TEXTURE := preload("res://assets/generated/forest_vertical_slice/forest_root_altar.png")

const TERRAIN_MAP_ORIGIN := Vector2(-6000.0, -6000.0)
const TERRAIN_MAP_SIZE := Vector2(12000.0, 12000.0)
const TERRAIN_MAP_RESOLUTION := Vector2i(384, 384)
const ROUTE_SEGMENTS := 24
const DETAIL_PLACEMENT_PATTERN := [
	"route", "settlement", "route", "dense", "route",
	"settlement", "background", "route", "settlement", "route",
	"dense", "settlement", "route", "background", "settlement",
	"route", "dense", "settlement", "route", "settlement",
]
const LANDMARK_KINDS := ["altar", "obelisk", "tree", "portal"]

var world
var terrain_blend_map: ImageTexture
var route_count := 0
var apron_count := 0
var dense_bridge_count := 0
var route_state_counts := {"visible": 0, "overgrown": 0, "faded": 0}
var build_time_ms := 0.0
var _mirrored_base: ImageTexture
var _mirrored_details: ImageTexture
var _routes: Array[Dictionary] = []
var _composition_root: Node2D
var _grove_anchor_positions: Array[Vector2] = []
var _dense_group_positions: Array[Vector2] = []
var _settlement_anchors: Array[Dictionary] = []
var _semantic_capture_points: Dictionary = {}
var _detail_placement_counts: Dictionary = {}
var _detail_placement_index := 0
var _route_placement_index := 0
var _settlement_placement_index := 0
var _dense_placement_index := 0
var _layout_revision := 0
var _detail_layout_revision := 0
var _layout_prepared := false


func _init(owner_world) -> void:
	world = owner_world


func _clear_rendered_composition() -> void:
	if is_instance_valid(_composition_root):
		_composition_root.free()
	_composition_root = null
	if is_instance_valid(world) and is_instance_valid(world.ground):
		world.ground.material = null
	terrain_blend_map = null


func clear() -> void:
	_clear_rendered_composition()
	_routes.clear()
	_grove_anchor_positions.clear()
	_dense_group_positions.clear()
	_settlement_anchors.clear()
	_semantic_capture_points.clear()
	_detail_placement_counts.clear()
	_detail_placement_index = 0
	_route_placement_index = 0
	_settlement_placement_index = 0
	_dense_placement_index = 0
	_layout_prepared = false
	route_count = 0
	apron_count = 0
	dense_bridge_count = 0
	route_state_counts = {"visible": 0, "overgrown": 0, "faded": 0}
	build_time_ms = 0.0


func rebuild() -> bool:
	_clear_rendered_composition()
	if str(world.biome.id) != "forest":
		return false
	if not _layout_prepared:
		prepare_layout()
	var started_at := Time.get_ticks_usec()
	var blend_image := _create_base_blend_map(_routes)
	_stamp_environment_aprons(blend_image)
	_stamp_dense_connections(blend_image)
	terrain_blend_map = ImageTexture.create_from_image(blend_image)
	world.ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.ground.material = _create_terrain_material()
	_create_semantic_composition()
	build_time_ms = float(Time.get_ticks_usec() - started_at) / 1000.0
	return true


func prepare_layout() -> void:
	_routes.clear()
	_grove_anchor_positions.clear()
	_dense_group_positions.clear()
	_settlement_anchors.clear()
	_layout_prepared = false
	if str(world.biome.id) != "forest":
		return
	_grove_anchor_positions = _select_grove_anchors()
	_settlement_anchors = _build_settlement_anchors()
	_routes = _build_routes()
	_layout_revision += 1
	_detail_layout_revision = _layout_revision
	_detail_placement_counts = {
		"route": 0,
		"settlement": 0,
		"dense": 0,
		"background": 0,
	}
	_detail_placement_index = 0
	_route_placement_index = 0
	_settlement_placement_index = 0
	_dense_placement_index = 0
	_layout_prepared = true


func sample_visual_placement(rng: RandomNumberGenerator, maximum: float) -> Dictionary:
	if str(world.biome.id) != "forest":
		return {
			"position": Vector2(rng.randf_range(-maximum, maximum), rng.randf_range(-maximum, maximum)),
			"context": "background", "scale_min": 0.65, "scale_max": 1.15,
			"alpha_min": 0.34, "alpha_max": 0.58, "tint": Color.WHITE,
		}
	if not _layout_prepared:
		prepare_layout()
	var category := str(DETAIL_PLACEMENT_PATTERN[_detail_placement_index % DETAIL_PLACEMENT_PATTERN.size()])
	_detail_placement_index += 1
	_detail_placement_counts[category] = int(_detail_placement_counts.get(category, 0)) + 1
	if category == "route":
		return _sample_route_placement(rng, maximum)
	if category == "settlement":
		return _sample_settlement_placement(rng, maximum)
	if category == "dense":
		return _sample_dense_placement(rng, maximum)
	return {
		"position": Vector2(rng.randf_range(-maximum, maximum), rng.randf_range(-maximum, maximum)),
		"context": "background", "scale_min": 0.42, "scale_max": 0.72,
		"alpha_min": 0.10, "alpha_max": 0.20, "tint": Color("73847d"),
	}


func sample_visual_position(rng: RandomNumberGenerator, maximum: float) -> Vector2:
	return Vector2(sample_visual_placement(rng, maximum).position)


func _sample_route_placement(rng: RandomNumberGenerator, maximum: float) -> Dictionary:
	if _routes.is_empty():
		return {
			"position": Vector2(rng.randf_range(-maximum, maximum), rng.randf_range(-maximum, maximum)),
			"context": "route", "scale_min": 0.50, "scale_max": 0.88,
			"alpha_min": 0.19, "alpha_max": 0.36, "tint": Color("7b8d82"),
		}
	var route_index := _route_placement_index % _routes.size()
	var cluster_index := floori(float(_route_placement_index) / float(_routes.size()))
	_route_placement_index += 1
	var route: Dictionary = _routes[route_index]
	var progress_slot := (cluster_index * 7 + route_index * 3) % 15
	var progress := clampf((float(progress_slot) + 0.8) / 16.0 + rng.randf_range(-0.022, 0.022), 0.035, 0.965)
	var center := _route_point(route, progress)
	var previous := _route_point(route, maxf(0.0, progress - 0.015))
	var following := _route_point(route, minf(1.0, progress + 0.015))
	var tangent := (following - previous).normalized()
	var normal := tangent.rotated(PI * 0.5)
	var edge_distance := rng.randf_range(118.0, 305.0)
	if rng.randf() < 0.24:
		edge_distance = rng.randf_range(24.0, 108.0)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var position := center + normal * edge_distance * side + tangent * rng.randf_range(-72.0, 72.0)
	position.x = clampf(position.x, -maximum, maximum)
	position.y = clampf(position.y, -maximum, maximum)
	return {
		"position": position, "context": "route", "scale_min": 0.50, "scale_max": 0.88,
		"alpha_min": 0.19, "alpha_max": 0.36, "tint": Color("7b8d82"),
	}


func _sample_settlement_placement(rng: RandomNumberGenerator, maximum: float) -> Dictionary:
	if _settlement_anchors.is_empty():
		return _sample_route_placement(rng, maximum)
	var anchor: Dictionary = _settlement_anchors[_settlement_placement_index % _settlement_anchors.size()]
	_settlement_placement_index += 1
	var radius := Vector2(anchor.radius)
	var angle := rng.randf() * TAU
	var distance_factor := sqrt(rng.randf_range(0.08, 1.0))
	var position := Vector2(anchor.position) + Vector2(
		cos(angle) * radius.x, sin(angle) * radius.y
	) * distance_factor
	position += Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-15.0, 15.0))
	position.x = clampf(position.x, -maximum, maximum)
	position.y = clampf(position.y, -maximum, maximum)
	var anchor_kind := str(anchor.kind)
	var context := "settlement_" + anchor_kind
	var tint := Color("7d9185")
	if anchor_kind == "stone" or anchor_kind == "landmark_obelisk":
		tint = Color("858f8a")
	elif anchor_kind == "landmark_altar":
		tint = Color("897c78")
	elif anchor_kind == "landmark_portal":
		tint = Color("827b8c")
	elif anchor_kind == "landmark_tree":
		tint = Color("748b80")
	var scale_min := 0.50
	var scale_max := 0.94
	var alpha_min := 0.22
	var alpha_max := 0.44
	if anchor_kind == "stone":
		scale_min = 0.56
		scale_max = 0.96
		alpha_min = 0.28
		alpha_max = 0.48
	return {
		"position": position, "context": context, "scale_min": scale_min, "scale_max": scale_max,
		"alpha_min": alpha_min, "alpha_max": alpha_max, "tint": tint,
	}


func _sample_dense_placement(rng: RandomNumberGenerator, maximum: float) -> Dictionary:
	if _dense_group_positions.is_empty():
		return _sample_route_placement(rng, maximum)
	var first_index := _dense_placement_index % _dense_group_positions.size()
	var second_index := (first_index + 1) % _dense_group_positions.size()
	_dense_placement_index += 1
	var first := _dense_group_positions[first_index]
	var second := _dense_group_positions[second_index]
	var center := first.lerp(second, rng.randf_range(0.18, 0.82))
	var position := center + Vector2(rng.randfn(0.0, 205.0), rng.randfn(0.0, 135.0))
	position.x = clampf(position.x, -maximum, maximum)
	position.y = clampf(position.y, -maximum, maximum)
	return {
		"position": position, "context": "dense", "scale_min": 0.52, "scale_max": 0.90,
		"alpha_min": 0.20, "alpha_max": 0.40, "tint": Color("76897f"),
	}


func sample_floor_decal_position(
	rng: RandomNumberGenerator, maximum: float, kind_index: int, variant_index: int
) -> Vector2:
	if not _layout_prepared or _routes.is_empty():
		return Vector2(rng.randf_range(-maximum, maximum), rng.randf_range(-maximum, maximum))
	var selection := (kind_index * 12 + variant_index) % 3
	if selection == 0:
		var route := _routes[(kind_index + variant_index) % _routes.size()]
		var progress := rng.randf_range(0.10, 0.90)
		var center := _route_point(route, progress)
		var previous := _route_point(route, maxf(0.0, progress - 0.02))
		var following := _route_point(route, minf(1.0, progress + 0.02))
		var normal := (following - previous).normalized().rotated(PI * 0.5)
		return center + normal * rng.randf_range(-190.0, 190.0)
	if selection == 1 and not _settlement_anchors.is_empty():
		var anchor := _settlement_anchors[(kind_index * 7 + variant_index) % _settlement_anchors.size()]
		return Vector2(anchor.position) + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(105.0, 310.0)
	if not _dense_group_positions.is_empty():
		var dense_position := _dense_group_positions[variant_index % _dense_group_positions.size()]
		return dense_position + Vector2(rng.randfn(0.0, 260.0), rng.randfn(0.0, 170.0))
	return Vector2(rng.randf_range(-maximum, maximum), rng.randf_range(-maximum, maximum))


func capture_point(region_id: String) -> Vector2:
	return Vector2(_semantic_capture_points.get(region_id, Vector2.ZERO))


func art_layout() -> Dictionary:
	return {
		"capture_points": _semantic_capture_points.duplicate(true),
		"grove_anchors": _grove_anchor_positions.duplicate(),
		"grove_visuals": grove_visual_layout(),
		"dense_group": _dense_group_positions.duplicate(),
		"settlement_anchors": _settlement_anchors.duplicate(true),
		"detail_placement_counts": _detail_placement_counts.duplicate(),
	}


func grove_visual_layout() -> Array[Dictionary]:
	var instances: Array[Dictionary] = []
	for index in range(_grove_anchor_positions.size()):
		var scale_value := (
			0.30 + float(index % 3) * 0.018
			if index < _dense_group_positions.size()
			else 0.215 + float(index % 4) * 0.010
		)
		instances.append({
			"anchor": _grove_anchor_positions[index],
			"position": _grove_anchor_positions[index] - Vector2(0.0, 365.0) * scale_value,
			"scale": Vector2.ONE * scale_value,
			"rotation": -0.035 + float(index % 4) * 0.022,
			"flip_h": index % 2 == 1,
			"dense": index < _dense_group_positions.size(),
			"color": (
				Color(0.82, 0.88, 0.86, 0.98)
				if index < _dense_group_positions.size()
				else Color(0.78, 0.85, 0.82, 0.97)
			),
			"texture_index": index % 3,
		})
	return instances


func summary() -> Dictionary:
	return {
		"active": is_instance_valid(world.ground.material),
		"blend_map_resolution": TERRAIN_MAP_RESOLUTION,
		"route_count": route_count,
		"apron_count": apron_count,
		"dense_bridge_count": dense_bridge_count,
		"route_state_counts": route_state_counts.duplicate(),
		"grove_count": _grove_anchor_positions.size(),
		"dense_grove_count": _dense_group_positions.size(),
		"settlement_anchor_count": _settlement_anchors.size(),
		"semantic_region_count": _semantic_capture_points.size(),
		"detail_placement_counts": _detail_placement_counts.duplicate(),
		"layout_revision": _layout_revision,
		"detail_layout_revision": _detail_layout_revision,
		"layout_finalized": _layout_prepared and _layout_revision == _detail_layout_revision,
		"representation": "continuous_material_mask",
		"build_time_ms": build_time_ms,
	}


func _create_base_blend_map(routes: Array[Dictionary]) -> Image:
	route_state_counts = {"visible": 0, "overgrown": 0, "faded": 0}
	var image := Image.create(
		TERRAIN_MAP_RESOLUTION.x, TERRAIN_MAP_RESOLUTION.y, false, Image.FORMAT_RGBA8
	)
	var broad_noise := FastNoiseLite.new()
	broad_noise.seed = 92831 + world.map_seed_offset * 307
	broad_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	broad_noise.frequency = 0.00082
	broad_noise.fractal_octaves = 3
	broad_noise.fractal_gain = 0.48
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 51607 + world.map_seed_offset * 181
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.0032
	detail_noise.fractal_octaves = 2
	var interruption_noise := FastNoiseLite.new()
	interruption_noise.seed = 37139 + world.map_seed_offset * 233
	interruption_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	interruption_noise.frequency = 0.00155
	interruption_noise.fractal_octaves = 2

	for y in range(TERRAIN_MAP_RESOLUTION.y):
		for x in range(TERRAIN_MAP_RESOLUTION.x):
			var normalized := Vector2(
				(float(x) + 0.5) / float(TERRAIN_MAP_RESOLUTION.x),
				(float(y) + 0.5) / float(TERRAIN_MAP_RESOLUTION.y)
			)
			var world_position := TERRAIN_MAP_ORIGIN + normalized * TERRAIN_MAP_SIZE
			var broad := broad_noise.get_noise_2d(world_position.x, world_position.y) * 0.5 + 0.5
			var detail := detail_noise.get_noise_2d(world_position.x, world_position.y) * 0.5 + 0.5
			var soil := 0.030 + maxf(0.0, broad - 0.43) * 0.38
			var litter := maxf(0.0, detail - 0.47) * 0.22
			var rooted := maxf(0.0, broad + detail - 1.20) * 0.12
			image.set_pixel(
				x, y,
				Color(
					clampf(soil, 0.0, 0.82),
					clampf(litter, 0.0, 0.56),
					clampf(rooted, 0.0, 0.20),
					0.0
				)
			)
	for route_index in range(routes.size()):
		_stamp_route(image, routes[route_index], route_index, detail_noise, interruption_noise)
	return image


func _stamp_route(
	image: Image, route: Dictionary, route_index: int,
	detail_noise: FastNoiseLite, interruption_noise: FastNoiseLite
) -> void:
	var minimum_world := Vector2(INF, INF)
	var maximum_world := Vector2(-INF, -INF)
	for route_point in [route.start, route.control_a, route.control_b, route.finish]:
		minimum_world = minimum_world.min(Vector2(route_point))
		maximum_world = maximum_world.max(Vector2(route_point))
	var route_margin := Vector2.ONE * 650.0
	var minimum := _world_to_pixel(minimum_world - route_margin)
	var maximum := _world_to_pixel(maximum_world + route_margin)
	var minimum_x := clampi(floori(minimum.x), 0, TERRAIN_MAP_RESOLUTION.x - 1)
	var minimum_y := clampi(floori(minimum.y), 0, TERRAIN_MAP_RESOLUTION.y - 1)
	var maximum_x := clampi(ceili(maximum.x), 0, TERRAIN_MAP_RESOLUTION.x - 1)
	var maximum_y := clampi(ceili(maximum.y), 0, TERRAIN_MAP_RESOLUTION.y - 1)
	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var world_position := _pixel_to_world(Vector2(x + 0.5, y + 0.5))
			var route_result := _distance_to_route(world_position, route)
			var distance := route_result.x
			var progress := route_result.y
			var detail := detail_noise.get_noise_2d(world_position.x, world_position.y) * 0.5 + 0.5
			var response := _route_environment_response(route, progress)
			var width := 220.0 + 72.0 * sin(progress * TAU * 1.55 + float(route_index) * 1.17)
			width += (detail - 0.5) * 70.0
			width = clampf(width * response.y, 118.0, 320.0)
			var edge_noise := detail_noise.get_noise_2d(
				world_position.x + 927.0 + float(route_index) * 173.0,
				world_position.y - 641.0 - float(route_index) * 211.0
			) * 0.5 + 0.5
			var irregular_distance := maxf(0.0, distance - (edge_noise - 0.5) * 54.0)
			if irregular_distance > width * 2.35:
				continue
			var core := 1.0 - smoothstep(width * 0.48, width * 1.26, irregular_distance)
			var interrupted := interruption_noise.get_noise_2d(
				world_position.x + float(route_index) * 719.0,
				world_position.y - float(route_index) * 431.0
			)
			var state_wave := 0.5 + 0.5 * sin(
				progress * TAU * 2.15 + float(route_index) * 0.83
			)
			var exposure_signal := clampf(
				state_wave * 0.52 + (interrupted * 0.5 + 0.5) * 0.48 - response.z * 0.24,
				0.0, 1.0
			)
			# Mesmo os trechos quase desaparecidos precisam sobreviver ao grade escuro
			# da câmera. A irregularidade continua vindo do núcleo, da borda e da
			# invasão de vegetação; a rota não depende de contraste quase nulo.
			var path_presence := 0.27 + smoothstep(0.16, 0.84, exposure_signal) * 0.71
			var path_strength := core * path_presence
			var exposed_core := (
				1.0 - smoothstep(width * 0.16, width * 0.70, irregular_distance)
			) * (0.18 + path_presence * 0.82)
			var shoulder := (
				(1.0 - smoothstep(width * 0.78, width * 2.35, irregular_distance))
				* (1.0 - core * 0.66)
			)
			if core > 0.38:
				if exposure_signal >= 0.64:
					route_state_counts.visible = int(route_state_counts.visible) + 1
				elif exposure_signal >= 0.34:
					route_state_counts.overgrown = int(route_state_counts.overgrown) + 1
				else:
					route_state_counts.faded = int(route_state_counts.faded) + 1
			var current := image.get_pixel(x, y)
			var invaded_core := core * (1.0 - path_presence) * (0.20 + response.z * 0.32)
			image.set_pixel(
				x, y,
				Color(
					maxf(current.r, path_strength * 0.96),
					maxf(
						current.g,
						shoulder * (0.23 + detail * 0.29) + path_strength * 0.08 + invaded_core
					),
					maxf(current.b, shoulder * (0.06 + response.z * 0.14) + invaded_core * 0.64),
					maxf(current.a, maxf(path_strength * 0.94, exposed_core))
				)
			)


func _build_routes() -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	if world.landmark_positions.size() < 4:
		route_count = 0
		return routes
	var landmarks: Array[Vector2] = []
	for landmark_position in world.landmark_positions:
		landmarks.append(Vector2(landmark_position))
	var rng := RandomNumberGenerator.new()
	rng.seed = 611953 + world.map_seed_offset * 809
	routes.append(_curved_route(Vector2(-520.0, 260.0), landmarks[0], rng.randf_range(-390.0, 390.0)))
	routes.append(_curved_route(Vector2(310.0, -420.0), landmarks[1], rng.randf_range(-430.0, 430.0)))
	routes.append(_curved_route(landmarks[0], landmarks[2], rng.randf_range(-520.0, 520.0)))
	routes.append(_curved_route(landmarks[1], landmarks[3], rng.randf_range(-520.0, 520.0)))
	var final_destination := landmarks[3]
	if not _dense_group_positions.is_empty():
		final_destination = Vector2.ZERO
		for dense_position in _dense_group_positions:
			final_destination += dense_position
		final_destination /= float(_dense_group_positions.size())
	routes.append(_curved_route(landmarks[2], final_destination, rng.randf_range(-620.0, 620.0)))
	for index in range(routes.size()):
		routes[index] = _prepare_visual_route(routes[index])
	route_count = routes.size()
	return routes


func _build_settlement_anchors() -> Array[Dictionary]:
	var anchors: Array[Dictionary] = []
	for index in range(world.landmark_positions.size()):
		var landmark_kind: String = str(LANDMARK_KINDS[index]) if index < LANDMARK_KINDS.size() else "altar"
		var landmark_radius := Vector2(510.0, 350.0)
		if landmark_kind == "tree":
			landmark_radius = Vector2(570.0, 390.0)
		elif landmark_kind == "obelisk":
			landmark_radius = Vector2(450.0, 315.0)
		elif landmark_kind == "portal":
			landmark_radius = Vector2(485.0, 335.0)
		anchors.append({
			"position": Vector2(world.landmark_positions[index]),
			"radius": landmark_radius,
			"kind": "landmark_" + landmark_kind,
		})
	for index in range(world.obstacles.get_child_count()):
		var obstacle := world.obstacles.get_child(index) as Node2D
		if not is_instance_valid(obstacle):
			continue
		var is_stone := index >= 26
		anchors.append({
			"position": obstacle.position,
			"radius": Vector2(245.0, 158.0) if is_stone else Vector2(295.0, 205.0),
			"kind": "stone" if is_stone else "tree",
		})
	return anchors


func _curved_route(start: Vector2, finish: Vector2, bend: float) -> Dictionary:
	var direction := finish - start
	var normal := direction.normalized().rotated(PI * 0.5)
	return {
		"start": start,
		"control_a": start + direction * 0.31 + normal * bend,
		"control_b": start + direction * 0.69 - normal * bend * 0.54,
		"finish": finish,
	}


func _prepare_visual_route(route: Dictionary) -> Dictionary:
	var influences: Array[Dictionary] = []
	for anchor in _settlement_anchors:
		var anchor_position := Vector2(anchor.position)
		var radius := Vector2(anchor.radius)
		var route_result := _distance_to_raw_route(anchor_position, route)
		var maximum_distance := radius.x + 260.0
		if route_result.x > maximum_distance:
			continue
		var progress := route_result.y
		var center := _raw_route_point(route, progress)
		var previous := _raw_route_point(route, maxf(0.0, progress - 0.012))
		var following := _raw_route_point(route, minf(1.0, progress + 0.012))
		var normal := (following - previous).normalized().rotated(PI * 0.5)
		var signed_side := (anchor_position - center).dot(normal)
		if absf(signed_side) < 1.0:
			signed_side = (
				-1.0
				if sin(anchor_position.x * 0.017 + anchor_position.y * 0.011) >= 0.0
				else 1.0
			)
		var closeness := 1.0 - smoothstep(radius.x * 0.30, maximum_distance, route_result.x)
		var kind := str(anchor.kind)
		var is_landmark := kind.begins_with("landmark_")
		var is_tree := kind == "tree"
		var target_width_scale := 1.08 if is_landmark else (0.72 if is_tree else 0.82)
		var target_overgrowth := 0.10 if is_landmark else (0.62 if is_tree else 0.34)
		var avoidance := 0.0
		if not is_landmark:
			avoidance = (
				(-1.0 if signed_side > 0.0 else 1.0)
				* (108.0 if is_tree else 72.0)
				* closeness
			)
		influences.append({
			"progress": progress,
			"range": 0.105 if is_landmark else (0.080 if is_tree else 0.060),
			"offset": avoidance,
			"width_scale": lerpf(1.0, target_width_scale, closeness),
			"overgrowth": target_overgrowth * closeness,
		})
	route["influences"] = influences
	var visual_points: Array[Vector2] = []
	for index in range(ROUTE_SEGMENTS + 1):
		var progress := float(index) / float(ROUTE_SEGMENTS)
		var raw_point := _raw_route_point(route, progress)
		var previous := _raw_route_point(route, maxf(0.0, progress - 0.008))
		var following := _raw_route_point(route, minf(1.0, progress + 0.008))
		var normal := (following - previous).normalized().rotated(PI * 0.5)
		var response := _route_environment_response(route, progress)
		visual_points.append(raw_point + normal * response.x)
	route["visual_points"] = visual_points
	return route


func _route_environment_response(route: Dictionary, progress: float) -> Vector3:
	var offset := 0.0
	var width_scale := 1.0
	var overgrowth := 0.0
	var influences: Array = route.get("influences", [])
	for influence in influences:
		var influence_range := maxf(float(influence.range), 0.001)
		var distance := absf(progress - float(influence.progress))
		if distance >= influence_range:
			continue
		var weight := 1.0 - smoothstep(influence_range * 0.12, influence_range, distance)
		offset += float(influence.offset) * weight
		var target_width := float(influence.width_scale)
		if target_width >= 1.0:
			width_scale = maxf(width_scale, lerpf(1.0, target_width, weight))
		else:
			width_scale = minf(width_scale, lerpf(1.0, target_width, weight))
		overgrowth = maxf(overgrowth, float(influence.overgrowth) * weight)
	var endpoint_guard := (
		smoothstep(0.0, 0.045, progress)
		* smoothstep(0.0, 0.045, 1.0 - progress)
	)
	return Vector3(
		clampf(offset * endpoint_guard, -125.0, 125.0),
		clampf(width_scale, 0.68, 1.16),
		clampf(overgrowth, 0.0, 0.70)
	)


func _distance_to_raw_route(point: Vector2, route: Dictionary) -> Vector2:
	var closest_distance := INF
	var closest_progress := 0.0
	var previous := Vector2(route.start)
	for segment_index in range(1, ROUTE_SEGMENTS + 1):
		var segment_progress := float(segment_index) / float(ROUTE_SEGMENTS)
		var current := _raw_route_point(route, segment_progress)
		var segment_vector := current - previous
		var segment_length_squared := segment_vector.length_squared()
		var local_progress := 0.0
		if segment_length_squared > 0.001:
			local_progress = clampf(
				(point - previous).dot(segment_vector) / segment_length_squared, 0.0, 1.0
			)
		var closest_point := previous + segment_vector * local_progress
		var distance := point.distance_to(closest_point)
		if distance < closest_distance:
			closest_distance = distance
			closest_progress = (float(segment_index - 1) + local_progress) / float(ROUTE_SEGMENTS)
		previous = current
	return Vector2(closest_distance, closest_progress)


func _distance_to_route(point: Vector2, route: Dictionary) -> Vector2:
	var closest_distance := INF
	var closest_progress := 0.0
	var visual_points: Array = route.get("visual_points", [])
	var previous := (
		Vector2(visual_points[0])
		if visual_points.size() == ROUTE_SEGMENTS + 1
		else Vector2(route.start)
	)
	for segment_index in range(1, ROUTE_SEGMENTS + 1):
		var current := (
			Vector2(visual_points[segment_index])
			if visual_points.size() == ROUTE_SEGMENTS + 1
			else _raw_route_point(route, float(segment_index) / float(ROUTE_SEGMENTS))
		)
		var segment_vector := current - previous
		var segment_length_squared := segment_vector.length_squared()
		var local_progress := 0.0
		if segment_length_squared > 0.001:
			local_progress = clampf(
				(point - previous).dot(segment_vector) / segment_length_squared, 0.0, 1.0
			)
		var closest_point := previous + segment_vector * local_progress
		var distance := point.distance_to(closest_point)
		if distance < closest_distance:
			closest_distance = distance
			closest_progress = (float(segment_index - 1) + local_progress) / float(ROUTE_SEGMENTS)
		previous = current
	return Vector2(closest_distance, closest_progress)


func _stamp_environment_aprons(image: Image) -> void:
	apron_count = 0
	for index in range(world.landmark_positions.size()):
		var landmark_position := Vector2(world.landmark_positions[index])
		var radius := Vector2(520.0, 360.0)
		var strengths := Vector3(0.44, 0.34, 0.78)
		if index == 1:
			radius = Vector2(455.0, 320.0)
			strengths = Vector3(0.54, 0.26, 0.42)
		elif index == 2:
			radius = Vector2(575.0, 395.0)
			strengths = Vector3(0.38, 0.39, 0.84)
		elif index == 3:
			radius = Vector2(490.0, 345.0)
			strengths = Vector3(0.52, 0.30, 0.55)
		_stamp_apron(
			image, landmark_position, radius, strengths.z, strengths.x, strengths.y
		)
	for index in range(world.obstacles.get_child_count()):
		var obstacle := world.obstacles.get_child(index) as Node2D
		if not is_instance_valid(obstacle):
			continue
		var is_stone := index >= 26
		var radius := Vector2(225.0, 145.0) if is_stone else Vector2(285.0, 195.0)
		_stamp_apron(
			image, obstacle.position, radius,
			0.40 if is_stone else 0.64,
			0.43 if is_stone else 0.36,
			0.24 if is_stone else 0.34
		)


func _stamp_apron(
	image: Image, center: Vector2, radius: Vector2, rooted_strength: float,
	soil_strength: float, litter_strength: float
) -> void:
	var minimum := _world_to_pixel(center - radius)
	var maximum := _world_to_pixel(center + radius)
	var minimum_x := clampi(floori(minimum.x), 0, TERRAIN_MAP_RESOLUTION.x - 1)
	var minimum_y := clampi(floori(minimum.y), 0, TERRAIN_MAP_RESOLUTION.y - 1)
	var maximum_x := clampi(ceili(maximum.x), 0, TERRAIN_MAP_RESOLUTION.x - 1)
	var maximum_y := clampi(ceili(maximum.y), 0, TERRAIN_MAP_RESOLUTION.y - 1)
	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var world_position := _pixel_to_world(Vector2(x + 0.5, y + 0.5))
			var normalized := (world_position - center) / radius
			var angle := atan2(normalized.y, normalized.x)
			var phase := center.x * 0.0137 + center.y * 0.0091
			var edge_variation := (
				1.0
				+ sin(angle * 3.0 + phase) * 0.085
				+ sin(angle * 7.0 - phase * 0.63) * 0.045
			)
			var ellipse_distance := normalized.length() / edge_variation
			if ellipse_distance >= 1.0:
				continue
			var falloff := 1.0 - smoothstep(0.18, 1.0, ellipse_distance)
			var current := image.get_pixel(x, y)
			image.set_pixel(
				x, y,
				Color(
					maxf(current.r, soil_strength * falloff),
					maxf(current.g, litter_strength * falloff),
					maxf(current.b, rooted_strength * falloff),
					current.a
				)
			)
	apron_count += 1


func _stamp_dense_connections(image: Image) -> void:
	dense_bridge_count = 0
	if _dense_group_positions.size() < 2:
		return
	for index in range(1, _dense_group_positions.size()):
		_stamp_ground_bridge(
			image, _dense_group_positions[0], _dense_group_positions[index],
			235.0 + float(index % 2) * 28.0, 0.44, 0.36, 0.58
		)
		dense_bridge_count += 1


func _stamp_ground_bridge(
	image: Image, start: Vector2, finish: Vector2, width: float,
	soil_strength: float, litter_strength: float, rooted_strength: float
) -> void:
	var margin := Vector2.ONE * (width * 1.35)
	var minimum := _world_to_pixel(start.min(finish) - margin)
	var maximum := _world_to_pixel(start.max(finish) + margin)
	var minimum_x := clampi(floori(minimum.x), 0, TERRAIN_MAP_RESOLUTION.x - 1)
	var minimum_y := clampi(floori(minimum.y), 0, TERRAIN_MAP_RESOLUTION.y - 1)
	var maximum_x := clampi(ceili(maximum.x), 0, TERRAIN_MAP_RESOLUTION.x - 1)
	var maximum_y := clampi(ceili(maximum.y), 0, TERRAIN_MAP_RESOLUTION.y - 1)
	var segment := finish - start
	var length_squared := maxf(segment.length_squared(), 0.001)
	for y in range(minimum_y, maximum_y + 1):
		for x in range(minimum_x, maximum_x + 1):
			var world_position := _pixel_to_world(Vector2(x + 0.5, y + 0.5))
			var progress := clampf((world_position - start).dot(segment) / length_squared, 0.0, 1.0)
			var closest := start + segment * progress
			var variation := 1.0 + sin(progress * TAU * 3.0 + start.x * 0.01) * 0.13
			var distance := world_position.distance_to(closest)
			if distance >= width * variation:
				continue
			var falloff := 1.0 - smoothstep(width * 0.20, width * variation, distance)
			var current := image.get_pixel(x, y)
			image.set_pixel(
				x, y,
				Color(
					maxf(current.r, soil_strength * falloff),
					maxf(current.g, litter_strength * falloff),
					maxf(current.b, rooted_strength * falloff),
					current.a
				)
			)


func _world_to_pixel(world_position: Vector2) -> Vector2:
	return (
		(world_position - TERRAIN_MAP_ORIGIN) / TERRAIN_MAP_SIZE
		* Vector2(TERRAIN_MAP_RESOLUTION)
	)


func _pixel_to_world(pixel_position: Vector2) -> Vector2:
	return (
		TERRAIN_MAP_ORIGIN
		+ pixel_position / Vector2(TERRAIN_MAP_RESOLUTION) * TERRAIN_MAP_SIZE
	)


func _cubic_bezier(
	start: Vector2, control_a: Vector2, control_b: Vector2, finish: Vector2, progress: float
) -> Vector2:
	var inverse := 1.0 - progress
	return (
		start * inverse * inverse * inverse
		+ control_a * 3.0 * inverse * inverse * progress
		+ control_b * 3.0 * inverse * progress * progress
		+ finish * progress * progress * progress
	)


func _raw_route_point(route: Dictionary, progress: float) -> Vector2:
	return _cubic_bezier(
		Vector2(route.start), Vector2(route.control_a), Vector2(route.control_b),
		Vector2(route.finish), progress
	)


func _route_point(route: Dictionary, progress: float) -> Vector2:
	var visual_points: Array = route.get("visual_points", [])
	if visual_points.size() != ROUTE_SEGMENTS + 1:
		return _raw_route_point(route, progress)
	var segment_position := clampf(progress, 0.0, 1.0) * float(ROUTE_SEGMENTS)
	var first_index := mini(floori(segment_position), ROUTE_SEGMENTS)
	var second_index := mini(first_index + 1, ROUTE_SEGMENTS)
	var local_progress := segment_position - float(first_index)
	return Vector2(visual_points[first_index]).lerp(
		Vector2(visual_points[second_index]), local_progress
	)


func _create_semantic_composition() -> void:
	_composition_root = Node2D.new()
	_composition_root.name = "ForestSemanticComposition"
	world.add_child(_composition_root)
	_hide_replaced_tree_visuals()
	_create_contact_shadows()
	_create_dense_groves()
	_create_landmark_settlement()
	_create_controlled_lighting()
	_update_semantic_capture_points()


func _select_grove_anchors() -> Array[Vector2]:
	var tree_positions: Array[Vector2] = []
	for index in range(mini(26, world.obstacles.get_child_count())):
		var obstacle := world.obstacles.get_child(index) as Node2D
		if is_instance_valid(obstacle):
			tree_positions.append(obstacle.position)
	if tree_positions.is_empty():
		return []

	var dense_seed := tree_positions[0]
	var dense_nearby_count := -1
	for candidate in tree_positions:
		if candidate.length() < 760.0:
			continue
		var nearby_count := 0
		for other in tree_positions:
			if candidate.distance_to(other) <= 1050.0:
				nearby_count += 1
		if nearby_count > dense_nearby_count:
			dense_nearby_count = nearby_count
			dense_seed = candidate

	var dense_candidates: Array[Dictionary] = []
	for position in tree_positions:
		dense_candidates.append({"position": position, "distance": position.distance_to(dense_seed)})
	dense_candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first.distance) < float(second.distance)
	)
	_dense_group_positions.clear()
	for candidate in dense_candidates:
		if _dense_group_positions.size() >= 3:
			break
		var position := Vector2(candidate.position)
		if position.distance_to(dense_seed) <= 1150.0:
			_dense_group_positions.append(position)

	var selected: Array[Vector2] = _dense_group_positions.duplicate()
	while selected.size() < tree_positions.size():
		var best_position := tree_positions[0]
		var best_clearance := -1.0
		for candidate in tree_positions:
			if _position_near_any(candidate, selected, 1.0):
				continue
			var clearance := INF
			for chosen in selected:
				clearance = minf(clearance, candidate.distance_to(chosen))
			if clearance > best_clearance:
				best_clearance = clearance
				best_position = candidate
		if best_clearance < 0.0:
			break
		selected.append(best_position)
	return selected


func _position_near_any(position: Vector2, positions: Array[Vector2], radius: float) -> bool:
	for candidate in positions:
		if position.distance_to(candidate) <= radius:
			return true
	return false


func _hide_replaced_tree_visuals() -> void:
	var visuals: Array[Dictionary] = world.environment_builder.visual_batcher.visual_instances
	for index in range(visuals.size()):
		var visual: Dictionary = visuals[index]
		if str(visual.source_kind) != "obstacle_tree":
			continue
		if not _position_near_any(Vector2(visual.position), _grove_anchor_positions, 1.0):
			continue
		var color := Color(visual.color)
		color.a = 0.0
		visual.color = color
		visuals[index] = visual


func _create_contact_shadows() -> void:
	var instances: Array[Dictionary] = []
	for index in range(world.obstacles.get_child_count()):
		var obstacle := world.obstacles.get_child(index) as Node2D
		if not is_instance_valid(obstacle):
			continue
		var is_stone := index >= 26
		var is_grove := _position_near_any(obstacle.position, _grove_anchor_positions, 1.0)
		var is_dense_grove := _position_near_any(obstacle.position, _dense_group_positions, 1.0)
		var shadow_size := Vector2(90.0, 28.0) if is_stone else Vector2(132.0, 38.0)
		var shadow_alpha := 0.28 if is_stone else 0.34
		if is_grove:
			shadow_size = Vector2(410.0, 104.0) if is_dense_grove else Vector2(285.0, 76.0)
			shadow_alpha = 0.43 if is_dense_grove else 0.37
		instances.append({
			"position": obstacle.position + Vector2(0.0, 8.0),
			"size": shadow_size,
			"rotation": 0.0,
			"color": Color(0.014, 0.020, 0.024, shadow_alpha),
		})
	for landmark_position in world.landmark_positions:
		instances.append({
			"position": Vector2(landmark_position) + Vector2(0.0, 8.0),
			"size": Vector2(430.0, 105.0),
			"rotation": 0.0,
			"color": Color(0.016, 0.012, 0.026, 0.46),
		})
	var shadow_batch := _create_textured_batch(
		"ForestContactShadows", _create_contact_shadow_texture(), instances, -5, true
	)
	_composition_root.add_child(shadow_batch)


func _create_dense_groves() -> void:
	if _grove_anchor_positions.is_empty():
		return
	var instances := grove_visual_layout()
	var grove_batch := _create_grove_atlas_batch(instances)
	_composition_root.add_child(grove_batch)


func _create_landmark_settlement() -> void:
	if world.landmark_positions.is_empty():
		return
	var scale_value := 0.34
	var backdrop := Sprite2D.new()
	backdrop.name = "ForestRootedLandmarkBackdrop"
	backdrop.texture = ROOT_ALTAR_TEXTURE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.scale = Vector2.ONE * scale_value
	backdrop.position = Vector2(world.landmark_positions[0]) - Vector2(0.0, 355.0) * scale_value
	backdrop.modulate = Color(0.84, 0.89, 0.90, 0.92)
	backdrop.z_index = -3
	_composition_root.add_child(backdrop)


func _create_controlled_lighting() -> void:
	var ambient := CanvasModulate.new()
	ambient.name = "ForestAmbientGrade"
	ambient.color = Color(0.78, 0.84, 0.86, 1.0)
	_composition_root.add_child(ambient)
	var light_texture := _create_light_texture()
	# O altar mantém seu acento funcional. Os demais landmarks influenciam o
	# terreno por máscara e detalhes, evitando multiplicar o custo das luzes 2D.
	if not world.landmark_positions.is_empty():
		_add_light(
			Vector2(world.landmark_positions[0]) + Vector2(0.0, -80.0),
			Color("d15150"), 0.30, 3.2, light_texture
		)


func _add_light(
	position: Vector2, color: Color, energy: float, texture_scale: float, texture: Texture2D
) -> void:
	var light := PointLight2D.new()
	light.position = position
	light.color = color
	light.energy = energy
	light.texture = texture
	light.texture_scale = texture_scale
	light.height = 1.0
	_composition_root.add_child(light)


func _update_semantic_capture_points() -> void:
	_semantic_capture_points = {"OPEN_ARENA": Vector2.ZERO}
	if not _routes.is_empty():
		_semantic_capture_points["NATURAL_CORRIDOR"] = _best_natural_corridor_capture_point()
	if not _dense_group_positions.is_empty():
		var dense_center := Vector2.ZERO
		for position in _dense_group_positions:
			dense_center += position
		_semantic_capture_points["DENSE_REGION"] = dense_center / float(_dense_group_positions.size())
	if not world.landmark_positions.is_empty():
		_semantic_capture_points["LANDMARK_REGION"] = Vector2(world.landmark_positions[0])
	_semantic_capture_points["TRANSITION"] = (
		Vector2(_semantic_capture_points.get("NATURAL_CORRIDOR", Vector2.ZERO))
		+ Vector2(_semantic_capture_points.get("DENSE_REGION", Vector2.ZERO))
	) * 0.5


func _best_natural_corridor_capture_point() -> Vector2:
	var best_position := _route_point(_routes[_routes.size() - 1], 0.52)
	var best_score := -INF
	var blend_image := terrain_blend_map.get_image() if is_instance_valid(terrain_blend_map) else null
	for route in _routes:
		for slot in range(3, 18):
			var progress := float(slot) / 20.0
			var position := _route_point(route, progress)
			var nearest_settlement := INF
			for anchor in _settlement_anchors:
				nearest_settlement = minf(
					nearest_settlement, position.distance_to(Vector2(anchor.position))
				)
			var mud_strength := 0.0
			if blend_image != null:
				var pixel := _world_to_pixel(position)
				mud_strength = blend_image.get_pixel(
					clampi(floori(pixel.x), 0, blend_image.get_width() - 1),
					clampi(floori(pixel.y), 0, blend_image.get_height() - 1)
				).a
			var score := mud_strength * 920.0 + minf(nearest_settlement, 720.0) * 0.52
			if score > best_score:
				best_score = score
				best_position = position
	return best_position


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
		atlas.blit_rect(
			source_image, Rect2i(Vector2i.ZERO, source_size), Vector2i(texture_index * source_size.x, 0)
		)
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
		multimesh.set_instance_transform_2d(
			index, Transform2D(x_axis, y_axis, Vector2(instance.position))
		)
		multimesh.set_instance_color(index, Color(instance.color))
		var texture_index := int(instance.texture_index)
		multimesh.set_instance_custom_data(
			index, Color(float(texture_index) / 3.0, 0.0, 1.0 / 3.0, 1.0)
		)
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
	batch.name = "ForestDenseGroveBatch"
	batch.multimesh = multimesh
	batch.texture = ImageTexture.create_from_image(atlas)
	batch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	batch.material = material
	batch.z_index = -3
	return batch


func _create_textured_batch(
	batch_name: String, texture: Texture2D, instances: Array[Dictionary], z_index: int,
	use_explicit_size := false
) -> MultiMeshInstance2D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = _create_unit_quad_mesh()
	multimesh.instance_count = instances.size()
	multimesh.visible_instance_count = instances.size()
	var source_size := Vector2(texture.get_size())
	for index in range(instances.size()):
		var instance: Dictionary = instances[index]
		var rendered_size := (
			Vector2(instance.get("size", source_size))
			if use_explicit_size else source_size * Vector2(instance.scale)
		)
		var angle := float(instance.get("rotation", 0.0))
		multimesh.set_instance_transform_2d(
			index,
			Transform2D(
				Vector2.RIGHT.rotated(angle) * rendered_size.x,
				Vector2.DOWN.rotated(angle) * rendered_size.y,
				Vector2(instance.position)
			)
		)
		multimesh.set_instance_color(index, Color(instance.color))
	var batch := MultiMeshInstance2D.new()
	batch.name = batch_name
	batch.multimesh = multimesh
	batch.texture = texture
	batch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	batch.z_index = z_index
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


func _create_terrain_material() -> ShaderMaterial:
	if not is_instance_valid(_mirrored_base):
		_mirrored_base = _create_mirrored_texture(BASE_GROUND_TEXTURE)
	if not is_instance_valid(_mirrored_details):
		_mirrored_details = _create_mirrored_texture(GROUND_DETAIL_TEXTURE)
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
	vec4 weights = texture(terrain_blend_map, clamp(blend_uv, vec2(0.0), vec2(1.0))) * inside_map;
	vec4 base = sample_world_material(base_material, terrain_world_position, vec2(0.0));
	vec4 shifted_base = sample_world_material(base_material, terrain_world_position * 0.91, vec2(0.173, 0.291));
	float soil_luma = dot(shifted_base.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 soil_palette = vec3(soil_luma * 1.16 + 0.038, soil_luma * 0.75 + 0.020, soil_luma * 0.53 + 0.010);
	vec4 soil = vec4(mix(shifted_base.rgb, soil_palette, 0.84), 1.0);
	// O barro precisa permanecer terroso depois do CanvasModulate do Bosque.
	// A separação é principalmente de matiz, não uma faixa clara sobre o chão.
	vec3 mud_palette = vec3(soil_luma * 0.88 + 0.076, soil_luma * 0.57 + 0.043, soil_luma * 0.34 + 0.021);
	vec4 mud = vec4(mix(shifted_base.rgb, mud_palette, 0.96), 1.0);
	vec4 detail_a = sample_world_material(integrated_details, terrain_world_position * 2.15, vec2(0.417, 0.119));
	vec4 detail_b = sample_world_material(integrated_details, terrain_world_position * 1.85, vec2(0.067, 0.533));
	float litter_luma = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 litter_palette = vec3(litter_luma * 0.88 + 0.014, litter_luma * 0.84 + 0.013, litter_luma * 0.58 + 0.007);
	vec4 litter = vec4(mix(base.rgb, litter_palette, 0.62), 1.0);
	litter.rgb = mix(litter.rgb, detail_a.rgb * 0.92, detail_a.a * 0.27);
	vec4 rooted = vec4(mix(soil.rgb, litter.rgb, 0.32), 1.0);
	rooted.rgb = mix(rooted.rgb, detail_b.rgb * 0.90, detail_b.a * 0.36);
	vec4 ground = mix(base, soil, weights.r);
	ground = mix(ground, litter, weights.g * (1.0 - weights.r * 0.28));
	ground = mix(ground, rooted, weights.b);
	ground = mix(ground, mud, weights.a);
	COLOR = ground * terrain_vertex_tint;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_material", _mirrored_base)
	material.set_shader_parameter("integrated_details", _mirrored_details)
	material.set_shader_parameter("terrain_blend_map", terrain_blend_map)
	material.set_shader_parameter("terrain_map_origin", TERRAIN_MAP_ORIGIN)
	material.set_shader_parameter("terrain_map_size", TERRAIN_MAP_SIZE)
	return material
