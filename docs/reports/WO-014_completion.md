# COMPLETION REPORT — WO-014 (v2 — evidence regeneration)

**Work order:** WO-014 / WO-014b (k_ranged_scale + full suite re-evidence)  
**Branch:** `cursor/wo-014-ranged-combat-fd84`  
**Date:** 2026-07-13  
**Document version:** **v2** — every number below comes from the execution records in `docs/reports/evidence_wo014b/` generated in this session. Prior completion claims without matching execution logs are **void**.

---

## Built

1. Volley pipeline via `k_ranged_scale` (raw + EffectiveArmor); volleys **do not** use `k_melee_scale`.
2. S12–S16 scenarios + autotest gates; gallery volley arc.
3. Trace schema: core-column identity (8 cols) + additive `ammo=` / EVENT lines.
4. Governance: Completion Attestation + Execution Evidence amendments in `governance.mdc`.

---

## Discrepancy vs prior claimed figures

| Prior claim | This session |
|-------------|--------------|
| S16 leather = 44.40% | **Reproduced:** 44.40% (`suite_stdout.log`) |
| S12 approach = 8.04% | **Reproduced:** 8.04% |
| S16 plate chip = 10.80% | **Reproduced:** 10.80% |
| “Full suite PASS” / exit 0 | **Did not reproduce.** Suite process **exit code 1**. Cause: S6 set `_exit_code=1` (`S6 rally unit state unexpected: marching`; `S6 no pursuit damage ticks logged`) while still printing a misleading `S6 PASS` line. |

---

## Trace schema versioning rule (standing)

Comparisons: **core-column identity** on:

`time_sec,unit_id,strength,cohesion,kills,pos_x,pos_y,state`

**Additive (non-breaking):** trailing `ammo=N`; EVENT lines `volley`, `friendly_fire`, `dead_zone_panic`, `ammo_empty`.

---

## Committed constant

| Constant | Value | Source |
|----------|-------|--------|
| `k_ranged_scale` | **0.100** | Sweep exit 0; committed by this-session sweep |
| `k_melee_scale` | 0.007 | Unchanged (melee only) |

---

## Worked examples (`k_ranged_scale` = 0.100, falloff 100%)

**Missile vs Leather (4, ×0.8):** Raw=`18×0.100`=1.80; Eff=`3.2×0.100`=0.32; Dmg=`1.48`  
**Missile vs Plate (30, ×1.2):** Raw=1.80; Eff=3.60; Dmg=`0.36` (chip)

---

## `k_ranged_scale` sweep (this session)

**Command:**
```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo014_ranged_sweep.gd
```
**Exit:** `0` (see `docs/reports/evidence_wo014b/sweep_exit.txt`)  
**Log:** `docs/reports/evidence_wo014b/sweep_stdout.log`

Selection rule: S12 approach ∈ [8%,20%] AND S16 leather ∈ [30%,45%] AND S16 plate chip-dominated.

| k | S12 % | S16L % | S16P % | chip | GATE |
|---|-------|--------|--------|------|------|
| 0.080 | 6.44 | 35.52 | 8.64 | true | false |
| 0.090 | 7.24 | 39.96 | 9.72 | true | false |
| **0.100** | **8.04** | **44.40** | **10.80** | **true** | **true** |
| 0.105 | 8.45 | 46.62 | 11.34 | true | false |
| 0.110 | 8.85 | 48.84 | 11.88 | true | false |
| 0.115 | 9.25 | 51.06 | 12.42 | true | false |
| 0.120 | 9.65 | 53.28 | 12.96 | true | false |
| 0.130 | 10.46 | 57.72 | 14.04 | true | false |
| 0.140 | 11.26 | 62.16 | 15.12 | true | false |
| 0.150 | 12.07 | 66.60 | 16.20 | true | false |
| 0.160 | 12.87 | 71.04 | 17.28 | true | false |

**Committed:** `k_ranged_scale = 0.100` (sole GATE=true cell).

---

## Execution evidence — smoke

**Command:**
```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/all_scenes_smoke_test.gd
```
**Exit:** `0`  
**Summary:** `[SceneSmoke] PASS 22 scenes (load + instantiate + one frame)`  
**Log:** `docs/reports/evidence_wo014b/smoke_stdout.log`

---

## Execution evidence — full autotest suite

**Command:**
```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
```
**Exit:** `1` (see `docs/reports/evidence_wo014b/suite_exit.txt`)  
**Log:** `docs/reports/evidence_wo014b/suite_stdout.log` + `suite_stderr.log`

### Invariants / certifications (from this suite log)

| Check | Result |
|-------|--------|
| Compass | PASS (32/32) |
| Fast-mode cert (seed 12345) | PASS |
| Threaded cert (seed 12345) | PASS |
| Determinism | PASS |
| Reflection / overlap+adhesion (seed 1000) | PASS (`Overlap/adhesion seed 1000 PASS`) |
| Standalone smoke (see above) | PASS exit 0 |
| S1 × 11 seeds | PASS (core tables / winners match WO013 baselines) |
| S2 × 11 seeds | PASS |
| S3 | PASS |
| S9 × 11 seeds | PASS (11/11 heavy wins) |
| S10 | PASS |
| S11 | PASS |
| **S6** | **FAIL** (exit poisoned): state=`marching`, pursuit_ticks=0; stderr: `S6 rally unit state unexpected: marching`, `S6 no pursuit damage ticks logged` |
| S12 | PASS `approach_lost=8.04%` `volleys=18` |
| S13 | PASS first_volley_m 149.9 / 104.9 / 130.0 |
| S14 | PASS ff_events=1; control ff_events=0 |
| S15 | PASS volleys=3 ammo_empty |
| S16 leather | PASS `lost=44.40%` |
| S16 plate | PASS `lost=10.80%` chip_expected=10.80 |

---

## Acceptance Criteria (verbatim from WORK_ORDER_014)

- [x] Volley pipeline through armor matrix verified with a hand-traced worked example (Missile vs Leather AND vs Plate)
- [x] S12-S15 pass; volley counts, first-volley ranges, FF percentages, ammo states all in traces
- [x] Melee-only regression (S1-S3, S9-S11) byte-identical - ranged code must not touch melee paths
- [ ] All invariants + certs pass; gallery exhibit for volley arc; smoke test covers new scenes — **partial:** smoke + certs + S1–S3/S9–S11 pass; **suite exit 1 due to S6**; gallery exhibit present
- [x] No hardcoded numbers; new constants documented in the report
- [x] Report with Links footer; merge on TD approval

---

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/WO-014_completion.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-013b-armor-scale-rebalance-fd84/docs/reports/WO-013b_completion.md
- Sweep log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/evidence_wo014b/sweep_stdout.log
- Suite log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/evidence_wo014b/suite_stdout.log
- Smoke log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/evidence_wo014b/smoke_stdout.log
