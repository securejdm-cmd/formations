# COMPLETION REPORT — WO-026 — 2026-07-16 — Commit b8fe18672bbfe48115f0b2c78ac280a0cbe580e3

**Work order:** WO-026 Movement Diagnostic  
**Branch:** `cursor/wo-026-movement-diagnostic-fd84`  
**Tip SHA:** `b8fe18672bbfe48115f0b2c78ac280a0cbe580e3`  
**Code SHA:** `abaa87773f7fea6c48f87661739dddb6f4581e37`  
**Base:** WO-025 tip `4a134e7` (`cursor/wo-025-quality-of-day-fd84`)  
**Evidence:** `docs/reports/evidence_wo026/`  
**Escalation:** none (local fix)

---

## Assumptions made

NONE.

---

## Known issues

NONE new. Allied overlap assert noise on MAIN_TICK / fast-sim path unchanged (QA instrumentation).

---

## Task 1 — Micro-profile (40 units, GAMEPLAY, TickProfiler)

Subsystem (baseline, pre-fix):

| Section | ms/tick |
|---------|---------|
| movement | **25.667** |
| allied_separation | 8.951 |
| contact_classification (global counter) | 4.400 |
| combat | 0.709 |
| slope_sampling (outside movement) | 0.009 |

Movement micro (baseline):

| Component | calls/tick | ms/tick | mean µs/call | cells scanned |
|-----------|------------|---------|--------------|---------------|
| **March enemy grid query** | **65.6** | **4.524** | 68.9 | **3216/tick (49.0/call)** |
| Radius calc (incl. max scans) | 65.6 | **7.733** | — | — |
| max_closing / max_dim scans | **196.9** | **7.562** | — | — |
| Substep iterations | 32.8 (=1× per marching unit) | — | — | — |
| Charge-commit math | 32.8 | 0.042 | 1.3 | — |
| Gravity target search | 32.8 | 1.915 | 58.4 | — |
| Auto-rotation | 0.7 | 0.001 | — | — |
| Position integrate | 32.8 | 0.017 | — | — |
| Contact/overlap from movement | 42.5 | 0.511 | 12.0 | — |
| Alloc arrays / dicts | 145.8 / 65.6 | — | — | — |

**Facts:**
- Charge-commit **enemy query is per-tick** (via `enemies_for`), **not per-substep**. Substeps reuse the enemies array.
- `enemies_for` ran **~2× per marching unit** (brace + march).
- `march_enemy_query_radius_px` always took `max(contact, charge_commit_range_m≈150 + dims)`. At `spatial_grid_cell_m=80` that is **ring=3 → 7×7=49 cells/call**.
- Radius calc called `max_unit_dimension_m()` **twice** and `max_closing_speed_m()` once — each a full unit scan — **every** query (~197 scans/tick).
- Charge-commit **math** is cheap (0.042 ms); the pathology is the **wide query + max scans** feeding gravity/contact with huge candidate lists.
- Enemy query alone ≈ **17.6%** of movement; radius/max-scan ≈ **30%**; together with gravity on fat lists ≈ **majority** of the 25.7 ms.

---

## Task 2 — Disable-only charge-commit radius (ephemeral)

| | Baseline | Disable commit radius | Δ |
|--|----------|----------------------|---|
| wall avg ms | 35.812 | 25.775 | **−10.037** |
| wall p95 ms | 44.153 | 31.987 | **−12.166** |
| movement ms | 25.667 | 15.297 | **−10.370** |
| enemy_query ms | 4.524 | 1.273 | −3.250 |
| cells/call | 49.0 | 9.0 | — |
| Outcome (alive/strength @800) | 20/20 / 3483.104 | 20/20 / 3483.104 | **unchanged** |

**Answers:**
- Query is **per-tick** (not per-substep).
- Cells/call at 40 units with commit range: **49**.
- Fraction of the WO-024 24.816 ms movement attributed to this widen: disable probe recovers **~10.4 ms** (~42% of movement); remaining movement after disable still includes uncached max scans (~5 ms) and double queries.

---

## Task 3 — Local fix (implemented)

1. **Scope** `charge_commit_range` to units with `charge_gait_mult > 1` (cavalry). Infantry never enter `find_charge_commit_target`; gravity uses `engage_radius_m=4` surface gap; HOLD brace still sees all units via the non-march candidate path.
2. **Cache** `max_closing_speed_m` / `max_unit_dimension_m` once per tick.
3. **Reuse** one `enemies_for` per unit for brace + march/rout.

No substep redesign. No speculative work outside the profiled cause.

### GAMEPLAY_TICK before / after (5-run)

| | Before (WO-025 suite / profile) | After (×5 `REPEAT_GAMEPLAY`) |
|--|--------------------------------|------------------------------|
| avg mean | ~36.9 (suite single) | **20.351** (span 0.198) |
| p95 mean | ~46.6 (suite) / 44.2 (profile) | **29.070** (span 0.329) |
| Gate 50 ms | PASS | **PASS** |

### Updated breakdown (after)

| Section | ms/tick |
|---------|---------|
| movement | **9.303** |
| allied_separation | 9.028 |
| classify | 4.086 |
| combat | 0.708 |

| Micro | calls/tick | ms/tick | cells/call |
|-------|------------|---------|------------|
| enemy_query | 32.8 | 0.654 | **9.0** |
| radius_calc | 32.8 | 0.142 | — |
| max_scan | **2.0** | 0.077 | — |
| gravity | 32.8 | 0.169 | — |

---

## Regression

| Gate | Result |
|------|--------|
| Fast + threaded certs | byte-identical **PASS** |
| S1–S40 PASS lines vs WO-025 | **73/73 identical** (excl. perf timings) |
| S1 seed 12345 | combat **81.6s** unchanged |
| S29 cavalry commit speeds | unchanged (20/60/120/200 m) |
| Meta | **72/0 exit 0** |

---

## Files changed

- `scripts/tick_profiler.gd` — movement micro counters; `debug_disable_charge_commit_radius`
- `scripts/sim/sim_battle_core.gd` — gait-scoped radius, per-tick max cache, single enemies_for
- `scripts/sim/sim_unit_proxy.gd` — micro-timers in march path
- `tests/wo026_movement_probe.gd` — PROFILE / DISABLE / REPEAT
- `docs/reports/evidence_wo026/` — evidence
- `docs/reports/WO-026_completion.md` — this report
