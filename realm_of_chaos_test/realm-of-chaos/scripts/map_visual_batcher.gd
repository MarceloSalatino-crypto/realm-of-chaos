extends RefCounted

const CHUNK_SIZE := 1536.0
const ATLAS_SIZE := Vector2i(2048, 1024)
const ATLAS_PADDING := 2

const SOURCE_DEFINITIONS := [
	{"key": "forest_floor_crater", "path": "res://assets/generated/map_decals_v2/forest/crater.png"},
	{"key": "forest_floor_ritual", "path": "res://assets/generated/map_decals_v2/forest/ritual.png"},
	{"key": "forest_floor_battle", "path": "res://assets/generated/map_decals_v2/forest/battle.png"},
	{"key": "frozen_floor_crater", "path": "res://assets/generated/map_decals_v2/frozen/crater.png"},
	{"key": "frozen_floor_ritual", "path": "res://assets/generated/map_decals_v2/frozen/ritual.png"},
	{"key": "frozen_floor_battle", "path": "res://assets/generated/map_decals_v2/frozen/battle.png"},
	{"key": "cathedral_floor_crater", "path": "res://assets/generated/map_decals_v2/cathedral/crater.png", "remove_light_background": true},
	{"key": "cathedral_floor_ritual", "path": "res://assets/generated/map_decals_v2/cathedral/ritual.png", "remove_light_background": true},
	{"key": "cathedral_floor_battle", "path": "res://assets/generated/map_decals_v2/cathedral/battle.png", "remove_light_background": true},
	{"key": "bush_01", "path": "res://assets/environment/props/bush/bush_01.png"},
	{"key": "bush_02", "path": "res://assets/environment/props/bush/bush_02.png"},
	{"key": "mushroom_03", "path": "res://assets/environment/props/Mushroom/Mushroom_03.png"},
	{"key": "leaf_litter", "path": "res://assets/generated/ground_clutter/leaf_litter.png"},
	{"key": "broken_branches", "path": "res://assets/generated/ground_clutter/broken_branches.png"},
	{"key": "twig_scatter", "path": "res://assets/generated/ground_clutter/twig_scatter.png"},
	{"key": "gravel_scatter", "path": "res://assets/generated/ground_clutter/gravel_scatter.png"},
	{"key": "tree_1", "path": "res://assets/environment/Tree/Tree_1.png"},
	{"key": "tree_2", "path": "res://assets/environment/Tree/Tree_2.png"},
	{"key": "tree_3", "path": "res://assets/environment/Tree/Tree_3.png"},
	{"key": "stone_03", "path": "res://assets/environment/props/little stone/little stone_03.png"},
]

var parent: Node2D
var atlas_texture: ImageTexture
var atlas_regions: Dictionary = {}
var visual_instances: Array[Dictionary] = []
var chunk_nodes: Dictionary = {}
var batch_nodes: Array[MultiMeshInstance2D] = []
var _quad_mesh: ArrayMesh
var _material: ShaderMaterial


func _init(owner_parent: Node2D) -> void:
	parent = owner_parent
	_build_atlas()
	_quad_mesh = _create_quad_mesh()
	_material = _create_material()


func reset() -> void:
	for child in parent.get_children():
		child.free()
	visual_instances.clear()
	chunk_nodes.clear()
	batch_nodes.clear()


func add_visual(
	atlas_key: String, world_position: Vector2, scale_value: Vector2,
	rotation: float, flip_h: bool, color: Color, z_index: int,
	source_kind: String
) -> void:
	var source: Dictionary = atlas_regions.get(atlas_key, {})
	if source.is_empty():
		push_error("Fonte visual ausente no atlas do mapa: " + atlas_key)
		return
	visual_instances.append({
		"atlas_key": atlas_key,
		"position": world_position,
		"scale": scale_value,
		"rotation": rotation,
		"flip_h": flip_h,
		"color": color,
		"z_index": z_index,
		"source_kind": source_kind,
		"source_path": str(source.path),
		"source_size": Vector2(source.size),
		"atlas_region": Color(source.region),
	})


func flush() -> void:
	var grouped: Dictionary = {}
	for visual in visual_instances:
		var chunk := chunk_for_position(Vector2(visual.position))
		var group_key := "%d:%d:%d" % [chunk.x, chunk.y, int(visual.z_index)]
		if not grouped.has(group_key):
			grouped[group_key] = {"chunk": chunk, "z_index": int(visual.z_index), "visuals": []}
		grouped[group_key].visuals.append(visual)
	var keys: Array = grouped.keys()
	keys.sort()
	for group_key in keys:
		_create_batch(grouped[group_key])


func chunk_for_position(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / CHUNK_SIZE), floori(world_position.y / CHUNK_SIZE))


