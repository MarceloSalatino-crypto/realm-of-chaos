extends Node

signal transition_state_changed(active: bool)

var _transition_active := false


func is_transitioning() -> bool:
	return _transition_active


func change_scene_to_file(scene_path: String) -> Error:
	if not _acquire():
		return ERR_BUSY
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		release()
		return ERR_FILE_NOT_FOUND
	var tree := get_tree()
	if tree == null:
		release()
		return ERR_UNCONFIGURED
	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		release()
		return error
	_release_after_scene_change.call_deferred()
	return OK


func reload_current_scene() -> Error:
	if not _acquire():
		return ERR_BUSY
	var tree := get_tree()
	if tree == null:
		release()
		return ERR_UNCONFIGURED
	var error := tree.reload_current_scene()
	if error != OK:
		release()
		return error
	_release_after_scene_change.call_deferred()
	return OK


func release() -> void:
	if not _transition_active:
		return
	_transition_active = false
	transition_state_changed.emit(false)


func _acquire() -> bool:
	if _transition_active:
		return false
	_transition_active = true
	transition_state_changed.emit(true)
	return true


func _release_after_scene_change() -> void:
	var tree := get_tree()
	if tree != null:
		await tree.process_frame
	release()
