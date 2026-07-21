extends Node2D

## WO-034 — Deployment screen (designer-facing).
## Edits BattleScenarioData placements only; Ready serializes and hands off to ScenarioFromData.
## No sim ticks on this screen (static). Battle handoff uses Scenario01 sim-thread seam.

const _BattleData := preload("res://scripts/battle_scenario_data.gd")
const _Presets := preload("res://scripts/ui/deployment_presets.gd")
const _HeightField := preload("res://scripts/height_field.gd")
const BATTLE_SCENE := preload("res://tests/scenario_from_data.tscn")
const UNIT_SCENE := preload("res://scenes/unit.tscn")

const BATTLE_PATH := "res://data/battles/wo034_pitched_deploy.json"

## Styling: earth campaign map — olive field, ink UI, ochre accents (not purple/cream AI defaults).
const COL_GROUND := Color(0.42, 0.52, 0.34, 1.0)
const COL_ZONE_PLAYER := Color(0.20, 0.45, 0.70, 0.22)
const COL_ZONE_ENEMY := Color(0.70, 0.22, 0.18, 0.18)
const COL_ZONE_REJECT := Color(0.85, 0.15, 0.10, 0.45)
const COL_INK := Color(0.12, 0.10, 0.08, 1.0)
const COL_PAPER := Color(0.93, 0.90, 0.82, 0.94)
const COL_ACCENT := Color(0.72, 0.42, 0.16, 1.0)
const COL_OK := Color(0.18, 0.45, 0.28, 1.0)

var battle: Dictionary = {}
var placements: Array = [] ## player placement dicts
var selected_id: String = ""
var placing_id: String = "" ## roster id awaiting map click
var _drag_placed_id: String = ""
var _rotate_mode: bool = false
var _reject_flash_t: float = 0.0
var _fps_accum: float = 0.0
var _fps_frames: int = 0
var _fps_report: float = 0.0
var _px: float = 1.0

var _ground: ColorRect
var _relief: Sprite2D
var _zone_player: ColorRect
var _zone_enemy: ColorRect
var _camera: Camera2D
var _unit_layer: Node2D
var _enemy_visuals: Array = []
var _hud: CanvasLayer
var _roster_box: VBoxContainer
var _summary_label: Label
var _status_label: Label
var _fps_label: Label
var _width_slider: HSlider
var _width_label: Label
var _selected_label: Label


func _ready() -> void:
	_px = float(_constants().get_float("px_per_meter"))
	battle = _BattleData.load_path(BATTLE_PATH)
	if battle.is_empty():
		push_error("DeploymentScreen: failed to load battle")
		return
	_build_world()
	_build_hud()
	_spawn_enemy_visuals()
	_refresh_roster_ui()
	_refresh_placed_visuals()
	_update_summary()
	set_process(true)
	print("[WO-034] Deployment screen ready. Battle=%s" % str(battle.get("id")))
	print("[WO-034] How to test: F5 this scene → place via roster/presets → width/rotate → Ready.")


func _constants():
	return Engine.get_main_loop().root.get_node("/root/Constants")


func _process(delta: float) -> void:
	_fps_accum += delta
	_fps_frames += 1
	if _fps_accum >= 0.5:
		_fps_report = float(_fps_frames) / _fps_accum
		_fps_accum = 0.0
		_fps_frames = 0
		if _fps_label != null:
			_fps_label.text = "FPS %.0f  (deploy static — no sim)" % _fps_report
	if _reject_flash_t > 0.0:
		_reject_flash_t = maxf(0.0, _reject_flash_t - delta)
		if _zone_player != null:
			_zone_player.color = COL_ZONE_REJECT if _reject_flash_t > 0.0 else COL_ZONE_PLAYER


