# COMPLETION REPORT — WO-016b — Date 2026-07-14 — Commit c975e3e160b8a1d521849edebe7f01e8bca6c942

**Work order:** WO-016 TD review remediation (scale + R15 + S17b)  
**Branch:** `cursor/wo-016b-charge-scale-r15-fd84`  
**Date:** 2026-07-14  
**Commit:** `c975e3e160b8a1d521849edebe7f01e8bca6c942`  
**Base:** `cursor/wo-016-mounted-charge-fd84`  
**Evidence:** `docs/reports/evidence_wo016b/`  

---

## (1) Scale diagnosis — root cause

**Not a per-tick mismatch.** Movement and measured `current_speed_m_s` are consistent:

```
sim_m_s = speed_stat × speed_stat_meters_per_10s / 10
```

With `speed_stat_meters_per_10s = 1.0`, Speed 40 → **4.0 sim-m/s**. That constant was calibrated for infantry walk (~1.5 m/s at Speed 15). Absolute SI for cavalry gallop (12–15 m/s) is understated by **~3.375×**. Same family as “scale-bug” calibrations: correct internal units, wrong absolute meter.

Raising the **global** movement constant to 3.375 made closing report 13.5 but shortened approach windows and failed **S12** (volleys 18→6, approach_lost 8%→2.7%).

**Fix:** keep movement at `1.0`; add `charge_speed_si_scale = 3.375` for Impact, `charge_min_speed` (SI), and reported `closing_speed`. Events also store `closing_speed_sim`.

| Quantity | Value |
|----------|-------|
| Cavalry top sim | 4.0 m/s |
| Cavalry top SI (`×3.375`) | **13.5 m/s** |
| Impact | 1.6 × 13.5 × 1.0 × 1.0 = **21.6** |

---

## (2) R15 (DESIGN_RULINGS append)

Fresh medium infantry charge must land cohesion **∈ [15, 30]**, not rout.

| Term | Value |
|------|-------|
| charge_cohesion_coeff | 3.55 |
| shock | 21.6 × 3.55 = **76.68** |
| landing cohesion | 100 − 76.68 = **23.32** ✓ |

---

## (3) S17b

Infantry start cohesion **40** → land 40 − 76.68 = **−36.68** → rout finish. PASS.

---

## Suite (exit 0)

| Gate | Result |
|------|--------|
| S1–S16 | PASS (S12 restored) |
| S17 / adj / S17b / S18–S20 | PASS |
| Meta | PASS=52 FAIL=0 exit 0 |

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# SUITE_EXIT=0
```

---

## Attestation

- Branch: `cursor/wo-016b-charge-scale-r15-fd84`
- Full SHA: `c975e3e160b8a1d521849edebe7f01e8bca6c942`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-016b-charge-scale-r15-fd84/docs/reports/WO-016b_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-016b-charge-scale-r15-fd84/docs/reports/evidence_wo016b/suite_stdout.log