func chunk_count() -> int:
	return chunk_nodes.size()


func batch_count() -> int:
	return batch_nodes.size()


func floor_decal_key(biome_id: String, decal_kind: String) -> String:
	var biome_prefix := "forest"
	if biome_id == "frozen":
		biome_prefix = "frozen"
	elif biome_id == "cathedral":
		biome_prefix = "cathedral"
	return "%s_floor_%s" % [biome_prefix, decal_kind]


func _create_batch(group: Dictionary) -> void:
	var chunk: Vector2i = group.chunk
	chunk_nodes[chunk] = true
	var visuals: Array = group.visuals
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _quad_mesh
	multimesh.instance_count = visuals.size()
	multimesh.visible_instance_count = visuals.size()
	var chunk_origin := Vector2(chunk) * CHUNK_SIZE
	for index in range(visuals.size()):
		var visual: Dictionary = visuals[index]
		var source_size := Vector2(visual.source_size)
		var visual_scale := Vector2(visual.scale)
		if bool(visual.flip_h):
			visual_scale.x *= -1.0
		var angle := float(visual.rotation)
		var x_axis := Vector2.RIGHT.rotated(angle) * source_size.x * visual_scale.x
		var y_axis := Vector2.DOWN.rotated(angle) * source_size.y * visual_scale.y
		var transform := Transform2D(x_axis, y_axis, Vector2(visual.position) - chunk_origin)
		multimesh.set_instance_transform_2d(index, transform)
		multimesh.set_instance_color(index, Color(visual.color))
		multimesh.set_instance_custom_data(index, Color(visual.atlas_region))
	var instance := MultiMeshInstance2D.new()
	instance.name = "DecorationChunk_%d_%d_Layer_%d" % [chunk.x, chunk.y, int(group.z_index)]
	instance.position = chunk_origin
	instance.multimesh = multimesh
	instance.texture = atlas_texture
	instance.material = _material
	instance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	instance.z_index = int(group.z_index)
	parent.add_child(instance)
	batch_nodes.append(instance)


func _build_atlas() -> void:
	var atlas := Image.create(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var cursor := Vector2i(ATLAS_PADDING, ATLAS_PADDING)
	var row_height := 0
	for definition in SOURCE_DEFINITIONS:
		var texture := load(str(definition.path)) as Texture2D
		if not is_instance_valid(texture):
			push_error("Textura do atlas do mapa nao encontrada: " + str(definition.path))
			continue
		var image := texture.get_image()
		if image.is_empty():
			push_error("Textura do atlas do mapa sem imagem: " + str(definition.path))
			continue
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		var source_rect := Rect2i(Vector2i.ZERO, image.get_size())
		if definition.has("rect"):
			source_rect = Rect2i(definition.rect)
		if bool(definition.get("remove_light_background", false)):
			_remove_light_background(image, source_rect)
		var size := source_rect.size
		if cursor.x + size.x + ATLAS_PADDING > ATLAS_SIZE.x:
			cursor.x = ATLAS_PADDING
			cursor.y += row_height + ATLAS_PADDING * 2
			row_height = 0
		if cursor.y + size.y + ATLAS_PADDING > ATLAS_SIZE.y:
			push_error("Atlas do mapa excedeu %dx%d" % [ATLAS_SIZE.x, ATLAS_SIZE.y])
			continue
		atlas.blit_rect(image, source_rect, cursor)
		atlas_regions[str(definition.key)] = {
			"path": str(definition.path),
			"size": size,
			"region": Color(
				float(cursor.x) / float(ATLAS_SIZE.x),
				float(cursor.y) / float(ATLAS_SIZE.y),
				float(size.x) / float(ATLAS_SIZE.x),
				float(size.y) / float(ATLAS_SIZE.y)
			),
		}
		cursor.x += size.x + ATLAS_PADDING * 2
		row_height = maxi(row_height, size.y)
	atlas_texture = ImageTexture.create_from_image(atlas)


func _remove_light_background(image: Image, source_rect: Rect2i) -> void:
	for pixel_y in range(source_rect.position.y, source_rect.end.y):
		for pixel_x in range(source_rect.position.x, source_rect.end.x):
			var pixel := image.get_pixel(pixel_x, pixel_y)
			var brightest := maxf(pixel.r, maxf(pixel.g, pixel.b))
			var darkest := minf(pixel.r, minf(pixel.g, pixel.b))
			if darkest > 0.90 and brightest - darkest < 0.045:
				pixel.a = 0.0
				image.set_pixel(pixel_x, pixel_y, pixel)


func _create_quad_mesh() -> ArrayMesh:
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


func _create_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

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
	return material