func _build_world() -> void:
	var C = _constants()
	var bw: float = float(C.get_float("battlefield_width_m")) * _px
	var bh: float = float(C.get_float("battlefield_height_m")) * _px

	_ground = ColorRect.new()
	_ground.name = "Ground"
	_ground.color = COL_GROUND
	_ground.size = Vector2(bw, bh)
	_ground.position = Vector2(-bw * 0.5, -bh * 0.5)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.z_index = -20
	add_child(_ground)

	var hf = _BattleData.build_height_field(battle)
	if hf != null and str(hf.label) != "flat":
		var img: Image = hf.build_relief_image(_px, COL_GROUND)
		_relief = Sprite2D.new()
		_relief.texture = ImageTexture.create_from_image(img)
		_relief.centered = true
		_relief.position = Vector2.ZERO
		_relief.z_index = -15
		add_child(_relief)
		_ground.visible = false

	_render_terrain_patches()

	var z_blue := _BattleData.zone_rect_m(battle, "blue")
	var z_red := _BattleData.zone_rect_m(battle, "red")
	_zone_player = _make_zone_rect(z_blue, COL_ZONE_PLAYER, "ZonePlayer")
	_zone_enemy = _make_zone_rect(z_red, COL_ZONE_ENEMY, "ZoneEnemy")
	add_child(_zone_player)
	add_child(_zone_enemy)

	_unit_layer = Node2D.new()
	_unit_layer.name = "UnitLayer"
	add_child(_unit_layer)

	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.enabled = true
	# Deployment zoom: see full zones + ridge.
	_camera.zoom = Vector2(0.55, 0.55)
	add_child(_camera)
	# Disable left-pan while placing; middle/right still via custom.
	_camera.set_script(load("res://scripts/battlefield_camera.gd"))
	_camera.enable_left_drag_pan = false


