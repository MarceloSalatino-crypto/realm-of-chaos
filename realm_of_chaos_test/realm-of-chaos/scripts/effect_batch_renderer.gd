extends Node2D

class EffectEntry:
	var node: Node2D
	var id := 0
	var color := Color.WHITE
	var max_radius := 80.0
	var duration := 0.35
	var filled := false
	var quality := 2


var effect_container: Node2D
var rendering_enabled := false
var _entries: Array[EffectEntry] = []
var _entries_by_id: Dictionary = {}
var _vertices := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _visual_dirty := true
var _cleanup_timer := 0.5
var _container_was_visible := true
var _quality_zero_ring_centers := PackedVector2Array()
var _quality_zero_ring_edges := PackedVector2Array()
var _quality_zero_ring_indices := PackedInt32Array()
var _quality_zero_fill_points := PackedVector2Array()
var _quality_zero_fill_indices := PackedInt32Array()


func setup(container: Node2D) -> void:
	effect_container = container
	name = "EffectBatchRenderer"
	z_index = container.z_index
	z_as_relative = container.z_as_relative
	process_priority = 100
	_prepare_quality_zero_geometry()
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	rendering_enabled = true
	_container_was_visible = effect_container.is_visible_in_tree()
	visible = _container_was_visible
	queue_redraw()


func _process(delta: float) -> void:
	var container_visible := is_instance_valid(effect_container) and effect_container.is_visible_in_tree()
	if container_visible != _container_was_visible:
		_container_was_visible = container_visible
		visible = container_visible
		_visual_dirty = true
	_cleanup_timer -= delta
	if _cleanup_timer <= 0.0:
		_cleanup_timer += 0.5
		_cleanup_invalid_entries()
	if not _visual_dirty:
		return
	_visual_dirty = false
	_rebuild_mesh()
	queue_redraw()


func register_effect(effect: Node2D) -> void:
	if not effect.has_method("effect_batch_data"):
		return
	var effect_id := effect.get_instance_id()
	var entry: EffectEntry = _entries_by_id.get(effect_id)
	if entry == null:
		entry = EffectEntry.new()
		entry.node = effect
		entry.id = effect_id
		_entries.append(entry)
		_entries_by_id[effect_id] = entry
	_update_immutable_entry(entry, effect)
	_mark_visual_dirty()


func update_effect(effect: Node2D) -> void:
	var entry: EffectEntry = _entries_by_id.get(effect.get_instance_id())
	if entry == null:
		register_effect(effect)
		return
	_mark_visual_dirty()


func unregister_effect(effect: Node2D) -> void:
	var effect_id := effect.get_instance_id()
	var entry: EffectEntry = _entries_by_id.get(effect_id)
	if entry == null:
		return
	_entries_by_id.erase(effect_id)
	var index := _entries.find(entry)
	if index >= 0:
		_entries.remove_at(index)
	_mark_visual_dirty()


func _update_immutable_entry(entry: EffectEntry, effect: Node2D) -> void:
	entry.color = effect.effect_color
	entry.max_radius = effect.max_radius
	entry.duration = maxf(effect.duration, 0.0001)
	entry.filled = effect.filled
	entry.quality = clampi(effect.visual_quality, 0, 2)


func _mark_visual_dirty() -> void:
	if rendering_enabled:
		_visual_dirty = true


func _cleanup_invalid_entries() -> void:
	var removed := false
	for index in range(_entries.size() - 1, -1, -1):
		var entry: EffectEntry = _entries[index]
		if not is_instance_valid(entry.node):
			_entries_by_id.erase(entry.id)
			_entries.remove_at(index)
			removed = true
	if removed:
		_mark_visual_dirty()


func _draw() -> void:
	if rendering_enabled and not _vertices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), _indices, _vertices, _colors
		)


