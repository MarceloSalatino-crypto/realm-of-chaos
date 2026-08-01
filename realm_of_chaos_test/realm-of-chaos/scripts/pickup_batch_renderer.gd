extends Node2D

const ROLE_OUTLINE := 0
const ROLE_SHADOW := 1
const ROLE_MAIN := 2
const ROLE_HIGHLIGHT := 3

const STYLE_XP_COMMON := "xp_common"
const STYLE_XP_HIGH := "xp_high"
const STYLE_HEAL := "heal"

var pickup_container: Node2D
var rendering_enabled := false
var _style_order: Array[String] = [STYLE_XP_COMMON, STYLE_XP_HIGH, STYLE_HEAL]
var _style_layers: Dictionary = {}
var _style_colors: Dictionary = {}
var _batches: Dictionary = {}
var _entries: Array[Dictionary] = []
var _entries_by_id: Dictionary = {}
var _visible_entries: Array[Dictionary] = []
var _cleanup_timer := 0.5
var _layout_dirty := true
var _container_was_visible := true


func setup(container: Node2D) -> void:
	pickup_container = container
	name = "PickupBatchRenderer"
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	rendering_enabled = true
	_build_geometry()
	for style in _style_order:
		_create_batch(style)
	_sync_batches()


func _process(_delta: float) -> void:
	var container_visible := is_instance_valid(pickup_container) and pickup_container.is_visible_in_tree()
	if container_visible != _container_was_visible:
		_container_was_visible = container_visible
		_layout_dirty = true
	_cleanup_timer -= _delta
	if _cleanup_timer <= 0.0:
		_cleanup_timer += 0.5
		_cleanup_invalid_entries()
	if _layout_dirty:
		_sync_batches()
		_layout_dirty = false


func register_pickup(pickup: Node2D) -> void:
	if not pickup.has_method("pickup_batch_style"):
		return
	var pickup_id := pickup.get_instance_id()
	var entry: Dictionary = _entries_by_id.get(pickup_id, {})
	if entry.is_empty():
		entry = {"node": pickup, "id": pickup_id, "visible": false}
		_entries.append(entry)
		_entries_by_id[pickup_id] = entry
	var style := str(pickup.pickup_batch_style())
	var bob := float(pickup.pickup_batch_bob())
	var previous_style := str(entry.get("style", ""))
	var style_changed := previous_style != style
	var bob_changed := not entry.has("bob") or not is_equal_approx(float(entry.bob), bob)
	entry.style = style
	entry.bob = bob
	_set_entry_visible(entry, bool(pickup.get("visual_on_screen")))
	if bool(entry.visible):
		if style_changed:
			_layout_dirty = true
		elif bob_changed:
			_update_entry_transform(entry)


func set_pickup_visible(pickup: Node2D, is_visible: bool) -> void:
	var entry: Dictionary = _entries_by_id.get(pickup.get_instance_id(), {})
	if entry.is_empty():
		register_pickup(pickup)
		entry = _entries_by_id.get(pickup.get_instance_id(), {})
	if not entry.is_empty():
		_set_entry_visible(entry, is_visible)


func update_pickup_bob(pickup: Node2D, bob: float) -> void:
	var entry: Dictionary = _entries_by_id.get(pickup.get_instance_id(), {})
	if entry.is_empty():
		register_pickup(pickup)
		return
	if is_equal_approx(float(entry.bob), bob):
		return
	entry.bob = bob
	if bool(entry.visible):
		_update_entry_transform(entry)


func mark_pickup_transform_dirty(pickup: Node2D) -> void:
	var entry: Dictionary = _entries_by_id.get(pickup.get_instance_id(), {})
	if not entry.is_empty() and bool(entry.visible):
		_update_entry_transform(entry)


func _set_entry_visible(entry: Dictionary, is_visible: bool) -> void:
	if bool(entry.visible) == is_visible:
		return
	entry.visible = is_visible
	_layout_dirty = true
	if is_visible:
		_visible_entries.append(entry)
	else:
		var visible_index := _visible_entries.find(entry)
		if visible_index >= 0:
			_visible_entries.remove_at(visible_index)


