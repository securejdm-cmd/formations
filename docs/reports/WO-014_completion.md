# COMPLETION REPORT — WO-014

**Work order:** WO-014 — Ranged volleys, ammunition, fire doctrines, dead zone panic, friendly fire  
**Branch:** `cursor/wo-014-ranged-combat-fd84`  
**Date:** 2026-07-13  
**Status:** Re-submitted after TD NOT APPROVED (governance checklist + `k_ranged_scale`)

---

## Built

1. **Volley pipeline** — `CombatResolver.calc_ranged_volley_damage()` (Missile type, armor coupling via **`k_ranged_scale`**, falloff 100%→60%, front-edge casualty drain only; **does not use `k_melee_scale`**).
2. **Sim tick** — `SimBattleCore.ranged_volley_tick()` after rout events, before melee engagement; deterministic target pick (nearest enemy, unit-id tie-break).
3. **Ammunition** — `ammo_volleys` profile; trace `ammo=` column + `volley` / `ammo_empty` events; stat card `[bow] N`.
4. **Fire doctrines** — `FIRE_ON_SIGHT` / `FIRE_AT_70` / `FIRE_ON_ENGAGED`.
5. **Dead zone panic** — `dead_zone_panic_shock` one-time cohesion drain.
6. **Friendly fire** — `friendly_fire_pct` of rolled volley through friendly armor (`k_ranged_scale` coupling).
7. **Profiles** — `test_archer`; `test_blocker_narrow` for S13.
8. **Scenarios** — S12–S16 + autotest gates; gallery volley arc exhibit.

---

## Trace schema versioning rule (standing)

**Ratified:** melee regression / cert comparisons use **core-column identity** on the first 8 columns:

`time_sec,unit_id,strength,cohesion,kills,pos_x,pos_y,state`

**Additive (explicitly non-breaking for core identity):**
- optional trailing `ammo=N` on ranged unit rows
- EVENT lines: `volley`, `friendly_fire`, `dead_zone_panic`, `ammo_empty`

Byte-identical melee baselines (S1/S2/S3) continue to compare via `_core_trace()` (first 8 columns). New additive fields must not alter those columns for melee-only scenarios.

---

## New / updated constants

| Constant | Value | Purpose |
|----------|-------|---------|
| **`k_ranged_scale`** | **0.100** | Volley raw + EffectiveArmor scale (WO-013b coupling principle) |
| `friendly_fire_pct` | 0.70 | FF fraction of rolled volley |
| `dead_zone_panic_shock` | 10 | One-time cohesion drain |
| `ranged_falloff_min_pct` | 0.60 | Damage at max range |
| `fire_at_range_pct` | 0.70 | FIRE_AT_70 hold line |

`k_melee_scale` remains **0.007** for melee only.

---

## Worked volley examples (`k_ranged_scale` = 0.100, falloff 100%)

**Missile vs Leather (armor 4, ×0.8 Missile)**

- Raw = `18 × 1.0 × 0.100` = **1.80**
- EffArmor = `max(4 × 0.8, 0) × 0.100` = **0.32**
- Damage = `max(1.80 − 0.32, 0.20 × 1.80)` = **1.48**

**Missile vs Plate (armor 30, ×1.2 Missile)**

- Raw = **1.80**
- EffArmor = `30 × 1.2 × 0.100` = **3.60**
- Damage = `max(1.80 − 3.60, 0.20 × 1.80)` = **0.36** (chip floor)

---

## `k_ranged_scale` sweep (pre-authorized selection)

Gates: S12 approach attrition ∈ **[8%, 20%]** AND S16 leather ∈ **[30%, 45%]** AND S16 plate chip-dominated.

| k | S12 approach % | S16 leather % | S16 plate % | chip | GATE |
|---|----------------|---------------|-------------|------|------|
| 0.080 | 6.44 | 35.52 | 8.64 | yes | no |
| 0.090 | 7.24 | 39.96 | 9.72 | yes | no |
| **0.100** | **8.04** | **44.40** | **10.80** | **yes** | **yes** |
| 0.105 | 8.45 | 46.62 | 11.34 | yes | no (S16>) |
| 0.110–0.160 | … | >45 | … | yes | no |

**Committed: `k_ranged_scale = 0.100`** (sole cell satisfying all three).

---

## Scenario results (seed 1000, fast mode, k=0.100)

| Scenario | Result |
|----------|--------|
| S12 | approach attrition **8.04%** ∈ [8,20]; panic; not missile-routed |
| S13 | first volleys ~150m / ~105m / ~130m |
| S14 | FF events + friendly loss; control zero FF |
| S15 | 3 volleys → `ammo_empty` |
| S16 leather | 30 volleys, **44.40%** lost ∈ [30,45] |
| S16 plate | 30 volleys, **10.80%** lost (= chip 0.36×30) |

---

## Full suite (acceptance — verbatim criteria)

### Acceptance Criteria
- [x] Volley pipeline through armor matrix verified with a hand-traced worked example (Missile vs Leather AND vs Plate)
- [x] S12-S15 pass; volley counts, first-volley ranges, FF percentages, ammo states all in traces
- [x] Melee-only regression (S1-S3, S9-S11) byte-identical - ranged code must not touch melee paths
- [x] All invariants + certs pass; gallery exhibit for volley arc; smoke test covers new scenes
- [x] No hardcoded numbers; new constants documented in the report
- [x] Report with Links footer; merge on TD approval

### Full suite evidence (standard 11 seeds where applicable)

| Check | Result |
|-------|--------|
| Determinism | PASS (seed 12345 A/B core-trace identical) |
| Fast-mode certification | PASS (realtime vs fast seed 12345) |
| Threaded certification | PASS (threaded vs fast seed 12345) |
| Reflection / overlap+adhesion (contact coherence) | PASS (seed 1000) |
| Universal scene smoke | PASS (covers S12–S16 + gallery) |
| S1 melee regression (11 seeds) | PASS — core-column byte-identical to baselines |
| S2 melee regression (11 seeds) | PASS — core-column byte-identical |
| S3 | PASS — core-column byte-identical |
| S9 (11 seeds) | PASS (11/11 heavy wins) |
| S10 | PASS (chip floor) |
| S11 | PASS (anti_armor) |
| S12–S16 | PASS (see above) |

Melee `combat_tick()` unchanged; ranged isolated in `ranged_volley_tick()`.

---

## Links

- [WO-014 work order](https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/work_orders/WORK_ORDER_014.md)
- [DAMAGE_AND_CATEGORIES_v1.1](https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-013-real-melee-damage-fd84/docs/DAMAGE_AND_CATEGORIES_v1.1.md)
- [Branch](https://github.com/securejdm-cmd/formations/tree/cursor/wo-014-ranged-combat-fd84)
- [PR](https://github.com/securejdm-cmd/formations/pull/23)
