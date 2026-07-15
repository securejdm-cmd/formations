# COMPLETION REPORT — WO-024 — 2026-07-15 — Commit 2f4385f65b550444b609a560db89b5c2ff982b48

**Work order:** WO-024 Honest Numbers: Perf, Gravity & Sensitivity  
**Branch:** `cursor/wo-024-honest-numbers-fd84`  
**Tip SHA:** `2f4385f65b550444b609a560db89b5c2ff982b48`  
**Code SHA:** `bef274db8e4de7c1721e8c408f2e1b7cb3344e03`  
**Date:** 2026-07-15  
**Base:** WO-023 tip `99a43d8` (`cursor/wo-023-gate2-blockers-fd84`)  
**Evidence:** `docs/reports/evidence_wo024/`  
**Escalation:** `docs/reports/WO-024_escalation.md` (S3 gravity A/B traces)

---

## Assumptions made

NONE.

---

## Built

1. **GAMEPLAY_TICK** — second canonical perf metric: 800 main-thread `advance_one_tick()` on `scenario_40_perf`, no sim_thread, `fast_sim_mode=false` (overlap assert OFF, periodic CSV/EVENT rows OFF). `MAIN_TICK` retained for QA-cost comparison. Suite prints both; **50 ms gate applies to GAMEPLAY_TICK only**. No optimization.
2. **Surface-gap gravity (DEFECT)** — `FormationGeometry.surface_gap_along_facing_m`; `Magnetism.find_gravity_target` compares that gap to `engage_radius_m` (still 4.0 — not widened).
3. **Sensitivity curve (DATA ONLY)** — ephemeral push overrides; wobble ±15% ephemeral; no constant commits.
4. **Governance** — `.cursor/rules/governance.mdc`: "Perf gates are measured in GAMEPLAY configuration. Test-mode instrumentation is never part of a perf gate."
5. **Cert wiring** — `force_trace_logging` so fast/threaded certification can still compare byte traces on the gameplay path without re-enabling overlap-assert QA on GAMEPLAY_TICK.

---

## Task 1 — GAMEPLAY_TICK

### Definitions

| Metric | Config |
|--------|--------|
| **GAMEPLAY_TICK** (gate) | 800 × `advance_one_tick`, main thread, no sim_thread, `fast_sim_mode=false` |
| **MAIN_TICK** (comparison) | same, `fast_sim_mode=true` (overlap assert + periodic trace rows ON) |

### 5-run variance (`wo024_gameplay_tick_probe.gd -- REPEAT_BOTH`)

| Metric | avg mean | p95 mean | p95 span |
|--------|---------:|---------:|---------:|
| GAMEPLAY_TICK | **36.792** | **46.285** | 0.270 |
| MAIN_TICK | **46.961** | **59.990** | 0.189 |

### QA instrumentation cost (MAIN − GAMEPLAY)

| | Δ ms | % of GAMEPLAY |
|--|-----:|--------------:|
| avg | **10.169** | **27.6%** |
| p95 | **13.705** | **29.6%** |

### 50 ms gate

**GAMEPLAY_TICK p95 mean = 46.285 ms → PASS** (suite sample p95=46.382). **No optimization performed.**

### Subsystem breakdown (GAMEPLAY, TickProfiler ON, 40 units, WO-010b method)

| Subsystem | ms/tick |
|-----------|--------:|
| total (section sum) | 34.969 |
| movement / substepping | 24.816 |
| allied separation | 8.964 |
| contact classification | 4.370 |
| combat resolution | 0.699 |
| adhesion | 0.229 |
| adhesion_post | 0.172 |
| grid | 0.048 |
| victory/epilogue | 0.031 |
| slope sampling | 0.010 |
| overlap_assert | 0.001 |
| trace_logging | 0.000 |

Wall-clock under profiler: avg 34.962 / p95 43.253.

### Historical figures superseded

| Prior figure | Status |
|--------------|--------|
| WO-011..WO-022 `Perf40 sim_thread p95=…` | Still **non-comparable** (WO-023) |
| WO-023 `MAIN_TICK` as gate / "canonical budget signal" | **Superseded** — GATE is now **GAMEPLAY_TICK**; MAIN_TICK remains the **test-config** reference and QA-cost baseline |
| Any claim that MAIN_TICK ≅ shipped tick | **Superseded** — MAIN includes QA equipment (~+29% p95 here) |

---

## Task 2 — Engagement gravity = surface gap

### Fix

`engage_radius_m` unchanged at **4.0**. Proximity is min surface gap along facing (block surfaces), not center separation.

