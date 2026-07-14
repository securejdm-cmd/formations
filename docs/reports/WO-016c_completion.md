# COMPLETION REPORT — WO-016c — Date 2026-07-14 — Commit 9f3ff9f90f525eff45e0f6ba552dcc5c4dd4cfad

**Work order:** WO-016c directional charge shock (R15 extension)  
**Branch:** `cursor/wo-016c-directional-charge-shock-fd84`  
**Date:** 2026-07-14  
**Commit:** `9f3ff9f90f525eff45e0f6ba552dcc5c4dd4cfad`  
**Base:** `cursor/wo-016b-charge-scale-r15-fd84`  
**Evidence:** `docs/reports/evidence_wo016c/`  

---

## (1) Directional R15

Charge cohesion shock is now:

```
base_shock = Impact × charge_cohesion_coeff
shock = base_shock × edge_casualty_mult(contact)
```

| Edge | Mult (`edge_mult_*_casualty`) | Role |
|------|-------------------------------|------|
| front | 1.0 | Frontal fresh → wavering band [15, 30] |
| side (left/right) | 1.5 | Flank routs fresh |
| rear | 2.0 | Hardest rout |

Closing speed for **Impact** is measured along the **contact inward normal** (WO-016 wording). Brace threat detection keeps the cheap front-axis `closing_speed_into_defender` so perf_40 is unaffected.

Frontal wavering supersedes the earlier flat “any charge lands [15,30]” reading of R15. Coefficient stays **3.55** (WO-016b); flank/rear ride the edge mult, not a frontal retune.

`DESIGN_RULINGS_v1.2.md` R15 updated accordingly.

---

## (2) Spectrum (fresh 100 cohesion, Impact 21.6)

| Approach | edge | edge_mult | base_shock | shock | land |
|----------|------|-----------|------------|-------|------|
| front (S22 / S17) | front | 1.0 | 76.68 | 76.68 | **23.32** (waver) |
| flank (S21) | left | 1.5 | 76.68 | 115.02 | **−15.02** (rout) |
| rear (probe) | rear | 2.0 | 76.68 | 153.36 | **−53.36** (rout) |

S17b (predrain 40, frontal) unchanged: 40 − 76.68 → rout finish.

---

## (3) Scenarios

| ID | Intent | Result |
|----|--------|--------|
| S21 | Flank charge vs fresh → elevated mult + rout | PASS |
| S22 | Frontal facing fresh → R15 waver band, not shock-rout | PASS |

Suite Meta **PASS=54** (prior 52 + S21 + S22).

---

## Suite (exit 0)

| Gate | Result |
|------|--------|
| S1–S20 | PASS (incl. S17 frontal edge assert) |
| S21 / S22 | PASS |
| Meta | PASS=54 FAIL=0 exit 0 |

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# SUITE_EXIT=0
```

---

## Attestation

- Branch: `cursor/wo-016c-directional-charge-shock-fd84`
- Full SHA: `9f3ff9f90f525eff45e0f6ba552dcc5c4dd4cfad`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-016c-directional-charge-shock-fd84/docs/reports/WO-016c_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-016c-directional-charge-shock-fd84/docs/reports/evidence_wo016c/suite_stdout.log
