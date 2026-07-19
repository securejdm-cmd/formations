# WO-029b Completion Report — Phase 2 Close: Frame Rate + S8

**Status:** COMPLETE with S8 population escalation (see below)  
**Branch:** `cursor/wo-029b-phase2-close-fd84`  
**Base:** WO-028 tip (`cursor/wo-028-boundary-vs-band-fd84`)

## Built

### Task 0 — S8 DIRECTION + variance
- Restored S8 as a **DIRECTION** check: ratio `< 3.0` (mean+3SD band removed).
- Ran n=500 (QoD on, σ=0.045). Magnitude reported; ge3 counted.
- Variance diagnosis: **frontage geometry / bimodal single-attacker engagement** (not small-sample artifact). No tuning.

### Task 1 — S40 profile (before fix)
- **Realtime pre-fix advanced the sim on the main/render thread** (`use_sim_thread` defaulted false).
- Designer 20–35 FPS explained by GAMEPLAY_TICK≈27ms blocking the frame.
- Render effects are not the primary bottleneck once sim leaves the main thread.
- Evidence: `docs/reports/evidence_wo029b/s40_fps_diagnosis.md`.

### Task 2 — Cause-directed fix
- Default `use_sim_thread = true` for realtime gameplay (fast-mode autotests unchanged).
- HeightField: stop worker-unsafe `Engine.get_main_loop().root.get_node` (use `Constants` autoload).
- Visuals: queue shock/volley as plain data; drain on main thread.
- S40 midbattle: RefCounted `Scenario40Midbattle` via `pre_tick_callback` (tick-synchronous, worker-safe).
- S40 fast vs threaded traces **byte-identical** at 900 ticks (harness path).
- Cloud Xvfb designer path: ~95 FPS p95-implied with sim thread on.

## Files changed
- `scripts/scenario_01.gd` — default sim thread on; visual drain
- `scripts/scenario_40_mixed.gd` / `scripts/scenario_40_midbattle.gd` — midbattle on core
- `scripts/sim/sim_battle_core.gd` — pre_tick + pending visuals
- `scripts/sim/sim_thread_controller.gd` — visual handoff
- `scripts/height_field.gd` — worker-safe Constants access
- `tests/scenario_wo010_autotest.gd` — S8 DIRECTION threshold
- `tests/wo029b_*` — sweeps, profiles, trace compare
- `docs/reports/evidence_wo029b/*`, `docs/reports/WO-029b_completion.md`

## Tests

| criterion | result |
|-----------|--------|
| S8 DIRECTION instrument restored (`< 3.0`, no mean+3SD) | PASS |
| S8 n=500 report mean/sd/min/max + ge3 | PASS (see numbers) |
| S8 ge3 == 0 on every seed | **FAIL — ge3=20** (escalate; not tuned) |
| S8 variance driver named, no tune | PASS — frontage geometry / bimodal single engagement |
| Task 1 thread ownership reported | PASS — was main; now worker for realtime |
| Task 1 SIM/RENDER distributions labeled | PASS — cloud + designer notes |
| Realtime on sim thread; certs byte-identical | PASS — S40 900-tick identical; suite certs use harness |
| Cloud proxy ≥60 FPS path with thread | PASS — Xvfb ~95 FPS p95-implied |
| Designer desktop ≥60 sustained | **PENDING designer** — open `tests/scenario_40_mixed.tscn` |
| Full suite | (see suite.log) |

### S8 n=500 numbers
`ratio n=500 mean=1.702297 sd=0.800819 cv=0.4704 min=0.805779 max=3.856754 ge3=20`

## Assumptions made
NONE.

## Known issues / Escalation

### ESCALATION — S8 population DIRECTION fails at n=500
- **Work order:** WO-029b Task 0
- **Blocker:** With QoD on (σ=0.045), 20 of 500 seeds have stack ratio ≥ 3.0. The suite’s single seed (1000) still passes (~2.80). Design rule says every seed must be sublinear; we did not tune.
- **Options:**
  - A) Accept suite seed check + report ge3 as known Phase-2 debt; close Phase 2 on FPS seam.
  - B) Open a follow-up WO to fix frontage fill / single-attacker edge contact (likely geometric), then re-run n=500 to ge3=0.
  - C) Waive population DIRECTION (conflicts with “not waivable” — not recommended).
- **Recommendation:** B for correctness; A only if product owner prioritizes Phase-2 tag over S8 population purity.
- Hold v0.2 tag remains per product-owner (designer FPS confirmation still required).

## Designer build / scene
1. Pull `cursor/wo-029b-phase2-close-fd84`.
2. Run `res://tests/scenario_40_mixed.tscn` (realtime; `use_sim_thread` defaults true).
3. Confirm FPS overlay ≥60 mid-battle on the test hill.
