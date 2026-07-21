class_name DeploymentPresets
extends RefCounted

## WO-034 — placement macros only. Write the same placement dicts the UI edits.
## Presets: LINE, COLUMN, REFUSED_FLANK.

const _BattleData := preload("res://scripts/battle_scenario_data.gd")


static func apply(battle: Dictionary, preset_name: String) -> Array:
	var name_u := preset_name.to_upper()
	match name_u:
		"LINE":
			return _line(battle)
		"COLUMN":
			return _column(battle)
		"REFUSED_FLANK":
			return _refused_flank(battle)
		_:
			push_error("Unknown deployment preset: %s" % preset_name)
			return []


static func shipped_names() -> PackedStringArray:
	return PackedStringArray(["LINE", "COLUMN", "REFUSED_FLANK"])


static func _roster_ids(battle: Dictionary) -> Array:
	var ids: Array = []
	for e in battle.get("roster", []):
		if typeof(e) == TYPE_DICTIONARY:
			ids.append(str(e.get("id")))
	return ids


static func _make_placement(battle: Dictionary, uid: String, pos: Vector2, facing: Vector2) -> Dictionary:
	var roster := _BattleData.roster_entry(battle, uid)
	var defs := _BattleData.profile_defaults(str(roster.get("profile", "test_infantry")))
	var front: float = float(defs.formation_frontage_m)
	var depth: float = float(defs.formation_depth_m)
	var snapped := _BattleData.snap_point_m(battle, pos)
	return {
		"id": uid,
		"position_m": {"x": snapped.x, "y": snapped.y},
		"facing": _BattleData.facing_to_dict(facing),
		"formation_frontage_m": front,
		"formation_depth_m": depth,
		"posture": "normal",
	}


static func _zone_center(battle: Dictionary) -> Vector2:
	var z := _BattleData.zone_rect_m(battle, str(battle.get("player_team", "blue")))
	return z.get_center()


static func default_facing(battle: Dictionary) -> Vector2:
	## Face toward the enemy zone center.
	var team := str(battle.get("player_team", "blue"))
	var enemy := "red" if team == "blue" else "blue"
	var my_c := _BattleData.zone_rect_m(battle, team).get_center()
	var en_c := _BattleData.zone_rect_m(battle, enemy).get_center()
	var d := en_c - my_c
	if d.length_squared() < 0.0001:
		return Vector2.RIGHT if team == "blue" else Vector2.LEFT
	return d.normalized()


static func _default_facing(battle: Dictionary) -> Vector2:
	return default_facing(battle)


static func _line(battle: Dictionary) -> Array:
	## All units abreast across zone, facing enemy.
	var ids := _roster_ids(battle)
	var facing := _default_facing(battle)
	var zone := _BattleData.zone_rect_m(battle, str(battle.get("player_team", "blue")))
	var n: int = maxi(ids.size(), 1)
	var gap: float = zone.size.y / float(n + 1)
	var x: float = zone.position.x + zone.size.x * 0.55
	var out: Array = []
	for i in range(ids.size()):
		var y: float = zone.position.y + gap * float(i + 1)
		out.append(_make_placement(battle, str(ids[i]), Vector2(x, y), facing))
	return out


static func _column(battle: Dictionary) -> Array:
	## March column: stacked along approach axis (depth), facing enemy.
	var ids := _roster_ids(battle)
	var facing := _default_facing(battle)
	var zone := _BattleData.zone_rect_m(battle, str(battle.get("player_team", "blue")))
	var center := zone.get_center()
	var back := -facing
	var spacing := 28.0
	var out: Array = []
	for i in range(ids.size()):
		var pos: Vector2 = center + back * (spacing * float(i)) + facing * 10.0
		# Keep inside zone by clamping toward center if needed.
		pos.x = clampf(pos.x, zone.position.x + 25.0, zone.position.x + zone.size.x - 25.0)
		pos.y = clampf(pos.y, zone.position.y + 25.0, zone.position.y + zone.size.y - 25.0)
		out.append(_make_placement(battle, str(ids[i]), pos, facing))
	return out


static func _refused_flank(battle: Dictionary) -> Array:
	## Main line abreast; northernmost wing held back (refused).
	var ids := _roster_ids(battle)
	var facing := _default_facing(battle)
	var zone := _BattleData.zone_rect_m(battle, str(battle.get("player_team", "blue")))
	var n: int = maxi(ids.size(), 1)
	var gap: float = zone.size.y / float(n + 1)
	var x_front: float = zone.position.x + zone.size.x * 0.62
	var x_refused: float = zone.position.x + zone.size.x * 0.35
	var out: Array = []
	for i in range(ids.size()):
		var y: float = zone.position.y + gap * float(i + 1)
		var x: float = x_front
		if i == 0:
			x = x_refused
		out.append(_make_placement(battle, str(ids[i]), Vector2(x, y), facing))
	return out
