# COMPLETION REPORT — WO-020b — Date 2026-07-15 — Commit f3466dc77278f014b9adb3e1b3d1f6056a9150a1

**Work order:** WO-020b Giving Magnetism Teeth  
**Branch:** `cursor/wo-020b-magnetism-teeth-fd84`  
**Date:** 2026-07-15  
**Commit:** `f3466dc77278f014b9adb3e1b3d1f6056a9150a1`  
**Base:** `cursor/wo-020-full-magnetism-fd84`  
**Evidence:** `docs/reports/evidence_wo020b/`  
**Escalation:** `docs/reports/WO-020b_escalation.md` (Task 1 ratio)

---

## Built

1. **Fighting withdrawal:** for the full `3.0×(1−Agility/150)` timer the unit stays partnered, speed=0, cannot attack; free hits every tick as push-loser melee × `disengage_damage_mult` + ordered-retreat cohesion. Mutual partner clear on timer end so break-off is real.
2. **`disengage_damage_mult=2.0`** provisional (WO propose). Criteria spears≥6 / skirm≤6 PASS; **ratio ∈[1.6,1.8] ESCALATED** (armor skew → ratio≈1.30 fixed).
3. **`base_turn_rate_rad=0.20`** (was 2.5) via Task 2 drain-band selection.

---

## Constants

| Key | Value | Notes |
|-----|-------|-------|
| `disengage_damage_mult` | **2.0** | provisional; see escalation |
| `base_turn_rate_rad` | **0.20** | selected |

### Task 2 wheel times (90°, analytic + S31 empirical)

| Profile | A / mass | t90 | under-contact drain (90°) |
|---------|----------|-----|---------------------------|
| spears | 30 / 1.0 | **13.0s** | **20.80** ∈[15,30] |
| infantry | 50 / 1.0 | **7.8s** | **10.40** ∈[7,15] |
| cavalry | 70 / 1.6 | **9.0s** | (analytic) |
| skirmisher | 80 / 0.6 | **2.9s** | (analytic) |

Drain ratio spears/infantry = **2.00** ≥ 1.6. Times (~8–13s under contact) sit under peacetime ~20s+ — believable; not escalated.

---

## Scenarios

| ID | Result | Actuals |
|----|--------|---------|
| S30 | PASS* | sk 1.40s lost **4.62**/coh12.84; spears 2.40s lost **6.04**/coh17.39; ratio **1.31** (*ratio escalated) |
| S31 | PASS | spears **13.00s** drain**20.80**; inf **7.80s** drain**10.40** |
| S32 | PASS | str **89.18 / 88.49 / 79.02**; impact2=**18.904** (WO-020 was 89.18/88.84/79.19) |
| S33 | PASS | FRONT/FRONT; dots 0.945/0.945; rot **1.1°/1.1°** (partial square-up OK) |
| S34 | PASS | flank persists; no reface |

### Task 3 flank-reface re-check

Gallop ×4m = **0.299s**; infantry 90° at new rate = **7.854s**. Still impossible to reface inside the gravity window.

---

## Regression

| Gate | Result |
|------|--------|
| S1 A/B radius 4 vs 0 | **byte-identical** |
| S12 | **18 / 8.04%** |
| S23–S26 | unchanged (46.01/53.99; 76.68/23.32; 71.20/28.80; 76.68/23.32) |
| S27–S29 | unchanged |
| Certs | Fast + Threaded byte-identical |
| Meta | **PASS=66 FAIL=0 exit 0** |
| Perf40 | 1.561/1.775 → **1.563/1.786** (budget 50ms) |

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# SUITE_EXIT=0
```

---

## Files changed

- `data/combat_constants.json` — `disengage_damage_mult`, `base_turn_rate_rad`
- `scripts/sim/sim_battle_core.gd` — free-hit path; fighting withdrawal
- `scripts/unit.gd`, `scripts/sim/sim_unit_proxy.gd` — mutual break-off
- `scripts/scenario_33.gd` — rotation reporting
- `tests/scenario_wo010_autotest.gd` — WO-020b asserts
- `docs/reports/WO-020b_escalation.md`, evidence dir

---

## Assumptions made
NONE — Task 1 ratio escalated instead of altering Sec 5 duration or inventing armor-blind free hits.

## Known issues
Task 1 strength-loss ratio cannot reach [1.6, 1.8] with a shared mult while armor differs — awaiting TD choice in escalation.

## Attestation

- Branch: `cursor/wo-020b-magnetism-teeth-fd84`
- Full SHA: `f3466dc77278f014b9adb3e1b3d1f6056a9150a1`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020b-magnetism-teeth-fd84/docs/reports/WO-020b_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020b-magnetism-teeth-fd84/docs/reports/evidence_wo020b/suite_stdout.log

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020b-magnetism-teeth-fd84/docs/reports/WO-020b_completion.md
- Escalation: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020b-magnetism-teeth-fd84/docs/reports/WO-020b_escalation.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020-full-magnetism-fd84/docs/reports/WO-020_completion.md
- Suite log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020b-magnetism-teeth-fd84/docs/reports/evidence_wo020b/suite_stdout.log
