class_name BattleScenarioData
extends RefCounted

## WO-034 — battle JSON ↔ existing scenario unit records (ORDER_SCHEMA + placement fields).
## Placement actions write the same structure headless scenarios author by hand.
## No sim mechanics; serialize / validate / spawn only.

const DEFAULT_BATTLE_PATH := "res://data/battles/wo034_pitched_deploy.json"
const _HeightField := preload("res://scripts/height_field.gd")
const _OrderSchema := preload("res://scripts/orders/order_schema.gd")

## Handoff payload for deployment → battle scene (no new Autoload).
static var pending_battle: Dictionary = {}


static func load_path(path: String = DEFAULT_BATTLE_PATH) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		push_error("BattleScenarioData: empty or missing %s" % path)
		return {}
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("BattleScenarioData: JSON root must be object: %s" % path)
		return {}
	return parsed


static func px_per_meter() -> float:
	return float(_constants().get_float("px_per_meter"))


static func _constants():
	## Runtime autoload lookup — bare `Constants` fails GDScript compile for new
	## scripts in this cloud Godot -s path; existing cached scripts still work.
	return Engine.get_main_loop().root.get_node("/root/Constants")


static func pos_m_to_px(pos_m: Dictionary) -> Vector2:
	var px := px_per_meter()
	return Vector2(float(pos_m.get("x", 0.0)) * px, float(pos_m.get("y", 0.0)) * px)


static func facing_from_dict(f: Dictionary) -> Vector2:
	var v := Vector2(float(f.get("x", 1.0)), float(f.get("y", 0.0)))
	if v.length_squared() < 0.0001:
		return Vector2.RIGHT
	return v.normalized()


static func facing_to_dict(v: Vector2) -> Dictionary:
	var n := v.normalized()
	return {"x": n.x, "y": n.y}


static func zone_rect_m(battle: Dictionary, team: String) -> Rect2:
	var zones: Dictionary = battle.get("deployment_zones", {})
	var z: Dictionary = zones.get(team, {})
	return Rect2(
		float(z.get("x", 0.0)),
		float(z.get("y", 0.0)),
		float(z.get("w", 0.0)),
		float(z.get("h", 0.0))
	)


static func snap_m(battle: Dictionary) -> float:
	return float(battle.get("snap_m", 5.0))


static func frontage_bounds(battle: Dictionary) -> Vector2:
	## Returns (min_m, max_m) from battle-authored formation_bounds.
	var b: Dictionary = battle.get("formation_bounds", {})
	return Vector2(float(b.get("frontage_min_m", 20.0)), float(b.get("frontage_max_m", 80.0)))


static func build_height_field(battle: Dictionary):
	var hf_spec: Dictionary = battle.get("height_field", {})
	if hf_spec.is_empty():
		return _HeightField.make_flat()
	var features: Array = hf_spec.get("features", [])
	if features.is_empty():
		return _HeightField.make_flat()
	return _HeightField.make_from_features(features, -1.0, str(hf_spec.get("label", "composite")))


static func default_player_queue(battle: Dictionary) -> Array:
	var q: Array = battle.get("default_player_order_queue", [])
	if q.is_empty():
		return [
			{
				"primitive": _OrderSchema.PRIM_ATTACK_NEAREST,
				"params": {},
				"trigger": {"type": _OrderSchema.TRIG_AT_START},
			}
		]
	return q.duplicate(true)


static func roster_entry(battle: Dictionary, unit_id: String) -> Dictionary:
	for entry in battle.get("roster", []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) == unit_id:
			return entry
	return {}


static func profile_defaults(profile_id: String) -> Dictionary:
	var prof: Dictionary = UnitProfileLoader.load_profile(profile_id)
	var C = _constants()
	return {
		"formation_frontage_m": float(prof.get("formation_frontage_m", C.get_float("default_infantry_block_frontage_m"))),
		"formation_depth_m": float(prof.get("formation_depth_m", C.get_float("default_infantry_block_depth_m"))),
		"display_name": str(prof.get("display_name", profile_id)),
		"profile_id": profile_id,
	}


static func area_m2(frontage_m: float, depth_m: float) -> float:
	return maxf(frontage_m, 0.01) * maxf(depth_m, 0.01)


