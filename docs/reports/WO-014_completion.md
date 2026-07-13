# COMPLETION REPORT — WO-014

**Work order:** WO-014 — Ranged volleys, ammunition, fire doctrines, dead zone panic, friendly fire  
**Branch:** `cursor/wo-014-ranged-combat-fd84`  
**Date:** 2026-07-13

---

## Built

1. **Volley pipeline** — `CombatResolver.calc_ranged_volley_damage()` (Missile type, WO-013b armor coupling, falloff 100%→60%, front-edge casualty drain only).
2. **Sim tick** — `SimBattleCore.ranged_volley_tick()` after rout events, before melee engagement; deterministic target pick (nearest enemy, unit-id tie-break).
3. **Ammunition** — `ammo_volleys` profile stat; trace `ammo=` column + `volley` / `ammo_empty` events; stat card `[bow] N`.
4. **Fire doctrines** — `fire_doctrine`: `FIRE_ON_SIGHT` / `FIRE_AT_70` / `FIRE_ON_ENGAGED` (profile field).
5. **Dead zone panic** — `dead_zone_panic_shock` one-time cohesion drain when enemy enters `min_range_m` while archer not in melee.
6. **Friendly fire** — `friendly_fire_pct` of rolled volley damage through friendly armor; `friendly_fire` trace events.
7. **Profile** — `test_archer` foot bow; `test_blocker_narrow` for S13 engaged setup.
8. **Scenarios** — S12–S15 + autotest gates; gallery volley arc exhibit.
9. **Visualization** — `VolleyArc` render-only arc + target impact flicker.

---

## New constants (`combat_constants.json`)

| Constant | Value | Purpose |
|----------|-------|---------|
| `friendly_fire_pct` | 0.70 | FF damage fraction of rolled volley |
| `dead_zone_panic_shock` | 10 | One-time cohesion drain |
| `ranged_falloff_min_pct` | 0.60 | Damage at max range |
| `fire_at_range_pct` | 0.70 | FIRE_AT_70 hold line |

Uses existing `k_melee_scale`, `chip_floor_pct`, `min_range_m` / `reload_s` / `ammo_volleys` on profiles.

---

## Worked volley examples (k=0.007, 100% falloff)

**Missile vs Leather (armor 4, ×0.8 Missile)**

- Raw = `18 × 1.0 × 0.007` = **0.126**
- EffArmor = `max(4 × 0.8, 0) × 0.007` = **0.0224**
- Damage = `max(0.126 − 0.0224, 0.0252)` = **0.1036**

**Missile vs Plate (armor 30, ×1.2 Missile)**

- Raw = **0.126**
- EffArmor = `30 × 1.2 × 0.007` = **0.252**
- Damage = `max(0.126 − 0.252, 0.0252)` = **0.0252** (chip floor)

---

## Scenario results (seed 1000, fast mode)

| Scenario | Result |
|----------|--------|
| S12 | 18 volleys, panic, ~1.84 inf lost, no missile rout |
| S13 sight | first volley **149.9m** |
| S13 at70 | first volley **104.9m** |
| S13 engaged | first volley **130.0m** (after blocker engagement) |
| S14 | FF events + friendly strength loss |
| S14 control | zero FF |
| S15 | 3 volleys, `ammo_empty`, melee fallback |

---

## Regression

- S1 trace core columns **byte-identical** (verified seed 1000).
- Melee `combat_tick()` untouched; ranged isolated in `ranged_volley_tick()`.
- `skip_auto_engage` partner check added (blocker + S6 pursuer only).

---

## Acceptance Criteria (WO-014)

- [x] Volley pipeline through armor matrix verified with hand-traced examples (Missile vs Leather AND vs Plate)
- [x] S12-S15 pass; volley counts, first-volley ranges, FF percentages, ammo states in traces
- [x] Melee-only regression (S1 core trace byte-identical seed 1000; `combat_tick()` untouched)
- [x] Scene smoke PASS (21 scenes); gallery volley arc exhibit
- [x] New constants in `combat_constants.json`; documented in report
- [x] Report with Links footer; merge on TD approval

---

## Links

- [WO-014 work order](https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/work_orders/WORK_ORDER_014.md)
- [DAMAGE_AND_CATEGORIES_v1.1](https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-013-real-melee-damage-fd84/docs/DAMAGE_AND_CATEGORIES_v1.1.md)
- [Branch](https://github.com/securejdm-cmd/formations/tree/cursor/wo-014-ranged-combat-fd84)
