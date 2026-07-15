class_name HeightField
extends RefCounted

## Coarse height grid (R6 / WO-021). World meters; sample from battlefield px via px_per_meter.

const TEST_HILL_PEAK_HEIGHT_M := 20.0
const TEST_HILL_HALF_WIDTH_M := 200.0
const TEST_HILL_CREST_X_M := 0.0

var cell_m: float = 20.0
var origin_m: Vector2 = Vector2.ZERO ## SW corner of cell (0,0), meters.
var cols: int = 0
var rows: int = 0
var heights: PackedFloat32Array = PackedFloat32Array()
var enabled: bool = true
var label: String = "flat"


static func px_to_m(pos_px: Vector2) -> Vector2:
	var ppm: float = Constants.get_float("px_per_meter")
	if ppm <= 0.0:
		return Vector2.ZERO
	return pos_px / ppm


static func make_flat(cell_m_in: float = -1.0) -> HeightField:
	var hf := HeightField.new()
	hf.label = "flat"
	hf._init_grid(cell_m_in)
	hf.heights.resize(hf.cols * hf.rows)
	hf.heights.fill(0.0)
	return hf


static func make_test_hill(cell_m_in: float = -1.0) -> HeightField:
	## Triangular E–W ridge: crest at x=0, linear flanks.
	## Flank grade = peak_height / half_width = 20/200 = 0.10 (Sec 7 reference).
	var hf := HeightField.new()
	hf.label = "test_hill"
	hf._init_grid(cell_m_in)
	hf.heights.resize(hf.cols * hf.rows)
	var peak: float = TEST_HILL_PEAK_HEIGHT_M
	var half_w: float = TEST_HILL_HALF_WIDTH_M
	var crest_x: float = TEST_HILL_CREST_X_M
	for r in hf.rows:
		for c in hf.cols:
			var p: Vector2 = hf.cell_center_m(c, r)
			var dx: float = absf(p.x - crest_x)
			var h: float = 0.0
			if dx < half_w:
				h = peak * (1.0 - dx / half_w)
			hf.heights[r * hf.cols + c] = h
	return hf


func _init_grid(cell_m_in: float = -1.0) -> void:
	cell_m = cell_m_in if cell_m_in > 0.0 else Constants.get_float("height_cell_m")
	if cell_m <= 0.0:
		cell_m = 20.0
	var bw: float = Constants.get_float("battlefield_width_m")
	var bh: float = Constants.get_float("battlefield_height_m")
	cols = int(ceil(bw / cell_m))
	rows = int(ceil(bh / cell_m))
	origin_m = Vector2(-bw * 0.5, -bh * 0.5)


func cell_center_m(c: int, r: int) -> Vector2:
	return origin_m + Vector2((float(c) + 0.5) * cell_m, (float(r) + 0.5) * cell_m)


func peak_height_m() -> float:
	var peak: float = 0.0
	for i in heights.size():
		peak = maxf(peak, heights[i])
	return peak


func peak_grade() -> float:
	## Max |∇h| sampled at cell centers (meters rise per meter run).
	var peak: float = 0.0
	for r in rows:
		for c in cols:
			var g: Vector2 = sample_gradient_m(cell_center_m(c, r))
			peak = maxf(peak, g.length())
	return peak


func _raw_height(c: int, r: int) -> float:
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return 0.0
	return heights[r * cols + c]


func sample_height_m(pos_m: Vector2) -> float:
	if not enabled or cols <= 0 or rows <= 0 or heights.is_empty():
		return 0.0
	var local: Vector2 = (pos_m - origin_m) / cell_m - Vector2(0.5, 0.5)
	var c0: int = int(floor(local.x))
	var r0: int = int(floor(local.y))
	var tx: float = local.x - float(c0)
	var ty: float = local.y - float(r0)
	var h00: float = _raw_height(c0, r0)
	var h10: float = _raw_height(c0 + 1, r0)
	var h01: float = _raw_height(c0, r0 + 1)
	var h11: float = _raw_height(c0 + 1, r0 + 1)
	var hx0: float = lerpf(h00, h10, tx)
	var hx1: float = lerpf(h01, h11, tx)
	return lerpf(hx0, hx1, ty)


