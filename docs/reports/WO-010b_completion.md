# WO-010b Completion Report — Performance Profile & Optimization

**Directive:** TD REJECTED WO-010 performance (40-unit avg tick 24.7→39.3 ms, superlinear scaling).  
**Branch:** `cursor/wo-010b-perf-profile-fd84`  
**Regression:** Full `scenario_wo010_autotest.gd` — **PASS** (byte-identical traces, S3 ratio 0.279, S7/S8/R13 gates intact).

---

## 1. Profile FIRST — 40-unit breakdown (BEFORE optimize)

Instrumented via `scripts/tick_profiler.gd` + `tests/scenario_wo010b_profile.gd` on WO-010 baseline (`b14a942`), warmup 200, profile 800 ticks:

| Subsystem | ms/tick |
|-----------|---------|
| **total** | **39.997** |
| movement | 18.406 |
| allied_separation | 10.121 |
| contact_classification | 9.207 |
| overlap_assert | 10.407 |
| adhesion (both passes) | ~0.53 |
| combat | ~0.9 |
| grid_overhead | **0.046** |
| trace/logging | ~0.02 |

**Counters (40 units):** classifier_calls/tick **2928**; adhesion_classifier/tick **6.2**; binary_search_iters/tick **0.2**.

### Conclusions (pre-optimize)

1. **Spatial grid is justified** — 0.05 ms/tick overhead; removing it would not materially help massed combat.
2. **Adhesion binary search is NOT the dominant classifier consumer** — ~6 calls/tick vs ~2900 total.
3. **Hot paths:** movement marching contact scans, grid pair loops (allied separation + overlap assert), and repeated `classify_contact` on grid neighbor pairs during massed engagement.

---

## 2. Optimizations applied

| Change | Purpose |
|--------|---------|
| `TickProfiler` + fast/profiled tick paths | Subsystem timing without affecting default sim |
| Per-tick contact cache (`contact_cache.gd`) | Dedup classifier on repeated same-pose pairs |
| Exact float pose hash (`hash([x,y,fx,fy])`) | **Required for byte-identical regression** — quantized hash caused S3/combat drift |
| `FormationGeometry.bounds_may_overlap()` | AABB early-out before OBB / classifier |
| `CombatResolver.could_have_contact()` | Distance reach precheck in marching + overlap |
| Marching enemy loop early-out (`unit.gd`) | Skip classifier when beyond contact reach |
| `_enemies_for()` spatial neighbors | ENGAGED/WAVERING/ROUTING/RALLYING only (MARCHING keeps full scan) |
| Adhesion binary search cap (`adhesion_binary_search_max_iters: 8`) | Cap search iterations per TD directive |
| Adhesion overlap scan distance filter | Skip distant units in `_adhesion_move_creates_overlap` |
| **`scenario_03.gd`: `EdgeContact.begin_tick()`** | **Fixes S3 infinite loop** — custom tick path must clear per-tick cache |

---

## 3. Profile AFTER — 40-unit breakdown

Warmup 600, profile 800 ticks, profiler enabled:

| Units | avg_total_ms | grid | movement | allied | classify | overlap | classifier/tick |
|-------|-------------|------|----------|--------|----------|---------|-----------------|
| 4 | 0.502 | 0.007 | 0.159 | 0.054 | 0.158 | 0.114 | 32 |
| 20 | 7.139 | 0.027 | 2.814 | 1.676 | 1.713 | 1.960 | 241 |
| **40** | **28.303** | **0.073** | **10.968** | **7.438** | **6.438** | **8.048** | **856** |

**Wall-clock** (`scenario_wo010b_wallclock.gd`, profiler off, warmup 600):

| Units | avg_tick_ms |
|-------|-------------|
| 4 | 0.572 |
| 20 | 7.011 |
| **40** | **27.858** |

### Before/after summary (40 units, massed combat)

| Metric | BEFORE | AFTER | Δ |
|--------|--------|-------|---|
| avg tick (profile) | 40.0 ms | 28.3 ms | **−29%** |
| avg tick (wall-clock) | ~40 ms | 27.9 ms | **−30%** |
| classifier calls/tick | 2928 | 856 | **−71%** |
| grid overhead | 0.05 ms | 0.07 ms | unchanged (keep) |

**Scaling (wall-clock):** 4 → 20 → 40 units: 0.57 → 7.01 → 27.86 ms. Improved vs WO-010 autotest superlinear spike but still **not linear**.

---

## 4. Target assessment

| Target | Result |
|--------|--------|
| 40-unit avg tick ≤ 10 ms (cloud) | **NOT MET** (27.9 ms wall-clock) |
| Scaling closer to linear (4/20/40) | **PARTIAL** (~30% faster; exponent still >1) |
| Full regression byte-identical | **PASS** |
| Grid keep/remove decision | **KEEP** — breakdown shows <0.1 ms overhead |

**Remaining cost:** O(n²) grid-neighbor pair enumeration when all 40 units collapse into 1–2 cells during massed combat (overlap_assert ~8 ms, allied ~7 ms, movement contact ~11 ms).

---

## 5. Escalations / incidents

1. **S3 hang (infinite loop):** `scenario_03.gd` overrides `advance_one_tick()` without `EdgeContact.begin_tick()` → stale cross-tick cache. Fixed.
2. **Trace drift (ESCALATION-class):** Quantized `pose_hash` in contact cache returned wrong contacts (S3 combat 19s→74s). Fixed with exact float pose hash; verified byte-identical on full autotest.

---

## 6. Commands

```bash
# Full regression
/tmp/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . -s res://tests/scenario_wo010_autotest.gd

# Profile breakdown
/tmp/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . -s res://tests/scenario_wo010b_profile.gd

# Wall-clock (profiler off)
/tmp/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . -s res://tests/scenario_wo010b_wallclock.gd
```