static func depth_for_frontage(base_frontage_m: float, base_depth_m: float, frontage_m: float) -> float:
	## Wide-vs-deep (Combat Core 3.7): hold body packing area constant with Strength.
	var area := area_m2(base_frontage_m, base_depth_m)
	return area / maxf(frontage_m, 0.01)


static func clamp_frontage(battle: Dictionary, frontage_m: float) -> float:
	var bounds := frontage_bounds(battle)
	return clampf(frontage_m, bounds.x, bounds.y)


static func snap_point_m(battle: Dictionary, pos_m: Vector2) -> Vector2:
	var s := snap_m(battle)
	if s <= 0.0:
		return pos_m
	return Vector2(snappedf(pos_m.x, s), snappedf(pos_m.y, s))


static func footprint_inside_zone(pos_m: Vector2, facing: Vector2, frontage_m: float, depth_m: float, zone: Rect2) -> bool:
	## All four OBB corners (meters) must lie inside the deployment zone rect.
	var fwd := facing.normalized()
	if fwd.length_squared() < 0.0001:
		fwd = Vector2.RIGHT
	var right := Vector2(-fwd.y, fwd.x)
	var hd := depth_m * 0.5
	var hf := frontage_m * 0.5
	var corners := [
		pos_m + fwd * hd + right * hf,
		pos_m + fwd * hd - right * hf,
		pos_m - fwd * hd - right * hf,
		pos_m - fwd * hd + right * hf,
	]
	for c in corners:
		if not zone.has_point(c):
			return false
	return true


static func footprints_overlap(
	a_pos: Vector2,
	a_facing: Vector2,
	a_front: float,
	a_depth: float,
	b_pos: Vector2,
	b_facing: Vector2,
	b_front: float,
	b_depth: float
) -> bool:
	## Meter-space OBB overlap via Separation Axis Theorem (deployment-time only).
	var a_corners := _obb_corners_m(a_pos, a_facing, a_front, a_depth)
	var b_corners := _obb_corners_m(b_pos, b_facing, b_front, b_depth)
	return _obb_overlap_m(a_corners, b_corners)


static func _obb_corners_m(pos: Vector2, facing: Vector2, frontage: float, depth: float) -> PackedVector2Array:
	var fwd := facing.normalized()
	if fwd.length_squared() < 0.0001:
		fwd = Vector2.RIGHT
	var right := Vector2(-fwd.y, fwd.x)
	var hd := depth * 0.5
	var hf := frontage * 0.5
	return PackedVector2Array([
		pos + fwd * hd + right * hf,
		pos + fwd * hd - right * hf,
		pos - fwd * hd - right * hf,
		pos - fwd * hd + right * hf,
	])