func _cleanup_invalid_entries() -> void:
	var removed_visible := false
	for index in range(_visible_entries.size() - 1, -1, -1):
		var entry: Dictionary = _visible_entries[index]
		if not is_instance_valid(entry.node):
			_visible_entries.remove_at(index)
			removed_visible = true
	for index in range(_entries.size() - 1, -1, -1):
		var entry: Dictionary = _entries[index]
		if not is_instance_valid(entry.node):
			_entries_by_id.erase(entry.id)
			_entries.remove_at(index)
	if removed_visible:
		_layout_dirty = true


func _build_geometry() -> void:
	_add_xp_geometry(STYLE_XP_COMMON, 10.5)
	_add_xp_geometry(STYLE_XP_HIGH, 12.0)
	_add_heal_geometry()
	var common := Color("83ed63")
	var high := Color("ffd45f")
	_style_colors[STYLE_XP_COMMON] = [Color("12220f"), common.darkened(0.14), common, Color("dcffb2")]
	_style_colors[STYLE_XP_HIGH] = [Color("2c210b"), high.darkened(0.14), high, Color("fff2ad")]
	_style_colors[STYLE_HEAL] = [Color("240d18"), Color("d93652"), Color("a61f3e"), Color("fff3e8")]


func _add_xp_geometry(style: String, size: float) -> void:
	_add_layer(style, PackedVector2Array([
		Vector2(0.0, -size), Vector2(size * 0.66, -size * 0.32),
		Vector2(size * 0.52, size * 0.54), Vector2(0.0, size),
		Vector2(-size * 0.52, size * 0.54), Vector2(-size * 0.66, -size * 0.32),
	]), ROLE_OUTLINE)
	_add_layer(style, PackedVector2Array([
		Vector2(0.0, -size * 0.72), Vector2(size * 0.44, -size * 0.22),
		Vector2(size * 0.35, size * 0.38), Vector2(0.0, size * 0.72),
		Vector2(-size * 0.35, size * 0.38), Vector2(-size * 0.44, -size * 0.22),
	]), ROLE_SHADOW)
	_add_layer(style, PackedVector2Array([
		Vector2(0.0, -size * 0.68), Vector2(size * 0.40, -size * 0.20), Vector2(0.0, size * 0.62),
	]), ROLE_MAIN)
	_add_layer(
		style,
		_line_polygon(Vector2(-size * 0.18, -size * 0.38), Vector2(-size * 0.18, size * 0.28), 1.6),
		ROLE_HIGHLIGHT
	)


func _add_heal_geometry() -> void:
	_add_layer(STYLE_HEAL, PackedVector2Array([
		Vector2(0.0, -13.0), Vector2(9.0, -9.0), Vector2(12.0, -2.0), Vector2(10.0, 8.0),
		Vector2(0.0, 14.0), Vector2(-10.0, 8.0), Vector2(-12.0, -2.0), Vector2(-9.0, -9.0),
	]), ROLE_OUTLINE)
	_add_layer(STYLE_HEAL, PackedVector2Array([
		Vector2(0.0, -10.0), Vector2(6.5, -7.0), Vector2(8.5, -1.5), Vector2(7.0, 5.5),
		Vector2(0.0, 10.5), Vector2(-7.0, 5.5), Vector2(-8.5, -1.5), Vector2(-6.5, -7.0),
	]), ROLE_SHADOW)
	_add_layer(STYLE_HEAL, PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(7.0, -1.5), Vector2(6.0, 4.8), Vector2(0.0, 9.0),
	]), ROLE_MAIN)
	_add_layer(STYLE_HEAL, _rect_polygon(Rect2(Vector2(-3.0, -8.0), Vector2(6.0, 16.0))), ROLE_OUTLINE)
	_add_layer(STYLE_HEAL, _rect_polygon(Rect2(Vector2(-8.0, -3.0), Vector2(16.0, 6.0))), ROLE_OUTLINE)
	_add_layer(STYLE_HEAL, _rect_polygon(Rect2(Vector2(-1.75, -6.5), Vector2(3.5, 13.0))), ROLE_HIGHLIGHT)
	_add_layer(STYLE_HEAL, _rect_polygon(Rect2(Vector2(-6.5, -1.75), Vector2(13.0, 3.5))), ROLE_HIGHLIGHT)


func _add_layer(style: String, polygon: PackedVector2Array, role: int) -> void:
	var layers: Array = _style_layers.get(style, [])
	layers.append({"polygon": polygon, "role": role})
	_style_layers[style] = layers