func sample_gradient_m(pos_m: Vector2) -> Vector2:
	## Central differences in world meters (dh/dx, dh/dy). Deterministic.
	if not enabled or cols <= 0 or rows <= 0 or heights.is_empty():
		return Vector2.ZERO
	var eps: float = cell_m * 0.5
	var hx: float = (
		sample_height_m(pos_m + Vector2(eps, 0.0)) - sample_height_m(pos_m - Vector2(eps, 0.0))
	) / (2.0 * eps)
	var hy: float = (
		sample_height_m(pos_m + Vector2(0.0, eps)) - sample_height_m(pos_m - Vector2(0.0, eps))
	) / (2.0 * eps)
	return Vector2(hx, hy)


func grade_along_direction(pos_m: Vector2, direction: Vector2) -> float:
	## Positive = downhill along direction (−∇h · dir̂).
	if direction.length_squared() < 0.0000001:
		return 0.0
	var g: Vector2 = sample_gradient_m(pos_m)
	return -g.dot(direction.normalized())


func slope_factor(grade: float, bonus: float) -> float:
	## Sec 7 calibration: at slope_reference_grade, factor = 1 ± bonus.
	var ref: float = Constants.get_float("slope_reference_grade")
	if ref <= 0.0:
		return 1.0
	return 1.0 + bonus * (grade / ref)


func speed_mult_at(pos_px: Vector2, facing: Vector2) -> float:
	if not enabled:
		return 1.0
	var grade: float = grade_along_direction(px_to_m(pos_px), facing)
	var mult: float = slope_factor(grade, Constants.get_float("slope_speed_bonus"))
	return maxf(0.05, mult)


func push_mod_at(pos_px: Vector2, facing: Vector2) -> float:
	if not enabled:
		return 1.0
	var grade: float = grade_along_direction(px_to_m(pos_px), facing)
	return maxf(0.05, slope_factor(grade, Constants.get_float("slope_push_bonus")))


func range_mult_toward(shooter_px: Vector2, target_px: Vector2) -> float:
	if not enabled:
		return 1.0
	var to_t: Vector2 = target_px - shooter_px
	var grade: float = grade_along_direction(px_to_m(shooter_px), to_t)
	return maxf(0.05, slope_factor(grade, Constants.get_float("slope_range_bonus")))


func geometry_report() -> Dictionary:
	return {
		"label": label,
		"cell_m": cell_m,
		"cols": cols,
		"rows": rows,
		"origin_m": origin_m,
		"peak_height_m": peak_height_m(),
		"peak_grade": peak_grade(),
		"design_grade": TEST_HILL_PEAK_HEIGHT_M / TEST_HILL_HALF_WIDTH_M,
		"half_width_m": TEST_HILL_HALF_WIDTH_M,
		"crest_x_m": TEST_HILL_CREST_X_M,
	}


func build_relief_image(px_per_meter: float, base_color: Color = Color(0.45, 0.55, 0.35, 1.0)) -> Image:
	## Cheap shaded relief (NW light). Render-only; never touches traces.
	var bw: float = Constants.get_float("battlefield_width_m")
	var bh: float = Constants.get_float("battlefield_height_m")
	var w: int = maxi(int(round(bw * px_per_meter)), 1)
	var h: int = maxi(int(round(bh * px_per_meter)), 1)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var light := Vector2(-0.6, -0.8).normalized()
	var peak: float = maxf(peak_height_m(), 0.001)
	for py in h:
		for px in w:
			var wx: float = origin_m.x + (float(px) + 0.5) / px_per_meter
			var wy: float = origin_m.y + (float(py) + 0.5) / px_per_meter
			var g: Vector2 = sample_gradient_m(Vector2(wx, wy))
			var shade: float = 0.55 + 0.45 * clampf(-g.dot(light) * 4.0, -1.0, 1.0)
			var elev: float = sample_height_m(Vector2(wx, wy)) / peak
			var lit: Color = base_color.lightened(clampf(elev * 0.25, 0.0, 0.35))
			lit = lit.darkened(clampf(1.0 - shade, 0.0, 0.55))
			img.set_pixel(px, py, lit)
	return img
