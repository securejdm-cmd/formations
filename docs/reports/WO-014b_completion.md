# COMPLETION REPORT — WO-014b — Date 2026-07-13 — Commit ee611b46d6f7a2e6254d511a54b4df85fafb231a

**Work order:** WO-014b (ranged scale sweep + certification on WO-014 branch)  
**Branch:** `cursor/wo-014-ranged-combat-fd84`  
**Date:** 2026-07-13  
**Commit:** `ee611b46d6f7a2e6254d511a54b4df85fafb231a`  
**Fresh path:** this file is `docs/reports/WO-014b_completion.md` (does not reuse `WO-014_completion.md`)  
**Evidence (this run):** `docs/reports/evidence_wo014b_r2/`

---

## Actual branch state

| Item | Value |
|------|-------|
| `k_ranged_scale` in `data/combat_constants.json` | **0.100** (committed) |
| Sweep sole GATE=true cell | **k=0.100** |
| Sweep exit | **0** |
| Smoke exit | **0** |
| Suite process exit | **1** (S6 push_error: unexpected `marching` + no pursuit ticks; misleading `S6 PASS` still printed) |

---

## Execution commands (this run)

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo014_ranged_sweep.gd
# → docs/reports/evidence_wo014b_r2/sweep_*.log  SWEEP_EXIT=0

$GODOT --headless --path . -s res://tests/all_scenes_smoke_test.gd
# → docs/reports/evidence_wo014b_r2/smoke_*.log  SMOKE_EXIT=0
# Summary: [SceneSmoke] PASS 22 scenes (load + instantiate + one frame)

$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# → docs/reports/evidence_wo014b_r2/suite_*.log  SUITE_EXIT=1
```

---

## Worked examples (`k_ranged_scale` = 0.100, falloff 100%)

**Missile vs Leather (armor 4, ×0.8):** Raw = 1.80; EffArmor = 0.32; Damage = **1.48**  
**Missile vs Plate (armor 30, ×1.2):** Raw = 1.80; EffArmor = 3.60; Damage = **0.36** (chip floor)

---

## `k_ranged_scale` sweep (fresh)

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

## S12–S16 actuals (fresh suite log)

| Scenario | Result |
|----------|--------|
| S12 | PASS volleys=18 approach_lost=**8.04%** total_lost=9.33 panic=true |
| S13 FIRE_ON_SIGHT | PASS first_volley_m=**149.9** |
| S13 FIRE_AT_70 | PASS first_volley_m=**104.9** |
| S13 FIRE_ON_ENGAGED | PASS first_volley_m=**130.0** |
| S14 | PASS ff_events=1 friendly_lost=0.03 |
| S14 control | PASS ff_events=0 |
| S15 | PASS volleys=3 ammo_empty=true |
| S16 leather | PASS volleys=30 lost=**44.40%** |
| S16 plate | PASS volleys=30 lost=**10.80%** chip_expected=10.80 |

---

## Invariants + certifications (fresh suite)

| Check | Result |
|-------|--------|
| Compass | PASS 32/32 |
| Fast-mode certification (seed 12345) | PASS |
| Threaded certification (seed 12345) | PASS |
| Determinism | PASS |
| Overlap/adhesion (seed 1000) | PASS |
| S5 | PASS |
| S6 | **FAIL** (`ERROR: S6 rally unit state unexpected: marching`; `ERROR: S6 no pursuit damage ticks logged`) — process exit 1; stdout still prints misleading `S6 PASS` |
| S7 | PASS |
| S8 | PASS (ratio logged) |

---

## Melee regression — S1 × 11 seeds

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

## Melee regression — S2 × 11 seeds

All 11 seeds: PASS combat=61.2s rout=68.12

## Melee regression — S3 / S9 / S10 / S11

| Scenario | Result |
|----------|--------|
| S3 | PASS ratio=0.282 rout=76.27 |
| S9 | PASS heavy_wins=**11/11** casualty_ratio_seed1000=0.144 |
| S10 | PASS winner=blue_1 chip_tick=0.0350 trace_floor_ok=true |
| S11 | PASS control=55.2s / anti_armor=63.8s |

### S9 × 11 seed detail (from traces)

| Seed | combat_s | winner_strength |
|------|----------|-----------------|
| 1000 | 40.0 | 92.46 |
| 1001 | 40.2 | 92.36 |
| 1002 | 40.2 | 92.37 |
| 1003 | 40.2 | 92.41 |
| 1004 | 40.4 | 92.28 |
| 1005 | 40.2 | 92.39 |
| 1006 | 40.0 | 92.51 |
| 1007 | 40.0 | 92.51 |
| 1008 | 39.8 | 92.55 |
| 1009 | 40.2 | 92.41 |
| 12345 | 40.2 | 92.41 |

---

## Assumptions made

NONE

## Known issues

- Suite process exit **1** from S6 assertion failures (pursuit/rally), unrelated to ranged scale; stdout still prints `S6 PASS`.
- Early stderr may show transient `Constants` compile noise from Godot script reload; suite then proceeds and completes.

---

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/WO-014b_completion.md
- Index: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/INDEX.md
- Previous report (WO-014 path): https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/WO-014_completion.md
- Sweep log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/evidence_wo014b_r2/sweep_stdout.log
- Suite log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/evidence_wo014b_r2/suite_stdout.log
- Smoke log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/evidence_wo014b_r2/smoke_stdout.log
