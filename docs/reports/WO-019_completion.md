# COMPLETION REPORT — WO-019 — Date 2026-07-15 — Commit PENDING_STAMP

**Work order:** WO-019 Making the Gallop Reachable (R18)  
**Branch:** `cursor/wo-019-reachable-gallop-fd84`  
**Date:** 2026-07-15  
**Commit:** `PENDING_STAMP`  
**Base:** `cursor/wo-018-charge-gait-fd84`  
**Evidence:** `docs/reports/evidence_wo019/`  

---

## Built

R18: `base_accel` raised so cavalry can reach gait ceiling on a realistic runway; absolute `charge_min_speed` replaced by relative `charge_min_speed_pct`; `charge_impact_scale` collapsed toward **1.0** so velocity carries Impact. High-speed march **sub-steps** keep per-substep displace < `engage_snap_max_m`.

**Root-cause fix:** march enemy query was contact-scale (~58m), so charge commitment never saw the target until too late (~8.3 m/s). Query now includes `charge_commit_range_m` — the gallop runway is real.

---

## Constants

| Key | Value | Notes |
|-----|-------|-------|
| `base_accel` | **0.96** | cavalry a=0.6; standstill d_gait≈**151.9m**, t≈22.5s |
| `charge_min_speed_pct` | **1.25** | relative; absolute `charge_min_speed` **DELETED** |
| `charge_impact_scale` | **1.006** | was 2.596; residual ~0.6% for V=13.42 vs exact 13.5×1.0 |
| `charge_cohesion_coeff` | 3.55 | unchanged |
| sub-stepping | Peak×dt ≥ snap → N=⌊disp/snap⌋+1 | Unit + SimUnitProxy identical |

Sweep table: `docs/reports/evidence_wo019/accel_sweep.txt`. Feasible band `base_accel∈[0.92,0.99]`; **0.96** committed.

---

## Spectrum vs WO-017/018

| Case | WO-017/018 | WO-019 |
|------|------------|--------|
| T1 fresh land | 53.99 | **53.99** (S23) |
| T3 unaware land | 23.32 | **23.32** (S26) |
| T3 march land | 27.38 | **28.80** (S25 ∈[15,30]) |
| Flank / T1@40 | rout | rout |

**Compensation eliminated:** scale **2.596 → 1.006**. Near 1.0 is the signal that real gallop velocity carries the moral band; residual 0.6% accounts for contact at 13.42 rather than the 13.5 ceiling.

---

## S29 run-up curve (measured)

| Run-up | v (sim-m/s) | Impact | Charged |
|--------|-------------|--------|---------|
| 20m | 2.82 | 0.00 | no |
| 60m | 7.44 (55% gait) | 11.98 | yes |
| 120m | 11.28 | 18.16 | yes |
| 200m | 13.42 (≥95% gait) | 21.60 | yes |

Impact strictly monotonic. Relative threshold hard-locks gait=1.0 units from charging.

---

## Task 3 — high-speed contact

At 13.5 m/s / 0.1s tick → **1.35m/tick > engage_snap_max_m (1.0)**. Sub-stepping implemented (2× @ 0.675m). Fast + threaded certs remain **byte-identical**. Audit: `evidence_wo019/high_speed_contact_audit.txt`.

---

## Regression

| Gate | Result |
|------|--------|
| S1–S16 | PASS (suite; gait=1.0 structurally cannot charge under R18) |
| S12 | volleys=**18** approach_lost=**8.04%** |
| S28 | impact=**3.018** shock=**6.43** land=**93.57** (vs WO-018 7.79/16.6/83.4 — modest, holds) |
| Certs | Fast + Threaded byte-identical |
| Meta | **PASS=61 FAIL=0 exit 0** |
| Perf40 | 1.249/1.511 → **1.411/1.618** (+0.16ms; under 50ms budget) |

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# SUITE_EXIT=0
```

---

## Assumptions made
NONE

## Known issues
Designer: watch S27 at battlefield zoom — 13.4 m/s gallop may look fast; do not workshop-dampen. Contact V peaks at 13.42 (ceiling 13.5) on 180–200m scenarios.

## Attestation

- Branch: `cursor/wo-019-reachable-gallop-fd84`
- Full SHA: `PENDING_STAMP`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-019-reachable-gallop-fd84/docs/reports/WO-019_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-019-reachable-gallop-fd84/docs/reports/evidence_wo019/suite_stdout.log

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-019-reachable-gallop-fd84/docs/reports/WO-019_completion.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-018-charge-gait-fd84/docs/reports/WO-018_completion.md
