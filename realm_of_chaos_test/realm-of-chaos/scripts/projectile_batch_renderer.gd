extends Node2D

const PLAYER := 0
const ENEMY := 1

const ROLE_OUTLINE := 0
const ROLE_SHADOW := 1
const ROLE_MAIN := 2
const ROLE_HIGHLIGHT := 3
const ROLE_DANGER_CORE := 4

const PLAYER_OUTLINE := Color("1b1022")
const ENEMY_OUTLINE := Color("240b18")
const ENEMY_DANGER_CORE := Color("4a071b")

var projectile_container: Node2D
var renderer_kind := PLAYER
var _batches: Dictionary = {}
var _style_layers: Dictionary = {}
var _style_order: Array[String] = []
var _material: ShaderMaterial
var _entries: Array[Dictionary] = []
var _entries_by_id: Dictionary = {}
var rendering_enabled := false


func setup(container: Node2D, kind: int) -> void:
	projectile_container = container
	renderer_kind = kind
	name = "PlayerProjectileBatchRenderer" if kind == PLAYER else "EnemyProjectileBatchRenderer"
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	rendering_enabled = true
	_material = _create_material()
	_build_geometry()
	for style in _style_order:
		_create_batch(style)
	_sync_batches()


func _process(_delta: float) -> void:
	_sync_batches()


func register_projectile(projectile: Node2D) -> void:
	if not projectile.has_method("projectile_batch_style"):
		return
	var projectile_id := projectile.get_instance_id()
	var entry: Dictionary = _entries_by_id.get(projectile_id, {})
	if entry.is_empty():
		entry = {"node": projectile, "id": projectile_id}
		_entries.append(entry)
		_entries_by_id[projectile_id] = entry
	entry.style = str(projectile.projectile_batch_style())
	entry.radius = float(projectile.projectile_batch_radius())
	entry.color = Color(projectile.projectile_batch_color())


func _create_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform vec4 outline_color : source_color;
uniform vec4 danger_core_color : source_color;
uniform float shadow_amount;