func _make_zone_rect(zone_m: Rect2, color: Color, node_name: String) -> ColorRect:
	var r := ColorRect.new()
	r.name = node_name
	r.color = color
	r.position = Vector2(zone_m.position.x * _px, zone_m.position.y * _px)
	r.size = Vector2(zone_m.size.x * _px, zone_m.size.y * _px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = -8
	return r


func _render_terrain_patches() -> void:
	var i := 0
	for patch in battle.get("terrain_patches", []):
		if typeof(patch) != TYPE_DICTIONARY:
			continue
		var rect := ColorRect.new()
		rect.name = "TerrainPatch_%d" % i
		i += 1
		rect.position = Vector2(float(patch.get("x")) * _px, float(patch.get("y")) * _px)
		rect.size = Vector2(float(patch.get("w")) * _px, float(patch.get("h")) * _px)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.z_index = -10
		var ptype: String = str(patch.get("type", "FOREST")).to_upper()
		rect.color = Color(0.28, 0.42, 0.22, 0.85) if ptype == "SHRUB" else Color(0.18, 0.32, 0.14, 0.9)
		add_child(rect)


func _spawn_enemy_visuals() -> void:
	## R25 v1: enemy deployment fully visible (no fog).
	for rec in battle.get("enemy_units", []):
		if typeof(rec) != TYPE_DICTIONARY:
			continue
		var u: Unit = _BattleData.spawn_unit_node(self, rec, UNIT_SCENE)
		u.set_process(false)
		u.set_physics_process(false)
		u.input_pickable = false
		u.monitoring = false
		u.monitorable = false
		_enemy_visuals.append(u)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "DeployHUD"
	add_child(_hud)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)

	# Brand hero strip (left).
	var brand_panel := PanelContainer.new()
	brand_panel.position = Vector2(24, 20)
	brand_panel.custom_minimum_size = Vector2(320, 0)
	brand_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(brand_panel)
	root.add_child(brand_panel)
	var brand_v := VBoxContainer.new()
	brand_panel.add_child(brand_v)
	var brand := Label.new()
	brand.text = "FORMATIONS"
	brand.add_theme_font_size_override("font_size", 42)
	brand.add_theme_color_override("font_color", COL_INK)
	brand_v.add_child(brand)
	var sub := Label.new()
	sub.text = "Deployment"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", COL_ACCENT)
	brand_v.add_child(sub)
	var hint := Label.new()
	hint.text = "Drag roster → zone · R rotate · Width slider · Presets edit freely"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18))
	hint.custom_minimum_size = Vector2(300, 0)
	brand_v.add_child(hint)

	# Roster panel.
	var roster_panel := PanelContainer.new()
	roster_panel.position = Vector2(24, 160)
	roster_panel.custom_minimum_size = Vector2(320, 280)
	_style_panel(roster_panel)
	root.add_child(roster_panel)
	var rv := VBoxContainer.new()
	roster_panel.add_child(rv)
	var rt := Label.new()
	rt.text = "ROSTER"
	rt.add_theme_font_size_override("font_size", 16)
	rt.add_theme_color_override("font_color", COL_INK)
	rv.add_child(rt)
	_roster_box = VBoxContainer.new()
	rv.add_child(_roster_box)

	# Presets + ready (bottom-left).
	var action_panel := PanelContainer.new()
	action_panel.position = Vector2(24, 460)
	action_panel.custom_minimum_size = Vector2(320, 0)
	_style_panel(action_panel)
	root.add_child(action_panel)
	var av := VBoxContainer.new()
	action_panel.add_child(av)
	var pt := Label.new()
	pt.text = "PRESETS"
	pt.add_theme_font_size_override("font_size", 16)
	pt.add_theme_color_override("font_color", COL_INK)
	av.add_child(pt)
	var preset_row := HBoxContainer.new()
	av.add_child(preset_row)
	for pname in _Presets.shipped_names():
		var b := Button.new()
		b.text = str(pname)
		b.pressed.connect(_on_preset.bind(str(pname)))
		_style_button(b)
		preset_row.add_child(b)
	var ready_btn := Button.new()
	ready_btn.text = "READY / DEPLOY"
	ready_btn.custom_minimum_size = Vector2(0, 44)
	ready_btn.pressed.connect(_on_ready)
	_style_button(ready_btn, true)
	av.add_child(ready_btn)
	_summary_label = Label.new()
	_summary_label.add_theme_color_override("font_color", COL_INK)
	av.add_child(_summary_label)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(300, 0)
	_status_label.add_theme_color_override("font_color", Color(0.45, 0.2, 0.1))
	av.add_child(_status_label)

	# Selection / width (right).
	var sel_panel := PanelContainer.new()
	sel_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sel_panel.position = Vector2(-360, 20)
	sel_panel.custom_minimum_size = Vector2(320, 0)
	_style_panel(sel_panel)
	root.add_child(sel_panel)
	# Fix right anchor manually for non-fullscreen child.
	sel_panel.anchor_left = 1.0
	sel_panel.anchor_right = 1.0
	sel_panel.offset_left = -344
	sel_panel.offset_right = -24
	sel_panel.offset_top = 20
	var sv := VBoxContainer.new()
	sel_panel.add_child(sv)
	_selected_label = Label.new()
	_selected_label.text = "No unit selected"
	_selected_label.add_theme_font_size_override("font_size", 16)
	_selected_label.add_theme_color_override("font_color", COL_INK)
	sv.add_child(_selected_label)
	_width_label = Label.new()
	_width_label.text = "Frontage —"
	_width_label.add_theme_color_override("font_color", COL_INK)
	sv.add_child(_width_label)
	_width_slider = HSlider.new()
	var bounds := _BattleData.frontage_bounds(battle)
	_width_slider.min_value = bounds.x
	_width_slider.max_value = bounds.y
	_width_slider.step = 1.0
	_width_slider.value_changed.connect(_on_width_changed)
	sv.add_child(_width_slider)
	var rot_btn := Button.new()
	rot_btn.text = "Rotate 45° (or press R)"
	rot_btn.pressed.connect(_rotate_selected)
	_style_button(rot_btn)
	sv.add_child(rot_btn)
	var rem_btn := Button.new()
	rem_btn.text = "Remove selected"
	rem_btn.pressed.connect(_remove_selected)
	_style_button(rem_btn)
	sv.add_child(rem_btn)

	_fps_label = Label.new()
	_fps_label.position = Vector2(24, 1040)
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	root.add_child(_fps_label)


func _style_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PAPER
	sb.border_color = Color(0.35, 0.28, 0.18, 1.0)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.content_margin_left = 14
	sb.content_margin_top = 12
	sb.content_margin_right = 14
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)


func _style_button(btn: Button, accent: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_ACCENT if accent else Color(0.22, 0.28, 0.22, 1.0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))