func _create_batch(style: String) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = _combined_mesh(_style_layers.get(style, []))
	var instance := MultiMeshInstance2D.new()
	instance.name = style
	instance.multimesh = multimesh
	instance.material = _create_material(_style_colors[style])
	instance.visible = false
	add_child(instance)
	_batches[style] = {
		"instance": instance,
		"multimesh": multimesh,
		"capacity": 0,
		"buffer": PackedFloat32Array(),
	}


func _create_material(colors: Array) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform vec4 layer_0 : source_color;
uniform vec4 layer_1 : source_color;
uniform vec4 layer_2 : source_color;
uniform vec4 layer_3 : source_color;

void fragment() {
	float role = UV.x;
	if (role < 0.5) {
		COLOR = layer_0;
	} else if (role < 1.5) {
		COLOR = layer_1;
	} else if (role < 2.5) {
		COLOR = layer_2;
	} else {
		COLOR = layer_3;
	}
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	for index in range(4):
		material.set_shader_parameter("layer_%d" % index, colors[index])
	return material


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


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.end,
		rect.position + Vector2(0.0, rect.size.y),
	])


func _sync_batches() -> void:
	if not is_instance_valid(pickup_container) or not pickup_container.is_visible_in_tree():
		_hide_all()
		return
	var grouped: Dictionary = {}
	for style in _style_order:
		grouped[style] = []
	for index in range(_visible_entries.size() - 1, -1, -1):
		var entry: Dictionary = _visible_entries[index]
		if not is_instance_valid(entry.node):
			_visible_entries.remove_at(index)
			continue
		var pickup: Node = entry.node
		if pickup.get_parent() != pickup_container:
			entry.visible = false
			_visible_entries.remove_at(index)
			continue
		if not pickup is CanvasItem or not pickup.visible:
			continue
		var style := str(entry.style)
		if grouped.has(style):
			grouped[style].append(entry)
	var inverse_transform := global_transform.affine_inverse()
	for style in _style_order:
		_sync_style(style, grouped[style], inverse_transform)


func _sync_style(style: String, pickups: Array, inverse_transform: Transform2D) -> void:
	var batch: Dictionary = _batches[style]
	var count := pickups.size()
	_ensure_capacity(batch, count)
	var multimesh: MultiMesh = batch.multimesh
	var instance: MultiMeshInstance2D = batch.instance
	instance.visible = count > 0
	if count == 0:
		multimesh.visible_instance_count = 0
		return
	var buffer: PackedFloat32Array = batch.buffer
	for index in range(count):
		var entry: Dictionary = pickups[index]
		var pickup: Node2D = entry.node
		entry.slot = index
		var relative_transform := inverse_transform * pickup.global_transform
		relative_transform.origin += relative_transform.basis_xform(Vector2(0.0, float(entry.bob)))
		var offset := index * 8
		buffer[offset] = relative_transform.x.x
		buffer[offset + 1] = relative_transform.y.x
		buffer[offset + 2] = 0.0
		buffer[offset + 3] = relative_transform.origin.x
		buffer[offset + 4] = relative_transform.x.y
		buffer[offset + 5] = relative_transform.y.y
		buffer[offset + 6] = 0.0
		buffer[offset + 7] = relative_transform.origin.y
	multimesh.buffer = buffer
	multimesh.visible_instance_count = count


func _update_entry_transform(entry: Dictionary) -> void:
	if _layout_dirty or not rendering_enabled or not bool(entry.visible):
		return
	var pickup: Node2D = entry.node
	if not is_instance_valid(pickup) or pickup.get_parent() != pickup_container:
		return
	var style := str(entry.style)
	if not _batches.has(style) or not entry.has("slot"):
		return
	var batch: Dictionary = _batches[style]
	var slot := int(entry.slot)
	var multimesh: MultiMesh = batch.multimesh
	if slot < 0 or slot >= multimesh.visible_instance_count:
		return
	var relative_transform := global_transform.affine_inverse() * pickup.global_transform
	relative_transform.origin += relative_transform.basis_xform(Vector2(0.0, float(entry.bob)))
	multimesh.set_instance_transform_2d(slot, relative_transform)


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
	buffer.resize(capacity * 8)
	batch.buffer = buffer


func _hide_all() -> void:
	for style in _style_order:
		var batch: Dictionary = _batches[style]
		var multimesh: MultiMesh = batch.multimesh
		multimesh.visible_instance_count = 0
		var instance: MultiMeshInstance2D = batch.instance
		instance.visible = false