func _rebuild_mesh() -> void:
	_vertices = PackedVector2Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()
	if not _container_was_visible:
		return
	var inverse_transform := global_transform.affine_inverse()
	if _rebuild_quality_zero_mesh(inverse_transform):
		return
	for entry in _entries:
		var effect: Node2D = entry.node
		if not is_instance_valid(effect) or effect.get_parent() != effect_container or not effect.visible:
			continue
		var effect_age: float = effect.age
		var progress := clampf(effect_age / entry.duration, 0.0, 1.0)
		var color := entry.color
		color.a *= 1.0 - progress
		var radius := lerpf(entry.max_radius * 0.15, entry.max_radius, progress)
		var quality := entry.quality
		var effect_transform := inverse_transform * effect.global_transform
		if quality == 0:
			if entry.filled:
				var fill_color := color.darkened(0.55)
				fill_color.a = color.a * 0.22
				_append_cached_quality_zero_fill(
					effect_transform, radius * 0.94,
					effect_age * 0.34, fill_color
				)
			_append_cached_quality_zero_ring_pair(
				effect_transform, radius, 3.2,
				effect_age * 0.52, color
			)
			continue
		if entry.filled:
			var fill_color := color.darkened(0.55)
			fill_color.a = color.a * 0.22
			_append_polygon(
				_vertices, _colors, _indices,
				_polygon_points(radius * 0.94, 16 if quality == 2 else 10, effect_age * 0.34),
				fill_color, effect_transform
			)
		if quality == 2:
			_append_segmented_ring_pair(
				_vertices, _colors, _indices, effect_transform,
				radius, 10, 3.2, effect_age * 0.52, color
			)
		else:
			_append_angular_ring_pair(
				_vertices, _colors, _indices, effect_transform,
				radius, 10 if quality == 1 else 8, 3.2, effect_age * 0.52, color
			)


func _rebuild_quality_zero_mesh(inverse_transform: Transform2D) -> bool:
	var visible_count := 0
	var filled_count := 0
	for entry in _entries:
		var effect: Node2D = entry.node
		if not is_instance_valid(effect) or effect.get_parent() != effect_container or not effect.visible:
			continue
		if entry.quality != 0:
			return false
		visible_count += 1
		if entry.filled:
			filled_count += 1
	if visible_count == 0:
		return true

	var ring_vertex_count := _quality_zero_ring_centers.size() * 2
	var ring_index_count := _quality_zero_ring_indices.size()
	var fill_vertex_count := _quality_zero_fill_points.size()
	var fill_index_count := _quality_zero_fill_indices.size()
	var total_vertices := visible_count * ring_vertex_count * 2 + filled_count * fill_vertex_count
	var total_indices := visible_count * ring_index_count * 2 + filled_count * fill_index_count
	_vertices.resize(total_vertices)
	_colors.resize(total_vertices)
	_indices.resize(total_indices)
	var vertex_cursor := 0
	var index_cursor := 0

	for entry in _entries:
		var effect: Node2D = entry.node
		if not is_instance_valid(effect) or effect.get_parent() != effect_container or not effect.visible:
			continue
		var effect_age: float = effect.age
		var progress := clampf(effect_age / entry.duration, 0.0, 1.0)
		var color := entry.color
		color.a *= 1.0 - progress
		var radius := lerpf(entry.max_radius * 0.15, entry.max_radius, progress)
		var effect_transform := inverse_transform * effect.global_transform
		if entry.filled:
			var fill_color := color.darkened(0.55)
			fill_color.a = color.a * 0.22
			var fill_transform := effect_transform * Transform2D(effect_age * 0.34, Vector2.ZERO)
			var fill_base := vertex_cursor
			for point in _quality_zero_fill_points:
				_vertices[vertex_cursor] = fill_transform * (point * radius * 0.94)
				_colors[vertex_cursor] = fill_color
				vertex_cursor += 1
			for local_index in _quality_zero_fill_indices:
				_indices[index_cursor] = fill_base + local_index
				index_cursor += 1

		var ring_transform := effect_transform * Transform2D(effect_age * 0.52, Vector2.ZERO)
		var outline := Color(0.055, 0.025, 0.075, color.a * 0.94)
		for pass_index in range(2):
			var ring_base := vertex_cursor
			var ring_color := outline if pass_index == 0 else color
			var half_width := 3.2 if pass_index == 0 else 1.6
			for point_index in range(_quality_zero_ring_centers.size()):
				var center := _quality_zero_ring_centers[point_index] * radius
				var edge := _quality_zero_ring_edges[point_index] * half_width
				_vertices[vertex_cursor] = ring_transform * (center + edge)
				_colors[vertex_cursor] = ring_color
				vertex_cursor += 1
				_vertices[vertex_cursor] = ring_transform * (center - edge)
				_colors[vertex_cursor] = ring_color
				vertex_cursor += 1
			for local_index in _quality_zero_ring_indices:
				_indices[index_cursor] = ring_base + local_index
				index_cursor += 1
	return true


