# COMPLETION REPORT — WO-016 — Date 2026-07-14 — Commit 447c9068fab141cff27fd9e8680dd242484926af

**Work order:** WO-016 — Mounted units: momentum charges, mass & brace  
**Branch:** `cursor/wo-016-mounted-charge-fd84`  
**Date:** 2026-07-14  
**Commit:** `447c9068fab141cff27fd9e8680dd242484926af`  
**Base:** `main` post-WO-015 merge (suite exit 0)  
**Evidence:** `docs/reports/evidence_wo016/`  
**Design authority:** DESIGN_RULINGS_v1.2 R4/R5; DAMAGE_AND_CATEGORIES_v1.1 §7  

---

## Baseline (main post-merge)

| Check | Result |
|-------|--------|
| Main tip after WO-013..015 merge | suite exit **0** |
| Evidence | `docs/reports/evidence_main_wo015_merge/` (`SUITE_EXIT=0`, Meta PASS=45) |

---

## Built

1. **Mass / inertia (R5):** `data/mass_by_profile.json` (Low 0.6 / Medium 1.0 / High 1.6 / Massive 3.0); accel/decel/turn ∝ 1/mass. **No knockback.**
2. **Momentum charge (R4):** first-contact Impact = mass × closing_speed × Strength% × `charge_impact_scale`; cohesion shock + decaying `charge_amp` window (~3s). Pair latch prevents re-charge spam.
3. **Brace (D&C §7):** stationary Pierce facing charger ≥ `brace_time_s` negates charge and reflects `brace_reflect_pct` of Impact.
4. Profiles `test_cavalry` / `test_spears`; scenarios **S17–S20**; gallery braced indicator + charge flash; suite `EXPECTED_GREEN_PASS_COUNT=51`.

### Regression-safe movement
- Default `configure` starts at **cruise** so S1/S2 approach timing stays byte-identical.
- Charge scenarios call `start_from_rest()`.
- Do **not** decelerate while ENGAGED (mid-fight partner flicker used to crawl and drifted grind ~+8s).
- `charge_min_speed=3.5` keeps walking infantry contacts from charging.

---

## Worked Impact example (S17, seed 12345)

| Term | Value |
|------|-------|
| mass (High) | 1.6 |
| closing_speed | 4.0 m/s (cavalry top) |
| Strength% | 1.0 |
| charge_impact_scale | 1.0 |
| **Impact** | **1.6 × 4.0 × 1.0 × 1.0 = 6.4** |
| charge_cohesion_coeff | 14.5 |
| **shock** | **6.4 × 14.5 = 92.8** → immediate infantry cohesion rout |

---

## S17–S20 results (suite)

| Gate | Result |
|------|--------|
| S17 charge | PASS impact=6.400 shock=92.800 closing=4.000 winner=red_cav inf_str=75.88 |
| S17 adjacent | PASS closing=1.556 charged=false combat=47.4s |
| S18 brace | PASS impact=6.400 reflected=3.200 cav_str=84.54 winner=blue_spears |
| S19 late brace | PASS impact=6.400 shock=92.800 braced=false closing=4.000 |
| S20 20m | PASS closing=1.556 charged=false |
| S20 120m | PASS closing=4.000 impact=6.400 short_closing=1.556 |

---

## Execution evidence

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/wo001_smoke_test.gd
# SMOKE_EXIT=0 — Constants PASS (49 keys)

$GODOT --headless --path . -s res://tests/all_scenes_smoke_test.gd
# SCENE_SMOKE_EXIT=0 — [SceneSmoke] PASS 26 scenes

$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# SUITE_EXIT=0
# [WO-015] Meta PASS=51 FAIL=0 expected_green_pass=51 exit=0
```

---

## Suite summary (exit 0)

| Gate | Result |
|------|--------|
| Smoke / Scene smoke | PASS |
| Compass / Fast cert / Threaded cert | PASS |
| Determinism / Overlap | PASS |
| S1 × 11 / S2 × 11 | PASS (byte timings match WO-013 goldens) |
| S3–S16 | PASS |
| S17–S20 | PASS |
| Meta PASS/FAIL reconcile | PASS **51/0** exit 0 |

---

## Files changed (high level)

- `data/combat_constants.json`, `data/mass_by_profile.json`, `data/units/test_cavalry.json`, `data/units/test_spears.json`
- `scripts/charge_combat.gd`, `scripts/combat_resolver.gd`, `scripts/sim/sim_battle_core.gd`, `scripts/sim/sim_unit_proxy.gd`, `scripts/unit.gd`, `scripts/visual_gallery.gd`
- `scripts/scenario_17.gd`–`20.gd`, `tests/scenario_17.tscn`–`20.tscn`
- `tests/scenario_wo010_autotest.gd`, `tests/wo001_smoke_test.gd`
- `docs/work_orders/WORK_ORDER_016.md`, this report, evidence dir

## Assumptions

- `charge_cohesion_coeff=14.5` tuned so a full-speed High-mass charge at Strength 100% routs medium infantry via shock (WO “routs fast at HIGH strength”).
- Turn rate only applies when heading error > ~0.15 rad (avoids micro-facing noise on on-axis marches).

## Known issues

None for acceptance. Allied overlap stderr noise on PerfScale remains pre-existing (non-gating).

---

## Attestation

- Branch: `cursor/wo-016-mounted-charge-fd84`
- Full SHA: `447c9068fab141cff27fd9e8680dd242484926af`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-016-mounted-charge-fd84/docs/reports/WO-016_completion.md
- Suite log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-016-mounted-charge-fd84/docs/reports/evidence_wo016/suite_stdout.log

## Links

- Index: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-016-mounted-charge-fd84/docs/reports/INDEX.md
- Previous (WO-015): https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/WO-015_completion.md
- Main baseline evidence: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/evidence_main_wo015_merge/suite_exit.txt