### S33 square-up

| | Before (WO-020b) | After (WO-024) |
|--|-----------------:|---------------:|
| rot_deg | **1.1 / 1.1** | **17.3 / 17.3** |
| facing dots | 0.945 / 0.945 | **1.000 / 1.000** |
| edges | FRONT/FRONT | FRONT/FRONT |

Real square-up within the gravity window (not the bogus 1.1° "partial").

### Flank-charge safety (WO-020 Task 1 re-check)

Analytic (radius still 4.0 m surface gap; gallop 13.4 m/s):

- flank cross = **0.299 s**
- infantry 90° wheel = **7.854 s** (ratio **26.3×**)

**Still impossible to reface a gallop flanker inside the gravity window.** S34: `flank_persist=true`, `no_reface=true`.

### Gravity A/B

| | Result |
|--|--------|
| S1 | **byte-identical** |
| S2 | **byte-identical** |
| S3 | **ESCALATED** — see `WO-024_escalation.md` (519/739 trace lines differ; winner/combat identical) |

---

## Task 3 — Push sensitivity curve (DATA ONLY)

Flat; gait 1.0; defender push=50; NO charge; 11 seeds. Default wobble ±5%.

| Edge | Atk push | Atk win% | Mean combat_s | Mean STR@rout |
|-----:|---------:|---------:|--------------:|--------------:|
| 0% | 50 | **63.6** | 80.0 | 58.39 |
| 2% | 51 | **100.0** | 70.2 | 54.55 |
| 5% | 52.5 | **100.0** | 67.2 | 54.55 |
| 10% | 55 | **100.0** | 65.8 | 54.77 |
| 20% | 60 | **100.0** | 64.2 | 55.52 |
| 50% | 75 | **100.0** | 61.2 | 56.49 |

### Wobble ±15% (ephemeral)

| Edge | Win% @ ±5% | Win% @ ±15% | Δ |
|-----:|----------:|------------:|--:|
| 0% | 63.6 | 63.6 | **+0.0** |
| 5% | 100.0 | 100.0 | **+0.0** |

Noise at ±15% does **not** overcome a persistent 5% push edge; at equal push, ±15% does not move the 63.6% first-mover split.

No tuning. No constant commits.

---

## Task 4 — Regression lock

| Gate | Result |
|------|--------|
| S1–S40 | clean |
| S12 | **18 / 8.04%** |
| S23–S29 | unchanged spectrum |
| Fast + threaded cert | **byte-identical** PASS |
| Determinism | PASS |
| Overlap/adhesion | PASS |
| Matrix determinism | **PASS** |
| Meta | **PASS=72 FAIL=0 exit 0** |
| GAMEPLAY_TICK gate | **PASS** (p95 46.382) |

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# SUITE_EXIT=0
```

Note: S32 soft numbers drifted slightly under working gravity (`str_rech` 79.02→78.95; `impact2` 18.904→19.089) — still within soft gates; no rebaseline.

---

## Files changed

- `scripts/formation_geometry.gd` — `surface_gap_along_facing_m`
- `scripts/magnetism.gd` — gravity uses surface gap
- `scripts/sim/sim_battle_core.gd` — `trace_logging_enabled` / `force_trace_logging`; profiled slope split; gate traces
- `scripts/scenario_01.gd` — `force_trace_logging` passthrough
- `tests/scenario_wo010_autotest.gd` — GAMEPLAY_TICK + MAIN_TICK; S33 real square-up; cert force-trace
- `tests/wo024_*.gd` — probes (perf, gravity, sensitivity, S3 diff, cert smoke)
- `.cursor/rules/governance.mdc` — GAMEPLAY perf-gate rule
- `docs/reports/WO-024_completion.md`, `WO-024_escalation.md`, `evidence_wo024/`

---

## Known issues

1. **S3 gravity A/B** not byte-identical — escalated (flank scenario + working gravity).
2. Overlap-assert stderr floods remain on MAIN_TICK / dense scenarios (QA path only).

---

## Attestation

- Branch: `cursor/wo-024-honest-numbers-fd84`
- Full SHA: `2f4385f65b550444b609a560db89b5c2ff982b48`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/WO-024_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/evidence_wo024/suite_stdout.log

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/WO-024_completion.md
- Escalation: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/WO-024_escalation.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-023-gate2-blockers-fd84/docs/reports/WO-023_completion.md
- Suite log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/evidence_wo024/suite_stdout.log
- Sensitivity: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/evidence_wo024/sensitivity_curve.md