func _refresh_roster_ui() -> void:
	for c in _roster_box.get_children():
		c.queue_free()
	var placed_ids: Dictionary = {}
	for p in placements:
		placed_ids[str(p.get("id"))] = true
	for entry in battle.get("roster", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var uid := str(entry.get("id"))
		var defs := _BattleData.profile_defaults(str(entry.get("profile")))
		var row := Button.new()
		var state := "PLACED" if placed_ids.has(uid) else "READY"
		row.text = "%s — %s [%s]" % [uid, str(defs.display_name), state]
		row.disabled = placed_ids.has(uid)
		row.pressed.connect(_on_roster_pick.bind(uid))
		_style_button(row)
		_roster_box.add_child(row)


func _placement_index(uid: String) -> int:
	for i in range(placements.size()):
		if str(placements[i].get("id")) == uid:
			return i
	return -1


func _get_placement(uid: String) -> Dictionary:
	var i := _placement_index(uid)
	if i < 0:
		return {}
	return placements[i]


func _on_roster_pick(uid: String) -> void:
	placing_id = uid
	selected_id = ""
	_status_label.text = "Click inside your blue zone to place %s" % uid
	_update_selection_panel()


func _on_preset(pname: String) -> void:
	placements = _Presets.apply(battle, pname)
	# Soft-validate; drop illegal corners by pushing toward zone center if needed.
	_sanitize_placements()
	selected_id = ""
	placing_id = ""
	_refresh_roster_ui()
	_refresh_placed_visuals()
	_update_summary()
	_status_label.text = "Preset %s applied — edit freely." % pname
	_update_selection_panel()


func _sanitize_placements() -> void:
	var team := str(battle.get("player_team", "blue"))
	var zone := _BattleData.zone_rect_m(battle, team)
	var center := zone.get_center()
	for i in range(placements.size()):
		var p: Dictionary = placements[i]
		var roster := _BattleData.roster_entry(battle, str(p.get("id")))
		var defs := _BattleData.profile_defaults(str(roster.get("profile")))
		var front := _BattleData.clamp_frontage(battle, float(p.get("formation_frontage_m", defs.formation_frontage_m)))
		var depth := float(p.get("formation_depth_m", defs.formation_depth_m))
		var pos := Vector2(float(p.get("position_m", {}).get("x")), float(p.get("position_m", {}).get("y")))
		var fac := _BattleData.facing_from_dict(p.get("facing", {"x": 1.0, "y": 0.0}))
		var guard := 0
		while not _BattleData.footprint_inside_zone(pos, fac, front, depth, zone) and guard < 20:
			pos = pos.lerp(center, 0.25)
			pos = _BattleData.snap_point_m(battle, pos)
			guard += 1
		p["position_m"] = {"x": pos.x, "y": pos.y}
		p["formation_frontage_m"] = front
		p["formation_depth_m"] = depth
		placements[i] = p


func _unhandled_input(event: InputEvent) -> void:
	# Kept for keys; pointer handled in _input so Area2D units cannot steal clicks.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_rotate_selected()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_remove_selected()
			get_viewport().set_input_as_handled()
			return


func _input(event: InputEvent) -> void:
	## WO-035: click-to-select + drag-to-move must beat Unit Area2D picking.
	if event is InputEventKey:
		return
	# Ignore pointer over HUD panels (left/right chrome).
	if _pointer_over_hud(event):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_map_click(mb.position)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_drag_placed_id = ""
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not selected_id.is_empty():
				_face_toward_screen(mb.position)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_placed_id != "" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_try_reposition(_drag_placed_id, mm.position)
			get_viewport().set_input_as_handled()
		elif selected_id != "" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_face_toward_screen(mm.position)
			get_viewport().set_input_as_handled()


func _pointer_over_hud(event: InputEvent) -> bool:
	if not (event is InputEventMouse):
		return false
	var p: Vector2 = (event as InputEventMouse).position
	var vp := get_viewport().get_visible_rect().size
	# Left chrome ~360px, right chrome ~360px (matches panel layout).
	if p.x < 360.0:
		return true
	if p.x > vp.x - 360.0 and p.y < 280.0:
		return true
	return false


func _screen_to_world_m(screen_pos: Vector2) -> Vector2:
	var canvas := get_canvas_transform()
	var world: Vector2 = canvas.affine_inverse() * screen_pos
	return world / _px


func _handle_map_click(screen_pos: Vector2) -> void:
	var pos_m := _screen_to_world_m(screen_pos)
	# Hit-test existing placements first (select / drag).
	var hit := _hit_placement(pos_m)
	if hit != "":
		selected_id = hit
		placing_id = ""
		_drag_placed_id = hit
		_update_selection_panel()
		_status_label.text = "Selected %s — drag to move, R/right-drag to face." % hit
		return
	if placing_id.is_empty():
		selected_id = ""
		_update_selection_panel()
		return
	_try_place(placing_id, pos_m)


func _hit_placement(pos_m: Vector2) -> String:
	for p in placements:
		var uid := str(p.get("id"))
		var roster := _BattleData.roster_entry(battle, uid)
		var defs := _BattleData.profile_defaults(str(roster.get("profile")))
		var front := float(p.get("formation_frontage_m", defs.formation_frontage_m))
		var depth := float(p.get("formation_depth_m", defs.formation_depth_m))
		var pp := Vector2(float(p.get("position_m", {}).get("x")), float(p.get("position_m", {}).get("y")))
		var fac := _BattleData.facing_from_dict(p.get("facing", {"x": 1.0, "y": 0.0}))
		# Local axes check in meters.
		var fwd := fac.normalized()
		var right := Vector2(-fwd.y, fwd.x)
		var local := pos_m - pp
		if absf(local.dot(fwd)) <= depth * 0.5 and absf(local.dot(right)) <= front * 0.5:
			return uid
	return ""


func _try_place(uid: String, pos_m: Vector2) -> void:
	var snapped := _BattleData.snap_point_m(battle, pos_m)
	var roster := _BattleData.roster_entry(battle, uid)
	var defs := _BattleData.profile_defaults(str(roster.get("profile")))
	var front: float = float(defs.formation_frontage_m)
	var depth: float = float(defs.formation_depth_m)
	var facing := _Presets.default_facing(battle)
	var zone := _BattleData.zone_rect_m(battle, str(battle.get("player_team", "blue")))
	if not _BattleData.footprint_inside_zone(snapped, facing, front, depth, zone):
		_reject_flash_t = 0.35
		_status_label.text = "Rejected — place fully inside the blue deployment zone."
		return
	# Overlap vs existing.
	for p in placements:
		var other := str(p.get("id"))
		if other == uid:
			continue
		var o_roster := _BattleData.roster_entry(battle, other)
		var o_defs := _BattleData.profile_defaults(str(o_roster.get("profile")))
		var o_front := float(p.get("formation_frontage_m", o_defs.formation_frontage_m))
		var o_depth := float(p.get("formation_depth_m", o_defs.formation_depth_m))
		var o_pos := Vector2(float(p.get("position_m", {}).get("x")), float(p.get("position_m", {}).get("y")))
		var o_fac := _BattleData.facing_from_dict(p.get("facing", {"x": 1.0, "y": 0.0}))
		if _BattleData.footprints_overlap(snapped, facing, front, depth, o_pos, o_fac, o_front, o_depth):
			_reject_flash_t = 0.35
			_status_label.text = "Rejected — overlaps %s." % other
			return
	var rec := {
		"id": uid,
		"position_m": {"x": snapped.x, "y": snapped.y},
		"facing": _BattleData.facing_to_dict(facing),
		"formation_frontage_m": front,
		"formation_depth_m": depth,
		"posture": "normal",
	}
	var idx := _placement_index(uid)
	if idx >= 0:
		placements[idx] = rec
	else:
		placements.append(rec)
	placing_id = ""
	selected_id = uid
	_refresh_roster_ui()
	_refresh_placed_visuals()
	_update_summary()
	_update_selection_panel()
	_status_label.text = "Placed %s." % uid


func _try_reposition(uid: String, screen_pos: Vector2) -> void:
	var idx := _placement_index(uid)
	if idx < 0:
		return
	var p: Dictionary = placements[idx]
	var snapped := _BattleData.snap_point_m(battle, _screen_to_world_m(screen_pos))
	var front := float(p.get("formation_frontage_m"))
	var depth := float(p.get("formation_depth_m"))
	var fac := _BattleData.facing_from_dict(p.get("facing", {"x": 1.0, "y": 0.0}))
	var zone := _BattleData.zone_rect_m(battle, str(battle.get("player_team", "blue")))
	if not _BattleData.footprint_inside_zone(snapped, fac, front, depth, zone):
		_reject_flash_t = 0.2
		return
	for other_p in placements:
		var oid := str(other_p.get("id"))
		if oid == uid:
			continue
		var o_pos := Vector2(float(other_p.get("position_m", {}).get("x")), float(other_p.get("position_m", {}).get("y")))
		var o_fac := _BattleData.facing_from_dict(other_p.get("facing", {"x": 1.0, "y": 0.0}))
		if _BattleData.footprints_overlap(
			snapped, fac, front, depth,
			o_pos, o_fac, float(other_p.get("formation_frontage_m")), float(other_p.get("formation_depth_m"))
		):
			_reject_flash_t = 0.2
			return
	p["position_m"] = {"x": snapped.x, "y": snapped.y}
	placements[idx] = p
	_refresh_placed_visuals()


func _face_toward_screen(screen_pos: Vector2) -> void:
	var idx := _placement_index(selected_id)
	if idx < 0:
		return
	var p: Dictionary = placements[idx]
	var pos := Vector2(float(p.get("position_m", {}).get("x")), float(p.get("position_m", {}).get("y")))
	var target := _screen_to_world_m(screen_pos)
	var fac := (target - pos)
	if fac.length_squared() < 0.01:
		return
	fac = fac.normalized()
	var front := float(p.get("formation_frontage_m"))
	var depth := float(p.get("formation_depth_m"))
	var zone := _BattleData.zone_rect_m(battle, str(battle.get("player_team", "blue")))
	if not _BattleData.footprint_inside_zone(pos, fac, front, depth, zone):
		_reject_flash_t = 0.2
		return
	p["facing"] = _BattleData.facing_to_dict(fac)
	placements[idx] = p
	_refresh_placed_visuals()
	_update_selection_panel()


func _rotate_selected() -> void:
	var idx := _placement_index(selected_id)
	if idx < 0:
		return
	var p: Dictionary = placements[idx]
	var fac := _BattleData.facing_from_dict(p.get("facing", {"x": 1.0, "y": 0.0}))
	fac = fac.rotated(deg_to_rad(45.0))
	var pos := Vector2(float(p.get("position_m", {}).get("x")), float(p.get("position_m", {}).get("y")))
	var front := float(p.get("formation_frontage_m"))
	var depth := float(p.get("formation_depth_m"))
	var zone := _BattleData.zone_rect_m(battle, str(battle.get("player_team", "blue")))
	if not _BattleData.footprint_inside_zone(pos, fac, front, depth, zone):
		_reject_flash_t = 0.25
		_status_label.text = "Rotate rejected — footprint would leave zone."
		return
	p["facing"] = _BattleData.facing_to_dict(fac)
	placements[idx] = p
	_refresh_placed_visuals()
	_update_selection_panel()


func _remove_selected() -> void:
	if selected_id.is_empty():
		return
	var idx := _placement_index(selected_id)
	if idx < 0:
		return
	placements.remove_at(idx)
	selected_id = ""
	_refresh_roster_ui()
	_refresh_placed_visuals()
	_update_summary()
	_update_selection_panel()
	_status_label.text = "Unit removed."


func _on_width_changed(v: float) -> void:
	var idx := _placement_index(selected_id)
	if idx < 0:
		return
	var p: Dictionary = placements[idx]
	var roster := _BattleData.roster_entry(battle, selected_id)
	var defs := _BattleData.profile_defaults(str(roster.get("profile")))
	var front := _BattleData.clamp_frontage(battle, v)
	var depth := _BattleData.depth_for_frontage(float(defs.formation_frontage_m), float(defs.formation_depth_m), front)
	var pos := Vector2(float(p.get("position_m", {}).get("x")), float(p.get("position_m", {}).get("y")))
	var fac := _BattleData.facing_from_dict(p.get("facing", {"x": 1.0, "y": 0.0}))
	var zone := _BattleData.zone_rect_m(battle, str(battle.get("player_team", "blue")))
	if not _BattleData.footprint_inside_zone(pos, fac, front, depth, zone):
		_reject_flash_t = 0.25
		_status_label.text = "Width rejected — footprint would leave zone."
		_width_slider.set_value_no_signal(float(p.get("formation_frontage_m")))
		return
	# Overlap check.
	for other_p in placements:
		if str(other_p.get("id")) == selected_id:
			continue
		var o_pos := Vector2(float(other_p.get("position_m", {}).get("x")), float(other_p.get("position_m", {}).get("y")))
		var o_fac := _BattleData.facing_from_dict(other_p.get("facing", {"x": 1.0, "y": 0.0}))
		if _BattleData.footprints_overlap(
			pos, fac, front, depth,
			o_pos, o_fac, float(other_p.get("formation_frontage_m")), float(other_p.get("formation_depth_m"))
		):
			_reject_flash_t = 0.25
			_status_label.text = "Width rejected — would overlap ally."
			_width_slider.set_value_no_signal(float(p.get("formation_frontage_m")))
			return
	p["formation_frontage_m"] = front
	p["formation_depth_m"] = depth
	placements[idx] = p
	_width_label.text = "Frontage %.0fm · Depth %.1fm (area held)" % [front, depth]
	_refresh_placed_visuals()


func _update_selection_panel() -> void:
	if selected_id.is_empty():
		_selected_label.text = "No unit selected"
		_width_label.text = "Frontage —"
		return
	var p := _get_placement(selected_id)
	var roster := _BattleData.roster_entry(battle, selected_id)
	var defs := _BattleData.profile_defaults(str(roster.get("profile")))
	var front := float(p.get("formation_frontage_m", defs.formation_frontage_m))
	var depth := float(p.get("formation_depth_m", defs.formation_depth_m))
	var fac := _BattleData.facing_from_dict(p.get("facing", {"x": 1.0, "y": 0.0}))
	_selected_label.text = "%s · %s\nFacing (%.2f, %.2f)" % [selected_id, str(defs.display_name), fac.x, fac.y]
	_width_slider.set_value_no_signal(front)
	_width_label.text = "Frontage %.0fm · Depth %.1fm (area held)" % [front, depth]


func _update_summary() -> void:
	var total: int = battle.get("roster", []).size()
	var placed: int = placements.size()
	_summary_label.text = "Deployment summary: %d / %d placed · %d remaining" % [placed, total, total - placed]


func _refresh_placed_visuals() -> void:
	for c in _unit_layer.get_children():
		c.queue_free()
	for p in placements:
		var uid := str(p.get("id"))
		var roster := _BattleData.roster_entry(battle, uid)
		var rec := _BattleData.placement_to_unit_record(battle, p)
		# Visual-only unit (no orders / process).
		var u: Unit = _BattleData.spawn_unit_node(_unit_layer, rec, UNIT_SCENE)
		u.set_process(false)
		u.set_physics_process(false)
		u.set_order_queue([])
		u.input_pickable = false
		u.monitoring = false
		u.monitorable = false
		# Facing chevron label.
		var tag := Label.new()
		tag.text = "%s\n%.0fm" % [uid, float(p.get("formation_frontage_m"))]
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(1, 1, 1))
		tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		tag.position = Vector2(-30, -50)
		u.add_child(tag)
		if uid == selected_id:
			# Selection ring.
			var ring := ColorRect.new()
			ring.color = Color(1.0, 0.85, 0.2, 0.35)
			var front_px := float(p.get("formation_frontage_m")) * _px
			var depth_px := float(p.get("formation_depth_m")) * _px
			ring.size = Vector2(depth_px + 8, front_px + 8)
			ring.position = Vector2(-(depth_px + 8) * 0.5, -(front_px + 8) * 0.5)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.z_index = -1
			u.add_child(ring)


func _on_ready() -> void:
	var result: Dictionary = _BattleData.validate_placements(battle, placements)
	if not bool(result.ok):
		_status_label.text = "Cannot deploy:\n" + "\n".join(result.errors)
		_reject_flash_t = 0.5
		return
	var merged: Dictionary = _BattleData.merge_deployed_battle(battle, placements)
	_BattleData.pending_battle = merged
	# Persist for designer inspection / headless replay.
	var path := "user://wo034_last_deploy.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(merged, "\t"))
		f.close()
		print("[WO-034] Serialized deployment → %s" % path)
	print("[WO-034] Deploy FPS last=%.1f — handing off to battle (sim thread)." % _fps_report)
	get_tree().change_scene_to_packed(BATTLE_SCENE)