static func _obb_overlap_m(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	var axes: Array[Vector2] = []
	axes.append((a[1] - a[0]).normalized())
	axes.append((a[3] - a[0]).normalized())
	axes.append((b[1] - b[0]).normalized())
	axes.append((b[3] - b[0]).normalized())
	for axis in axes:
		if axis.length_squared() < 0.0001:
			continue
		var amin := INF
		var amax := -INF
		var bmin := INF
		var bmax := -INF
		for p in a:
			var d: float = p.dot(axis)
			amin = minf(amin, d)
			amax = maxf(amax, d)
		for p in b:
			var d2: float = p.dot(axis)
			bmin = minf(bmin, d2)
			bmax = maxf(bmax, d2)
		if amax < bmin or bmax < amin:
			return false
	return true


static func placement_to_unit_record(battle: Dictionary, placement: Dictionary) -> Dictionary:
	var uid := str(placement.get("id", ""))
	var roster := roster_entry(battle, uid)
	var profile_id := str(roster.get("profile", placement.get("profile", "test_infantry")))
	var defs := profile_defaults(profile_id)
	var front := float(placement.get("formation_frontage_m", defs.formation_frontage_m))
	var depth := float(placement.get("formation_depth_m", defs.formation_depth_m))
	front = clamp_frontage(battle, front)
	var team := str(battle.get("player_team", "blue"))
	var pos: Dictionary = placement.get("position_m", {"x": 0.0, "y": 0.0})
	var facing: Dictionary = placement.get("facing", {"x": 1.0, "y": 0.0})
	return {
		"id": uid,
		"team": team,
		"profile": profile_id,
		"posture": str(placement.get("posture", _OrderSchema.POSTURE_NORMAL)),
		"position_m": {"x": float(pos.get("x", 0.0)), "y": float(pos.get("y", 0.0))},
		"facing": facing_to_dict(facing_from_dict(facing)),
		"formation_frontage_m": front,
		"formation_depth_m": depth,
		"order_queue": default_player_queue(battle),
	}


static func merge_deployed_battle(battle: Dictionary, player_placements: Array) -> Dictionary:
	## Writes player placements into the scenario unit list alongside enemy_units.
	var out: Dictionary = battle.duplicate(true)
	var units: Array = []
	for eu in battle.get("enemy_units", []):
		if typeof(eu) == TYPE_DICTIONARY:
			units.append(eu.duplicate(true))
	for p in player_placements:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		units.append(placement_to_unit_record(battle, p))
	units.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	out["units"] = units
	out.erase("hand_authored_placements")
	out.erase("roster")
	return out


static func canonical_units_fingerprint(battle_with_units: Dictionary) -> String:
	## Deterministic string of starting state fields (for UI == hand assert).
	var parts: PackedStringArray = PackedStringArray()
	parts.append("battle_type=%s" % str(battle_with_units.get("battle_type", "")))
	var zones: Dictionary = battle_with_units.get("deployment_zones", {})
	var zone_keys: Array = zones.keys()
	zone_keys.sort()
	for zk in zone_keys:
		var z: Dictionary = zones[zk]
		parts.append(
			"zone.%s=%.3f,%.3f,%.3f,%.3f"
			% [str(zk), float(z.get("x")), float(z.get("y")), float(z.get("w")), float(z.get("h"))]
		)
	var units: Array = battle_with_units.get("units", [])
	var sorted_units: Array = units.duplicate()
	sorted_units.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	for u in sorted_units:
		if typeof(u) != TYPE_DICTIONARY:
			continue
		var pos: Dictionary = u.get("position_m", {})
		var fac: Dictionary = u.get("facing", {})
		parts.append(
			"unit:%s team=%s prof=%s posture=%s pos=%.3f,%.3f face=%.6f,%.6f front=%.3f depth=%.3f queue=%s"
			% [
				str(u.get("id")),
				str(u.get("team")),
				str(u.get("profile")),
				str(u.get("posture", "normal")),
				float(pos.get("x", 0.0)),
				float(pos.get("y", 0.0)),
				float(fac.get("x", 0.0)),
				float(fac.get("y", 0.0)),
				float(u.get("formation_frontage_m", 0.0)),
				float(u.get("formation_depth_m", 0.0)),
				JSON.stringify(u.get("order_queue", [])),
			]
		)
	return "\n".join(parts)


static func initial_trace_fingerprint_from_core(core) -> String:
	## Tick-0 proxy state after capture_from_units / before combat.
	var lines: PackedStringArray = PackedStringArray()
	var proxies: Array = []
	for u in core.units:
		proxies.append(u)
	proxies.sort_custom(func(a, b): return str(a.unit_id) < str(b.unit_id))
	var px := px_per_meter()
	for u in proxies:
		var pos_m: Vector2 = u.position / px
		lines.append(
			"%s|%s|%.4f,%.4f|%.6f,%.6f|str=%.2f|coh=%.2f|front=%.3f|depth=%.3f"
			% [
				str(u.unit_id),
				str(u.team_id),
				pos_m.x,
				pos_m.y,
				u.facing.x,
				u.facing.y,
				float(u.strength),
				float(u.cohesion),
				float(u.effective_frontage_m()),
				float(u.full_depth_m()),
			]
		)
	return "\n".join(lines)


static func validate_placements(battle: Dictionary, placements: Array) -> Dictionary:
	## Returns { ok: bool, errors: PackedStringArray }.
	var errors: PackedStringArray = PackedStringArray()
	var team := str(battle.get("player_team", "blue"))
	var zone := zone_rect_m(battle, team)
	var roster: Array = battle.get("roster", [])
	var placed_ids: Dictionary = {}
	for p in placements:
		if typeof(p) != TYPE_DICTIONARY:
			errors.append("non-dict placement")
			continue
		var uid := str(p.get("id", ""))
		if uid.is_empty():
			errors.append("placement missing id")
			continue
		if placed_ids.has(uid):
			errors.append("duplicate placement id=%s" % uid)
		placed_ids[uid] = true
		var roster_e := roster_entry(battle, uid)
		if roster_e.is_empty():
			errors.append("id %s not in roster" % uid)
			continue
		var defs := profile_defaults(str(roster_e.get("profile")))
		var front := clamp_frontage(battle, float(p.get("formation_frontage_m", defs.formation_frontage_m)))
		var depth := float(p.get("formation_depth_m", defs.formation_depth_m))
		var pos_d: Dictionary = p.get("position_m", {})
		var pos := Vector2(float(pos_d.get("x", 0.0)), float(pos_d.get("y", 0.0)))
		var fac := facing_from_dict(p.get("facing", {"x": 1.0, "y": 0.0}))
		if not footprint_inside_zone(pos, fac, front, depth, zone):
			errors.append("%s footprint outside deployment zone" % uid)
	for entry in roster:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if bool(entry.get("required", true)) and not placed_ids.has(str(entry.get("id"))):
			errors.append("required roster unit not placed: %s" % str(entry.get("id")))
	# Pairwise overlap among player placements.
	for i in range(placements.size()):
		var a: Dictionary = placements[i]
		var a_roster := roster_entry(battle, str(a.get("id")))
		var a_defs := profile_defaults(str(a_roster.get("profile", "test_infantry")))
		var a_front := clamp_frontage(battle, float(a.get("formation_frontage_m", a_defs.formation_frontage_m)))
		var a_depth := float(a.get("formation_depth_m", a_defs.formation_depth_m))
		var a_pos := Vector2(float(a.get("position_m", {}).get("x", 0.0)), float(a.get("position_m", {}).get("y", 0.0)))
		var a_fac := facing_from_dict(a.get("facing", {"x": 1.0, "y": 0.0}))
		for j in range(i + 1, placements.size()):
			var b: Dictionary = placements[j]
			var b_roster := roster_entry(battle, str(b.get("id")))
			var b_defs := profile_defaults(str(b_roster.get("profile", "test_infantry")))
			var b_front := clamp_frontage(battle, float(b.get("formation_frontage_m", b_defs.formation_frontage_m)))
			var b_depth := float(b.get("formation_depth_m", b_defs.formation_depth_m))
			var b_pos := Vector2(float(b.get("position_m", {}).get("x", 0.0)), float(b.get("position_m", {}).get("y", 0.0)))
			var b_fac := facing_from_dict(b.get("facing", {"x": 1.0, "y": 0.0}))
			if footprints_overlap(a_pos, a_fac, a_front, a_depth, b_pos, b_fac, b_front, b_depth):
				errors.append("overlap: %s vs %s" % [str(a.get("id")), str(b.get("id"))])
	return {"ok": errors.is_empty(), "errors": errors}


static func apply_profile_dims(profile: Dictionary, frontage_m: float, depth_m: float) -> Dictionary:
	var out: Dictionary = profile.duplicate(true)
	out["formation_frontage_m"] = frontage_m
	out["formation_depth_m"] = depth_m
	return out


static func spawn_unit_node(parent: Node, unit_rec: Dictionary, unit_scene: PackedScene) -> Unit:
	var profile_id := str(unit_rec.get("profile", "test_infantry"))
	var base_prof: Dictionary = UnitProfileLoader.load_profile(profile_id)
	var front := float(unit_rec.get("formation_frontage_m", base_prof.get("formation_frontage_m", 40.0)))
	var depth := float(unit_rec.get("formation_depth_m", base_prof.get("formation_depth_m", 15.0)))
	var prof := apply_profile_dims(base_prof, front, depth)
	var unit: Unit = unit_scene.instantiate()
	parent.add_child(unit)
	unit.configure(
		str(unit_rec.get("id")),
		str(unit_rec.get("team")),
		prof,
		pos_m_to_px(unit_rec.get("position_m", {"x": 0.0, "y": 0.0})),
		facing_from_dict(unit_rec.get("facing", {"x": 1.0, "y": 0.0}))
	)
	unit.starting_posture = str(unit_rec.get("posture", _OrderSchema.POSTURE_NORMAL))
	var q: Array = unit_rec.get("order_queue", [])
	if not q.is_empty():
		unit.set_order_queue(q)
	if str(profile_id).contains("cavalry") or float(prof.get("charge_gait_mult", 1.0)) > 1.01:
		unit.start_from_rest()
	return unit
