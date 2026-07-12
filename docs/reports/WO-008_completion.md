# COMPLETION REPORT — WO-008

**Work order:** WO-008 — Edge-Based Contact: Flanks & Corners  
**Branch:** `cursor/fast-harness-wo008-rerun-fd84`  
**Date:** 2026-07-12  
**TD rulings applied:** S3 band re-derive, S4 corner instrumentation, S3 allied overlap release, accelerated test harness

---

## Assumptions made

**NONE**

---

## Accelerated test harness (TD standing infrastructure)

| Item | Implementation |
|------|----------------|
| Fast mode | `scripts/sim_harness.gd` — `RunMode.FAST` tight-loops `advance_one_tick()` at fixed 10 Hz math, no frame waits |
| Realtime reference | `RunMode.REALTIME` drives `simulate_realtime_step(tick_interval)` — same tick math, no wall-clock coupling |
| Headless driver | `tests/sim_harness_runner.gd` — spawn + ready helpers |
| Designer play | `_process` remains for non-headless sessions only; all `headless_mode` scenarios disable Godot process loop |
| Fixed-tick probes | `SimHarness.run_ticks()` for Scenario 4 drain harness (50 ticks, no `battle_over`) |

### Fast-mode certification (permanent autotest assertion)

| Check | Result |
|-------|--------|
| Seed | **12345** Scenario 1 |
| Realtime vs fast trace CSV | **BYTE-IDENTICAL** |
| Assertion | First step in `tests/scenario_wo008_autotest.gd` |

All automated acceptance harnesses (`scenario_01_autotest`, `scenario_wo006/007/007b_autotest`, `scenario_wo008_autotest`) now use fast mode.

---

## S3 band derivation (TD ruling 1)

| Item | Value |
|------|-------|
| TD accepted band | **[0.28, 0.45]** |
| TD baseline ratio (two-attacker harness) | **0.32** |
| Rationale | Two-attacker configuration compounds beyond per-edge multipliers; single-edge mults (2.0 shift / 1.5 casualty) do not bound combined front+flank pacing |

Prior band [0.45, 0.60] superseded.

---

## Regression (Scenarios 1 & 2) — fast mode re-run

| Check | Result |
|-------|--------|
| S1 winner / combat | **11/11 PASS** (±0.15s) |
| S2 winner / combat / rout | **11/11 PASS** |
| Determinism (seed 12345) | **PASS** |
| Fast certification (seed 12345) | **PASS** |
| Wall-clock coupling detected | **NONE** |

---

## Scenario 3 — Flank + allied separation re-run (seed 1000, fast mode)

### Resolver changes (this re-run)

| Change | File |
|--------|------|
| Contact snap on **all** engagement pairs (not head-on only) | `scenario_01.gd` `_try_begin_engagement()` |
| Allied overlap separation each tick | `scenario_01.gd` `_resolve_allied_overlaps()` |
| `separate_allied_overlap()` iterative push-apart | `combat_resolver.gd` |
| Scripted flank position maintenance **removed** (prior ruling) | `scenario_03.gd` |

| Metric | TD baseline | Post-rerun (fast mode) |
|--------|-------------|----------------------|
| Combat | 22.0s | **54.0s** |
| Ratio (S3/S1) | **0.32** | **0.79** |
| Blue `strength_at_rout` | 78.60% | **67.52%** |
| Blue LEFT drain | 50.3 | **8.43** |
| Non-routing overlap assertion | — | **PASS** (allied separation active) |

**ESCALATE:** Ratio **0.79** remains outside band **[0.28, 0.45]**. Overlap assertion now passes with allied separation, but combined front+flank pacing still diverges — front drain **0.00**, LEFT drain **8.43** vs TD baseline **50.3**. Trace: `tests/traces/scenario_03_1000.csv`.

---

## Scenario 4 — Three-mode drain (seed 1000, 50 ticks, fast mode)

### Post-fix (corner solver + segment harness + head-on skip)

| Mode | Drain/s | Edge label | Notes |
|------|---------|------------|-------|
| FRONT | **3.163** | front | |
| SIDE | **6.811** | left | side/front **2.15×** |
| CORNER | **5.663** | front+left | **strict-between PASS** |

### Corner instrumentation

| Metric | Value |
|--------|-------|
| front contact | **11.119 m** |
| left contact | **10.373 m** |
| balance_delta | **0.746 m** |
| shift_blend | **1.483** |
| casualty_blend | **1.241** |
| corner/front measured | **1.790** |
| blend expected | **1.345** (within 0.5 tol) |

---

## Resolver fixes (cumulative)

| Fix | File |
|-----|------|
| Head-on loop skips pairs with meaningful flank/rear segment contact | `scenario_01.gd` |
| `has_non_front_segment_contact` checks both orientations | `edge_contact.gd` |
| S4 side/corner use spawn-contact segment harness | `scenario_04.gd` |
| Corner spawn brute-force solver (~50/50 lengths) | `scenario_04.gd` |
| Contact snap on all contact pairs at engagement | `scenario_01.gd` |
| Allied overlap separation | `combat_resolver.gd`, `scenario_01.gd` |

---

## Files changed

| File | Change |
|------|--------|
| `scripts/sim_harness.gd` | **NEW** — fast/realtime/tick-count drivers |
| `tests/sim_harness_runner.gd` | **NEW** — headless spawn helpers |
| `scripts/scenario_01.gd` | Fast mode flag, allied separation, universal contact snap, headless `_process` disable |
| `scripts/combat_resolver.gd` | `separate_allied_overlap()` |
| `scripts/scenario_03.gd` | Flank release without maintenance; headless process disable |
| `tests/scenario_wo008_autotest.gd` | Fast certification + fast-mode full suite |
| `tests/scenario_*_autotest.gd` | All acceptance harnesses use fast mode |

---

## Open escalations

1. **S3 post-release ratio 0.79** vs TD baseline 0.32 — flank/front combined pacing diverges; front drain zero, LEFT drain 8.43 vs expected 50.3 (trace attached).
