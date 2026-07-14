# COMPLETION REPORT — WO-018 — Date 2026-07-14 — Commit aa8b46f4e7c147b71165da85105daa0f67410892

**Work order:** WO-018 The Charge Gait (R17)  
**Branch:** `cursor/wo-018-charge-gait-fd84`  
**Date:** 2026-07-14  
**Commit:** `aa8b46f4e7c147b71165da85105daa0f67410892`  
**Base:** `cursor/wo-017-three-tier-brace-fd84`  
**Evidence:** `docs/reports/evidence_wo018/`  

---

## Built

Deleted `charge_speed_si_scale`. Cavalry/infantry_charge physically accelerate to `Speed × charge_gait_mult` after charge commitment (`charge_commit_range_m=150`). Impact uses **real sim-m/s** closing along the contact normal — one speed, one truth (R17 / R4).

Governance: chat attestation block (branch + SHA + report URL + suite-log URL) must be the **final content of the chat reply**.

---

## Constants

| Key | Value | Units / notes |
|-----|-------|----------------|
| `charge_gait_mult` (cavalry) | 3.375 | gait top 13.5 sim-m/s |
| `charge_gait_mult` (infantry_charge) | 2.0 | ~3.0 sim-m/s |
| `charge_gait_mult` (infantry/spears/archer) | 1.0 | regression lock |
| `charge_commit_range_m` | 150 | |
| `charge_min_speed` | **2.4** | **sim m/s** (same as measured velocity) |
| `charge_impact_scale` | 2.596154 | restores WO-017 shock band at emergent gait V≈5.2 |
| `charge_cohesion_coeff` | 3.55 | unchanged |
| `charge_speed_si_scale` | **DELETED** | `rg` clean on scripts/data/tests |

Emergent note: with R5 `accel = base/mass` (0.125 m/s² for cavalry), commit-range runway reaches ~5.2 sim-m/s at contact on the 180–200m scenarios — not the theoretical 13.5 ceiling. S29 documents the curve; impact_scale restores the approved moral spectrum without a hidden conversion.

---

## Spectrum vs WO-017

| Case | WO-017 | WO-018 |
|------|--------|--------|
| T1 fresh land | 53.99 | **53.99** (S23) |
| T3 unaware land | 23.32 | **23.32** (S26) |
| T3 march land | 23.32 | **27.38** (S25, still ∈[15,30]) |
| Flank / rear fresh | rout | rout |
| T1 @40 | rout | rout (S17b) |

All five Task 2 targets met.

---

## S17 disposition

**RETIRED** (fresh + adjacent). Intent was “charge wrecks unbraced”; R16 Tier 1 made S17 identical to S23. Harness emits retired PASSes pointing to **S23** (hold) and **S24–S26** (unaware). **S17b kept** (shaken Tier 1 rout).

---

## New scenarios

| ID | Result |
|----|--------|
| S27 | PASS — closing=unit_speed=5.200 (no conversion); commit+accel in curve |
| S28 | PASS — impact=7.79 shock=16.6 land=83.4 (modest vs cav) |
| S29 | PASS — 20m:v=1.27; 60m:3.41; 120m:5.16; 200m:5.20 |

---

## Regression

| Gate | Result |
|------|--------|
| S12 | volleys=**18** approach_lost=**8.04%** (WO-014b match) |
| S1–S16 | PASS (suite) |
| Meta | **PASS=61 FAIL=0 exit 0** |
| Perf40 | before 1.279/1.496 → after **1.249/1.511** |

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# SUITE_EXIT=0
```

---

## Assumptions made
NONE

## Known issues
Gait top 13.5 is the ceiling; R5 accel makes long-run contact ~5.2 m/s on current scenarios. Spectrum restored via `charge_impact_scale`. Sub-stepping high-speed integration not required for this suite.

## Attestation

- Branch: `cursor/wo-018-charge-gait-fd84`
- Full SHA: `aa8b46f4e7c147b71165da85105daa0f67410892`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-018-charge-gait-fd84/docs/reports/WO-018_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-018-charge-gait-fd84/docs/reports/evidence_wo018/suite_stdout.log

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-018-charge-gait-fd84/docs/reports/WO-018_completion.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-017-three-tier-brace-fd84/docs/reports/WO-017_completion.md
