# COMPLETION REPORT — WO-014 — Date 2026-07-13 — Commit COMMIT_STAMP

**Work order:** WO-014 / WO-014b  
**Branch:** `cursor/wo-014-ranged-combat-fd84`  
**Date:** 2026-07-13  
**Commit:** `COMMIT_STAMP`  
**Source of figures:** `docs/reports/evidence_wo014b/` (sweep / smoke / suite logs on this branch)

---

## Actual branch state (summary)

| Item | Value |
|------|-------|
| `k_ranged_scale` in `data/combat_constants.json` | **0.100** |
| Sweep selection | sole GATE=true cell at k=0.100 |
| Suite process exit | **1** (S6 FAIL sets `_exit_code`; see below) |
| Smoke exit | **0** |
| Sweep exit | **0** |

---

## Built (current code)

- Foot ranged volleys: `reload_s`, ammo, doctrines, dead-zone panic, friendly fire
- Damage: Missile through armor matrix with **`k_ranged_scale`** on raw and EffectiveArmor (not `k_melee_scale`)
- Profiles: `test_archer`, `test_blocker_narrow`
- Scenarios: S12–S16 + gallery volley arc
- Trace: core 8-column identity; additive `ammo=` and EVENT lines

---

## Trace schema (standing)

Core columns (byte-identical melee compare):  
`time_sec,unit_id,strength,cohesion,kills,pos_x,pos_y,state`

Additive: trailing `ammo=N`; EVENTs `volley`, `friendly_fire`, `dead_zone_panic`, `ammo_empty`.

---

## Worked examples (`k_ranged_scale` = 0.100, falloff 100%)

**Missile vs Leather (armor 4, ×0.8):** Raw = 1.80; EffArmor = 0.32; Damage = **1.48**  
**Missile vs Plate (armor 30, ×1.2):** Raw = 1.80; EffArmor = 3.60; Damage = **0.36** (chip floor)

---

## `k_ranged_scale` sweep

**Command:**
```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo014_ranged_sweep.gd
```
**Exit:** `0` — `docs/reports/evidence_wo014b/sweep_exit.txt`

Gates: S12 approach ∈ [8%, 20%] AND S16 leather ∈ [30%, 45%] AND S16 plate chip-dominated.

| k | S12 % | S16 leather % | S16 plate % | chip | GATE |
|---|-------|---------------|-------------|------|------|
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

**Selected / committed:** `k_ranged_scale = 0.100`

---

## Smoke

**Command:**
```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/all_scenes_smoke_test.gd
```
**Exit:** `0`  
**Summary:** `[SceneSmoke] PASS 22 scenes (load + instantiate + one frame)`

---

## Full suite (invariants, certifications, regressions)

**Command:**
```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
```
**Exit:** `1` — `docs/reports/evidence_wo014b/suite_exit.txt`  
**Cause:** S6 sets `_exit_code=1` (`S6 rally unit state unexpected: marching`; `S6 no pursuit damage ticks logged`) while still printing a misleading `S6 PASS` line.

| Check | Result (this suite log) |
|-------|-------------------------|
| Compass | PASS 32/32 |
| Fast-mode certification (seed 12345) | PASS |
| Threaded certification (seed 12345) | PASS |
| Determinism | PASS |
| Reflection / overlap+adhesion (seed 1000) | PASS |
| S1 × 11 seeds | PASS (all listed) |
| S2 × 11 seeds | PASS (all listed) |
| S3 | PASS ratio=0.282 rout=76.27 |
| S9 × 11 seeds | PASS heavy_wins=11/11 |
| S10 | PASS chip floor |
| S11 | PASS |
| S6 | **FAIL** (exit code 1) |
| S12 | PASS volleys=18 approach_lost=**8.04%** panic=true |
| S13 | PASS first_volley_m **149.9 / 104.9 / 130.0** |
| S14 | PASS ff_events=1; control ff_events=0 |
| S15 | PASS volleys=3 ammo_empty |
| S16 leather | PASS lost=**44.40%** |
| S16 plate | PASS lost=**10.80%** chip_expected=10.80 |

### S1 11-seed results
| Seed | Result |
|------|--------|
| 1000 | PASS winner=red_1 combat=75.8s |
| 1001 | PASS winner=red_1 combat=80.6s |
| 1002 | PASS winner=blue_1 combat=76.0s |
| 1003 | PASS winner=blue_1 combat=83.9s |
| 1004 | PASS winner=red_1 combat=83.4s |
| 1005 | PASS winner=red_1 combat=73.2s |
| 1006 | PASS winner=red_1 combat=77.0s |
| 1007 | PASS winner=blue_1 combat=82.4s |
| 1008 | PASS winner=red_1 combat=81.0s |
| 1009 | PASS winner=red_1 combat=84.6s |
| 12345 | PASS winner=blue_1 combat=81.6s |

### S2 11-seed results
All 11 seeds: PASS combat=61.2s rout=68.12

---

## Acceptance Criteria (verbatim from WORK_ORDER_014)

- [x] Volley pipeline through armor matrix verified with a hand-traced worked example (Missile vs Leather AND vs Plate)
- [x] S12-S15 pass; volley counts, first-volley ranges, FF percentages, ammo states all in traces
- [x] Melee-only regression (S1-S3, S9-S11) byte-identical - ranged code must not touch melee paths
- [ ] All invariants + certs pass; gallery exhibit for volley arc; smoke test covers new scenes — **partial:** smoke+certs+S1–S3/S9–S11 PASS; **suite exit 1 from S6**; gallery present
- [x] No hardcoded numbers; new constants documented in the report
- [x] Report with Links footer; merge on TD approval

---

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/WO-014_completion.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-013b-armor-scale-rebalance-fd84/docs/reports/WO-013b_completion.md
- Sweep log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/evidence_wo014b/sweep_stdout.log
- Suite log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/evidence_wo014b/suite_stdout.log
- Smoke log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/evidence_wo014b/smoke_stdout.log
