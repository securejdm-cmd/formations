class_name Scenario40Midbattle
extends RefCounted

## WO-029b: plain-data midbattle script for S40. Safe to invoke from the sim worker.

var phase: String = "approach"


func on_pre_tick(core) -> void:
	if phase == "approach" and int(core.first_contact_tick) >= 0:
		phase = "commit"
	if phase == "commit" and int(core.sim_tick_count) > int(core.first_contact_tick) + 80:
		var blue_cav = null
		var red_cav = null
		for u in core.units:
			if u == null:
				continue
			if str(u.unit_id) == "blue_cav":
				blue_cav = u
			elif str(u.unit_id) == "red_cav":
				red_cav = u
		if blue_cav != null and blue_cav.get_state() == Unit.State.HOLD:
			var target: Vector2 = red_cav.position if red_cav != null else Vector2(-100, 0)
			blue_cav.set_march_to(target)
		phase = "committed"
