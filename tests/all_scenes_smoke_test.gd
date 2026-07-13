extends SceneTree

## Universal scene smoke — every .tscn must load, instantiate, and survive one frame headless.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var paths: PackedStringArray = PackedStringArray()
	_collect_tscn_files("res://", paths)
	paths.sort()
	var failed := 0
	for path in paths:
		if not _smoke_one_scene(path):
			failed += 1
	if failed > 0:
		push_error("[SceneSmoke] FAIL %d/%d scenes" % [failed, paths.size()])
		quit(1)
		return
	print("[SceneSmoke] PASS %d scenes (load + instantiate + one frame)" % paths.size())
	quit(0)


func _collect_tscn_files(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[SceneSmoke] Cannot open directory: %s" % dir_path)
		return
	for file_name in dir.get_files():
		if file_name.ends_with(".tscn"):
			out.append(dir_path.path_join(file_name))
	for subdir in dir.get_directories():
		if subdir.begins_with("."):
			continue
		_collect_tscn_files(dir_path.path_join(subdir), out)


func _smoke_one_scene(path: String) -> bool:
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("[SceneSmoke] load failed: %s" % path)
		return false
	var instance: Node = packed.instantiate()
	if instance == null:
		push_error("[SceneSmoke] instantiate failed: %s" % path)
		return false
	root.add_child(instance)
	var spins := 0
	while not instance.is_node_ready() and spins < 512:
		OS.delay_usec(16000)
		spins += 1
	if not instance.is_node_ready():
		push_error("[SceneSmoke] not ready after 512 frames: %s" % path)
		instance.free()
		return false
	OS.delay_usec(16000)
	instance.free()
	return true
