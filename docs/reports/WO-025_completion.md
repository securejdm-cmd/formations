# COMPLETION REPORT — WO-025 — 2026-07-16 — Commit 01f4788b1ea4df4a6a82ec01dafe2716e348f68a

**Work order:** WO-025 Quality of the Day: Persistent Variance  
**Branch:** `cursor/wo-025-quality-of-day-fd84`  
**Base:** WO-024 tip  
**Evidence:** `docs/reports/evidence_wo025/`  
**Escalation:** `docs/reports/WO-025_escalation.md` (Task 2 — no σ satisfies R21 bands)

---

## Assumptions made

NONE.

---

## Built

### S3 rebaseline (separate commit, before R21)

Working-gravity flank metrics **HOLD**: ratio **0.282** ∈ [0.28,0.45]; rout **76.13** > 67%; LEFT drain **58.68**. Suite gates enforced (`[WO-025] S3`).

### R21

Appended to `docs/DESIGN_RULINGS_v1.2.md`.

### quality_of_day (Task 1)

| Item | Choice |
|------|--------|
| Distribution | **Gaussian N(1, σ)** via Box-Muller on the **battle-seeded** RNG stream (two `randf` draws). Justified: “quality of the day” is naturally bell-shaped; extremes rarer than uniform. |
| Constants | `quality_of_day_enabled` (default **false**), `quality_of_day_sigma` (default 0.05, unused while disabled) |
| Pipeline | Multiplies in `CombatResolver.calc_push_score` **and** `calc_melee_strength_loss` (attacker), after charge_amp, **before** per-tick wobble on push. **Why:** both channels feed the push/cohesion death spiral WO-024 identified. **Not** applied to charge shock, brace tiers, edge multipliers, or slope (R21 maneuver boundary). |
| When | Once at battle start after units are captured (`assign_quality_of_day_if_needed`) |
| Trace | `EVENT,QUALITY_OF_DAY,unit=…` when **enabled**; silent when disabled |
| Determinism | Same seed → same rolls (verified); fast+threaded certs PASS |

### Task 2 — width sweep → **ESCALATED**

33 seeds **1000–1032**. No σ meets all six bands. See escalation + `qod_sweep.md`. Feature remains **disabled** pending TD.

### Task 3 — 0% anomaly

**Mechanism:** slot / RNG-call-order bias (attacker first in `units[]`), **not** marcher-vs-standing. Identical seed→winner maps for march-vs-hold, hold-vs-march, and march-vs-march (`anomaly_diag.log`). With QoD ON, 0% win% enters 50±10 for σ∈{0.02…0.05,0.08,0.10,0.12,0.15} (except 0.06=36.4).

### Task 4 — R21 boundary (probe at σ=0.05, enabled)

| Check | Result |
|-------|--------|
| S3 flank metrics | **HOLD** (0.282 / 76.13 / LEFT 58.68) |
| S34 pin | **HOLD** (flank_persist + no_reface) |
| S18 braced spears stop cav | **HOLD** (`blue_spears`) |
| S19 late brace fails | **HOLD** (`red_cav`) |
| S23–S26 winners | unchanged direction (blue hold / red cav) |
| S36 downhill | **HOLD** (`red_downhill`) |
| S21 flank charge | **HOLD** (`red_cav`) |

No committed width — full boundary re-lock awaits TD σ choice.

### Task 5 — regression

| Gate | Result |
|------|--------|
| Disabled A/B | byte-identical; no QUALITY events; S1 combat 81.6 |
| Certs | fast + threaded **PASS** |
| Determinism | PASS |
| Meta | **72/0 exit 0** |
| GAMEPLAY_TICK | p95 **45.8–46.7** ms (PASS); QoD off = one multiply skipped |

Movement optimization logged as Phase 6/7 debt (WO-024 TD) — not acted on.

---

## Files changed

- `docs/DESIGN_RULINGS_v1.2.md` — R21
- `data/combat_constants.json` — enabled/sigma
- `scripts/rng_service.gd`, `sim/sim_rng.gd`, `sim/sim_rng_bridge.gd` — randn / roll
- `scripts/combat_resolver.gd` — pipeline multiply
- `scripts/sim/sim_battle_core.gd`, `scenario_01.gd` — assign + threaded capture order
- `scripts/unit.gd`, `sim/sim_unit_proxy.gd` — field
- `tests/scenario_wo010_autotest.gd` — S3 flank gates
- `tests/wo025_*.gd`, evidence, reports

---

## Known issues

1. **Task 2:** no σ satisfies R21 curve — escalated (supporting levers).
2. Phase 6/7 debt: movement/substepping dominates GAMEPLAY_TICK.

---

## Attestation

- Branch: `cursor/wo-025-quality-of-day-fd84`
- Full SHA: `01f4788b1ea4df4a6a82ec01dafe2716e348f68a`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-025-quality-of-day-fd84/docs/reports/WO-025_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-025-quality-of-day-fd84/docs/reports/evidence_wo025/suite_stdout.log

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-025-quality-of-day-fd84/docs/reports/WO-025_completion.md
- Escalation: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-025-quality-of-day-fd84/docs/reports/WO-025_escalation.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-024-honest-numbers-fd84/docs/reports/WO-024_completion.md
- Sweep: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-025-quality-of-day-fd84/docs/reports/evidence_wo025/qod_sweep.md
- Suite log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-025-quality-of-day-fd84/docs/reports/evidence_wo025/suite_stdout.log