func _prepare_quality_zero_geometry() -> void:
	var path := _polygon_points(1.0, 8, 0.0)
	path.append(path[0])
	var first_segment_dir := (path[1] - path[0]).normalized()
	var last_segment_dir := (path[path.size() - 1] - path[path.size() - 2]).normalized()
	var previous_segment_dir := Vector2.ZERO
	for index in range(path.size()):
		var is_first := index == 0
		var is_last := index == path.size() - 1
		var segment_dir := previous_segment_dir if is_last else (path[index + 1] - path[index]).normalized()
		if segment_dir.is_zero_approx():
			segment_dir = previous_segment_dir
		if is_first:
			previous_segment_dir = last_segment_dir
		elif is_last:
			previous_segment_dir = first_segment_dir
		_quality_zero_ring_centers.append(path[index])
		_quality_zero_ring_edges.append(_polyline_edge_offset(segment_dir, previous_segment_dir))
		previous_segment_dir = segment_dir
	for segment in range(path.size() - 1):
		var first := segment * 2
		_quality_zero_ring_indices.append(first)
		_quality_zero_ring_indices.append(first + 1)
		_quality_zero_ring_indices.append(first + 2)
		_quality_zero_ring_indices.append(first + 2)
		_quality_zero_ring_indices.append(first + 1)
		_quality_zero_ring_indices.append(first + 3)
	_quality_zero_fill_points = _polygon_points(1.0, 10, 0.0)
	_quality_zero_fill_indices = Geometry2D.triangulate_polygon(_quality_zero_fill_points)


func _append_cached_quality_zero_ring_pair(
	instance_transform: Transform2D, radius: float, width: float, angle_offset: float, color: Color
) -> void:
	var outline := Color(0.055, 0.025, 0.075, color.a * 0.94)
	var rotated_transform := instance_transform * Transform2D(angle_offset, Vector2.ZERO)
	_append_cached_quality_zero_ring(rotated_transform, radius, width + 3.2, outline)
	_append_cached_quality_zero_ring(rotated_transform, radius, width, color)


func _append_cached_quality_zero_ring(
	instance_transform: Transform2D, radius: float, width: float, color: Color
) -> void:
	var base := _vertices.size()
	var half_width := width * 0.5
	for index in range(_quality_zero_ring_centers.size()):
		var center := _quality_zero_ring_centers[index] * radius
		var edge := _quality_zero_ring_edges[index] * half_width
		_vertices.append(instance_transform * (center + edge))
		_vertices.append(instance_transform * (center - edge))
		_colors.append(color)
		_colors.append(color)
	for local_index in _quality_zero_ring_indices:
		_indices.append(base + local_index)


func _append_cached_quality_zero_fill(
	instance_transform: Transform2D, radius: float, angle_offset: float, color: Color
) -> void:
	var rotated_transform := instance_transform * Transform2D(angle_offset, Vector2.ZERO)
	var base := _vertices.size()
	for point in _quality_zero_fill_points:
		_vertices.append(rotated_transform * (point * radius))
		_colors.append(color)
	for local_index in _quality_zero_fill_indices:
		_indices.append(base + local_index)


func _append_segmented_ring_pair(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	instance_transform: Transform2D, radius: float, segment_count: int,
	width: float, angle_offset: float, color: Color
) -> void:
	var segment_angle := TAU / float(segment_count)
	var outline := Color(0.055, 0.025, 0.075, color.a * 0.94)
	for index in range(segment_count):
		var start := angle_offset + segment_angle * index
		var finish := start + segment_angle * 0.67
		var path := PackedVector2Array()
		for point_index in range(5):
			var ratio := float(point_index) / 4.0
			path.append(Vector2.RIGHT.rotated(lerpf(start, finish, ratio)) * radius)
		_append_polyline(vertices, colors, indices, path, outline, width + 3.2, instance_transform)
		_append_polyline(vertices, colors, indices, path, color, width, instance_transform)


