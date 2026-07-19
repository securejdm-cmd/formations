extends SceneTree
## WO-030: per-attacker frontage + damage for worst S8 ge3 seed.


func _initialize() -> void:
	call_deferred("_run")


func _consts():
	return root.get_node("/root/Constants")


func _run_battle(seed_value: int, attackers: int) -> Dictionary:
	_consts().set_constant("quality_of_day_enabled", true)
	_consts().set_constant("quality_of_day_sigma", 0.045)
	var packed: PackedScene = load("res://tests/scenario_08.tscn")
	var sc = packed.instantiate()
	sc.headless_mode = true
	sc.fast_sim_mode = true
	sc.auto_run = false
	sc.suppress_io = true
	sc.attacker_count = attackers
	sc.set_battle_seed(seed_value)
	root.add_child(sc)
	var spins := 0
	while not sc.is_node_ready() and spins < 512:
		OS.delay_usec(1000)
		spins += 1

	var max_partners := 0
	var multi_partner_ticks := 0
	var worst_multi: Dictionary = {}
	var ticks_with_headon: Dictionary = {}  # id -> count
	var ticks := 0
	while not sc.is_battle_over() and ticks < 20000:
		sc.advance_one_tick()
		ticks += 1
		var core = sc._sim_core
		if core == null:
			continue
		var defender = null
		var atk_units: Array = []
		for u in core.units:
			if str(u.unit_id) == "defender":
				defender = u
			elif str(u.unit_id).begins_with("attacker"):
				atk_units.append(u)
		if defender == null:
			continue
		var partners = defender.get_contact_partners()
		max_partners = maxi(max_partners, partners.size())
		if partners.size() >= 2:
			multi_partner_ticks += 1
			var def_front: float = float(defender.effective_frontage_m())
			var sum_span: float = 0.0
			var sum_pct: float = 0.0
			var sum_headon_full: float = 0.0
			var rows: Array = []
			for atk in partners:
				var contact: Dictionary = EdgeContact.classify_contact(atk, defender)
				var pct: float = float(contact.get("attacker_frontage_pct", 0.0))
				var head_on: bool = CombatResolver.is_head_on_pair(atk, defender)
				var front_contact: bool = CombatResolver.units_have_front_contact(atk, defender)
				# What combat_tick actually uses for head-on: always 1.0
				var combat_pct: float = 1.0 if (head_on and front_contact) else pct
				var span: float = combat_pct * float(atk.effective_frontage_m())
				sum_span += span
				sum_pct += pct
				sum_headon_full += combat_pct
				rows.append(
					{
						"id": str(atk.unit_id),
						"head_on": head_on,
						"front_contact": front_contact,
						"edge_pct": pct,
						"combat_pct": combat_pct,
						"span_m": span,
						"pos_x": float(atk.position.x),
						"pos_y": float(atk.position.y),
						"str": float(atk.strength),
					}
				)
			if worst_multi.is_empty() or sum_span > float(worst_multi.get("sum_span", 0.0)):
				worst_multi = {
					"tick": int(core.sim_tick_count),
					"def_front_m": def_front,
					"sum_span": sum_span,
					"sum_edge_pct": sum_pct,
					"sum_combat_pct": sum_headon_full,
					"exceeds": sum_span > def_front + 0.001,
					"rows": rows,
				}
		for atk2 in partners:
			var id2: String = str(atk2.unit_id)
			if CombatResolver.is_head_on_pair(atk2, defender) and CombatResolver.units_have_front_contact(atk2, defender):
				ticks_with_headon[id2] = int(ticks_with_headon.get(id2, 0)) + 1

	# Final damage dealt from proxies after sync
	sc._sync_units_from_core()
	var damage_by_attacker: Dictionary = {}
	for u in sc._units:
		if str(u.unit_id).begins_with("attacker"):
			damage_by_attacker[str(u.unit_id)] = float(u.damage_dealt)

	var dmg: float = float(sc.get_defender_damage_taken())
	var qods: Array = []
	for u2 in sc._units:
		qods.append("%s=%.6f" % [u2.unit_id, float(u2.quality_of_day)])
	var out := {
		"dmg": dmg,
		"ticks": ticks,
		"max_partners": max_partners,
		"multi_partner_ticks": multi_partner_ticks,
		"worst_multi": worst_multi,
		"ticks_with_headon": ticks_with_headon,
		"damage_by_attacker": damage_by_attacker,
		"qods": qods,
		"combat_sec": float(sc.get_phase_durations_sec().get("combat_sec", -1.0)),
	}
	sc.free()
	return out


func _run() -> void:
	print("WO030_S8_FRONTAGE_DIAG_START")
	var seed_value := 1321
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("SEED="):
			seed_value = int(str(a).split("=")[1])
	print("SEED=%d" % seed_value)

	var s1: Dictionary = _run_battle(seed_value, 1)
	var s3: Dictionary = _run_battle(seed_value, 3)
	var ratio: float = float(s3.dmg) / float(s1.dmg) if float(s1.dmg) > 0.0 else 0.0
	print(
		"SUMMARY single=%.4f triple=%.4f ratio=%.4f ge3=%s"
		% [float(s1.dmg), float(s3.dmg), ratio, str(ratio >= 3.0)]
	)
	print(
		"SINGLE combat_sec=%.1f headon_ticks=%s dmg_by=%s"
		% [float(s1.combat_sec), str(s1.ticks_with_headon), str(s1.damage_by_attacker)]
	)
	print(
		"TRIPLE combat_sec=%.1f max_partners=%d multi_partner_ticks=%d headon_ticks=%s"
		% [
			float(s3.combat_sec),
			int(s3.max_partners),
			int(s3.multi_partner_ticks),
			str(s3.ticks_with_headon),
		]
	)
	print("DAMAGE_BY_ATTACKER_TRIPLE %s" % str(s3.damage_by_attacker))
	print("QOD_SINGLE %s" % "|".join(s1.qods))
	print("QOD_TRIPLE %s" % "|".join(s3.qods))

	var wm: Dictionary = s3.worst_multi
	if not wm.is_empty():
		print(
			"WORST_MULTI tick=%d def_front=%.3f sum_combat_span=%.3f sum_combat_pct=%.3f exceeds=%s"
			% [
				int(wm.tick),
				float(wm.def_front_m),
				float(wm.sum_span),
				float(wm.sum_combat_pct),
				str(wm.exceeds),
			]
		)
		for r in wm.rows:
			print(
				"  atk=%s head_on=%s front_c=%s edge_pct=%.3f combat_pct=%.3f span=%.3f str=%.2f pos=(%.1f,%.1f)"
				% [
					r.id,
					str(r.head_on),
					str(r.front_contact),
					float(r.edge_pct),
					float(r.combat_pct),
					float(r.span_m),
					float(r.str),
					float(r.pos_x),
					float(r.pos_y),
				]
			)
	else:
		print("WORST_MULTI none (never 2+ partners on defender)")

	_consts().reload_from_file()
	print("WO030_S8_FRONTAGE_DIAG_DONE")
	quit(0)