void fragment() {
	float role = UV.x;
	vec4 tint = COLOR;
	if (role < 0.5) {
		COLOR = outline_color;
	} else if (role < 1.5) {
		COLOR = vec4(tint.rgb * (1.0 - shadow_amount), tint.a);
	} else if (role < 2.5) {
		COLOR = tint;
	} else if (role < 3.5) {
		COLOR = vec4(mix(tint.rgb, vec3(1.0), 0.42), tint.a);
	} else {
		COLOR = danger_core_color;
	}
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("outline_color", PLAYER_OUTLINE if renderer_kind == PLAYER else ENEMY_OUTLINE)
	shader_material.set_shader_parameter("danger_core_color", ENEMY_DANGER_CORE)
	shader_material.set_shader_parameter("shadow_amount", 0.46 if renderer_kind == PLAYER else 0.48)
	return shader_material


func _build_geometry() -> void:
	if renderer_kind == PLAYER:
		_style_order = ["default", "shadow_small", "shadow", "chaos"]
		_add_player_default()
		_add_player_shadow("shadow_small", 1.0 / 6.0)
		_add_player_shadow("shadow", 0.16)
		_add_player_chaos()
	else:
		_style_order = ["generic", "danger"]
		_add_enemy_generic()
		_add_enemy_danger()


func _add_player_default() -> void:
	_add_layer("default", PackedVector2Array([
		Vector2(1.35, 0.0), Vector2(0.45, 0.62), Vector2(0.0, 1.15),
		Vector2(-0.45, 0.62), Vector2(-1.35, 0.0), Vector2(-0.45, -0.62),
		Vector2(0.0, -1.15), Vector2(0.45, -0.62),
	]), ROLE_OUTLINE)
	_add_layer("default", PackedVector2Array([
		Vector2(1.0, 0.0), Vector2(0.0, 0.78), Vector2(-1.0, 0.0), Vector2(0.0, -0.78),
	]), ROLE_MAIN)
	_add_layer("default", PackedVector2Array([
		Vector2(0.42, 0.0), Vector2(0.0, 0.32), Vector2(-0.42, 0.0), Vector2(0.0, -0.32),
	]), ROLE_HIGHLIGHT)


func _add_player_shadow(style: String, highlight_width: float) -> void:
	_add_layer(style, PackedVector2Array([
		Vector2(-1.65, -0.48), Vector2(0.55, -0.76), Vector2(1.48, 0.0),
		Vector2(0.55, 0.76), Vector2(-1.65, 0.48), Vector2(-1.12, 0.0),
	]), ROLE_OUTLINE)
	_add_layer(style, PackedVector2Array([
		Vector2(-1.35, -0.27), Vector2(0.42, -0.48), Vector2(1.12, 0.0),
		Vector2(0.42, 0.48), Vector2(-1.35, 0.27), Vector2(-0.88, 0.0),
	]), ROLE_MAIN)
	_add_layer(style, _line_polygon(Vector2(-0.82, -0.12), Vector2(0.58, -0.25), highlight_width), ROLE_HIGHLIGHT)


func _add_player_chaos() -> void:
	_add_layer("chaos", PackedVector2Array([
		Vector2(-1.72, -0.46), Vector2(0.30, -0.46), Vector2(1.50, 0.0),
		Vector2(0.30, 0.46), Vector2(-1.72, 0.46), Vector2(-1.25, 0.0),
	]), ROLE_OUTLINE)
	_add_layer("chaos", PackedVector2Array([
		Vector2(-1.42, -0.24), Vector2(0.22, -0.24), Vector2(1.12, 0.0),
		Vector2(0.22, 0.24), Vector2(-1.42, 0.24), Vector2(-1.08, 0.0),
	]), ROLE_SHADOW)
	_add_layer("chaos", PackedVector2Array([
		Vector2(-0.72, -0.22), Vector2(0.22, -0.22), Vector2(0.88, 0.0),
		Vector2(0.22, 0.0), Vector2(-0.72, 0.0),
	]), ROLE_MAIN)
	_add_layer("chaos", _line_polygon(Vector2(-1.25, 0.0), Vector2(-2.15, 0.0), 0.42), ROLE_OUTLINE)
	_add_layer("chaos", _line_polygon(Vector2(-1.28, 0.0), Vector2(-2.08, 0.0), 0.18), ROLE_MAIN)


func _add_enemy_generic() -> void:
	_add_layer("generic", PackedVector2Array([
		Vector2(0.0, -1.32), Vector2(0.96, 0.0), Vector2(0.0, 1.32), Vector2(-0.96, 0.0),
	]), ROLE_OUTLINE)
	_add_layer("generic", PackedVector2Array([
		Vector2(0.0, -1.0), Vector2(0.68, 0.0), Vector2(0.0, 1.0), Vector2(-0.68, 0.0),
	]), ROLE_SHADOW)
	_add_layer("generic", PackedVector2Array([
		Vector2(0.0, -0.78), Vector2(0.46, 0.0), Vector2(0.0, 0.18), Vector2(-0.46, 0.0),
	]), ROLE_MAIN)
	_add_layer("generic", PackedVector2Array([
		Vector2(0.0, -0.36), Vector2(0.20, 0.0), Vector2(0.0, 0.20), Vector2(-0.20, 0.0),
	]), ROLE_HIGHLIGHT)


func _add_enemy_danger() -> void:
	var outline_points := PackedVector2Array()
	var blade_points := PackedVector2Array()
	for index in range(16):
		var angle := -PI * 0.5 + TAU * float(index) / 16.0
		var is_tip := index % 2 == 0
		outline_points.append(Vector2.RIGHT.rotated(angle) * (1.34 if is_tip else 0.62))
		blade_points.append(Vector2.RIGHT.rotated(angle) * (1.08 if is_tip else 0.48))
	_add_layer("danger", outline_points, ROLE_OUTLINE)
	_add_layer("danger", blade_points, ROLE_MAIN)
	var core_points := PackedVector2Array()
	for index in range(32):
		core_points.append(Vector2.RIGHT.rotated(TAU * float(index) / 32.0) * 0.36)
	_add_layer("danger", core_points, ROLE_DANGER_CORE)
	_add_layer("danger", PackedVector2Array([
		Vector2(-0.06, -0.28), Vector2(0.22, -0.02), Vector2(-0.06, 0.20), Vector2(-0.28, -0.02),
	]), ROLE_HIGHLIGHT)


func _add_layer(style: String, polygon: PackedVector2Array, role: int) -> void:
	var layers: Array = _style_layers.get(style, [])
	layers.append({"polygon": polygon, "role": role})
	_style_layers[style] = layers


func _create_batch(style: String) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = _combined_mesh(_style_layers.get(style, []))
	var instance := MultiMeshInstance2D.new()
	instance.name = style
	instance.multimesh = multimesh
	instance.material = _material
	instance.visible = false
	add_child(instance)
	_batches[style] = {
		"instance": instance,
		"multimesh": multimesh,
		"capacity": 0,
		"buffer": PackedFloat32Array(),
	}


func _combined_mesh(layers: Array) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for layer in layers:
		var polygon: PackedVector2Array = layer.polygon
		var polygon_indices := Geometry2D.triangulate_polygon(polygon)
		var offset := vertices.size()
		vertices.append_array(polygon)
		for _point in polygon:
			uvs.append(Vector2(float(layer.role), 0.0))
		for index in polygon_indices:
			indices.append(offset + index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _line_polygon(start: Vector2, finish: Vector2, width: float) -> PackedVector2Array:
	var normal := (finish - start).normalized().orthogonal() * width * 0.5
	return PackedVector2Array([start + normal, finish + normal, finish - normal, start - normal])


func _sync_batches() -> void:
	if not is_instance_valid(projectile_container) or not projectile_container.is_visible_in_tree():
		_hide_all()
		return
	var grouped: Dictionary = {}
	for style in _style_order:
		grouped[style] = []
	for index in range(_entries.size() - 1, -1, -1):
		var entry: Dictionary = _entries[index]
		var projectile: Node = entry.node
		if not is_instance_valid(projectile):
			_entries_by_id.erase(entry.id)
			_entries.remove_at(index)
	for entry in _entries:
		var projectile: Node = entry.node
		if projectile.get_parent() != projectile_container:
			continue
		if not projectile is CanvasItem or not projectile.visible:
			continue
		var style := str(entry.style)
		if grouped.has(style):
			grouped[style].append(entry)
	var inverse_transform := global_transform.affine_inverse()
	for style in _style_order:
		_sync_style(style, grouped[style], inverse_transform)


func _sync_style(style: String, projectiles: Array, inverse_transform: Transform2D) -> void:
	var batch: Dictionary = _batches[style]
	var count := projectiles.size()
	_ensure_capacity(batch, count)
	var multimesh: MultiMesh = batch.multimesh
	var instance: MultiMeshInstance2D = batch.instance
	instance.visible = count > 0
	if count == 0:
		multimesh.visible_instance_count = 0
		return
	var buffer: PackedFloat32Array = batch.buffer
	for index in range(count):
		var entry: Dictionary = projectiles[index]
		var projectile: Node2D = entry.node
		var radius := float(entry.radius)
		var relative_transform := inverse_transform * projectile.global_transform
		relative_transform = relative_transform.scaled_local(Vector2(radius, radius))
		var color: Color = entry.color
		var offset := index * 12
		buffer[offset] = relative_transform.x.x
		buffer[offset + 1] = relative_transform.y.x
		buffer[offset + 2] = 0.0
		buffer[offset + 3] = relative_transform.origin.x
		buffer[offset + 4] = relative_transform.x.y
		buffer[offset + 5] = relative_transform.y.y
		buffer[offset + 6] = 0.0
		buffer[offset + 7] = relative_transform.origin.y
		buffer[offset + 8] = color.r
		buffer[offset + 9] = color.g
		buffer[offset + 10] = color.b
		buffer[offset + 11] = color.a
	multimesh.buffer = buffer
	multimesh.visible_instance_count = count


func _ensure_capacity(batch: Dictionary, required: int) -> void:
	if int(batch.capacity) >= required:
		return
	var capacity := maxi(8, int(batch.capacity))
	while capacity < required:
		capacity *= 2
	var multimesh: MultiMesh = batch.multimesh
	multimesh.instance_count = capacity
	batch.capacity = capacity
	var buffer := PackedFloat32Array()
	buffer.resize(capacity * 12)
	batch.buffer = buffer


func _hide_all() -> void:
	for style in _style_order:
		var batch: Dictionary = _batches[style]
		var multimesh: MultiMesh = batch.multimesh
		multimesh.visible_instance_count = 0
		var instance: MultiMeshInstance2D = batch.instance
		instance.visible = false