func _append_angular_ring_pair(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	instance_transform: Transform2D, radius: float, point_count: int,
	width: float, angle_offset: float, color: Color
) -> void:
	var path := _polygon_points(radius, point_count, angle_offset)
	path.append(path[0])
	var outline := Color(0.055, 0.025, 0.075, color.a * 0.94)
	_append_polyline(vertices, colors, indices, path, outline, width + 3.2, instance_transform)
	_append_polyline(vertices, colors, indices, path, color, width, instance_transform)


func _append_polyline(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	path: PackedVector2Array, color: Color, width: float, instance_transform: Transform2D
) -> void:
	if path.size() < 2:
		return
	var first_segment_dir := Vector2.ZERO
	for index in range(1, path.size()):
		first_segment_dir = (path[index] - path[index - 1]).normalized()
		if not first_segment_dir.is_zero_approx():
			break
	var last_segment_dir := Vector2.ZERO
	for index in range(path.size() - 1, 0, -1):
		last_segment_dir = (path[index] - path[index - 1]).normalized()
		if not last_segment_dir.is_zero_approx():
			break
	var loop := path[0].is_equal_approx(path[path.size() - 1])
	var strip := PackedVector2Array()
	var previous_segment_dir := Vector2.ZERO
	for index in range(path.size()):
		var is_first := index == 0
		var is_last := index == path.size() - 1
		var segment_dir := previous_segment_dir if is_last else (path[index + 1] - path[index]).normalized()
		if segment_dir.is_zero_approx():
			segment_dir = previous_segment_dir
		if is_first and loop:
			previous_segment_dir = last_segment_dir
		elif is_last and loop:
			previous_segment_dir = first_segment_dir
		var base_edge_offset: Vector2
		if is_first and not loop:
			base_edge_offset = first_segment_dir.orthogonal()
		elif is_last and not loop:
			base_edge_offset = last_segment_dir.orthogonal()
		else:
			base_edge_offset = _polyline_edge_offset(segment_dir, previous_segment_dir)
		var edge_offset := base_edge_offset * (width * 0.5)
		strip.append(instance_transform * (path[index] + edge_offset))
		strip.append(instance_transform * (path[index] - edge_offset))
		previous_segment_dir = segment_dir
	var base := vertices.size()
	for point in strip:
		vertices.append(point)
		colors.append(color)
	for segment in range(path.size() - 1):
		var first := base + segment * 2
		indices.append(first)
		indices.append(first + 1)
		indices.append(first + 2)
		indices.append(first + 2)
		indices.append(first + 1)
		indices.append(first + 3)


func _polyline_edge_offset(segment_dir: Vector2, previous_segment_dir: Vector2) -> Vector2:
	var bisector := (
		previous_segment_dir * segment_dir.length()
		- segment_dir * previous_segment_dir.length()
	).normalized()
	var length := 1.0
	var angle := atan2(bisector.cross(previous_segment_dir), bisector.dot(previous_segment_dir))
	var sine := sin(angle)
	if not is_zero_approx(sine) and not segment_dir.is_equal_approx(previous_segment_dir):
		length = clampf(1.0 / sine, -3.0, 3.0)
	else:
		bisector = segment_dir.orthogonal()
	if bisector.is_zero_approx():
		bisector = segment_dir.orthogonal()
	return bisector * length


func _append_polygon(
	vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
	polygon: PackedVector2Array, color: Color, instance_transform: Transform2D
) -> void:
	var polygon_indices := Geometry2D.triangulate_polygon(polygon)
	var base := vertices.size()
	for point in polygon:
		vertices.append(instance_transform * point)
		colors.append(color)
	for index in polygon_indices:
		indices.append(base + index)


func _polygon_points(radius: float, point_count: int, angle_offset: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := angle_offset + TAU * float(index) / float(point_count)
		var edge_scale := 1.0 if index % 2 == 0 else 0.94
		points.append(Vector2.RIGHT.rotated(angle) * radius * edge_scale)
	return points
