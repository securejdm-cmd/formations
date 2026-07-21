extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var C = Engine.get_main_loop().root.get_node("/root/Constants")
	print("CONST_OK=", C.get_float("px_per_meter"))
	quit(0)
