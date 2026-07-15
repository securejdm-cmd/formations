extends SceneTree
func _initialize():
	var u = load("res://scripts/unit.gd")
	print("unit_load=", u)
	var m = load("res://scripts/magnetism.gd")
	print("mag_load=", m)
	var c = load("res://scripts/charge_combat.gd")
	print("charge_load=", c)
	quit(0)
