# ESCALATION REPORT — WO-013

**Work order:** WO-013 — Real Melee Damage: Stats, Armor & the Chip Floor  
**Branch:** `cursor/wo-013-real-melee-damage-fd84`  
**Date:** 2026-07-13  
**Status:** BLOCKED — awaiting design authority

---

## Blocker

Task 1 requires `/data/armor_matrix.json` to contain the **4×3 armor-class vs melee-damage-type multiplier table from DAMAGE_AND_CATEGORIES_v1.1 §3, exactly as documented**.

`DAMAGE_AND_CATEGORIES_v1.1` is cited as design authority in WO-013 and referenced throughout `DESIGN_RULINGS_v1.2.md`, but **the document is not present** in the repository, uploads folder, or any committed path. Without the §3 matrix values, the workshop cannot create `armor_matrix.json` without inventing balance numbers — a governance violation (Prime Directive: no silent decisions).

All other WO-013 requirements are specified and ready to implement once the matrix is available:

- Melee damage formula (Task 2) — sequencing is explicit in WO-013 (chip floor, then push-loser ×1.25)
- Profile schema additions (`melee_damage_type`, `agility`, full nine-stat line)
- `k_melee_scale` / `k_armor_scale` sweep (Task 3) with pre-authorized selection rule
- Scenarios S9/S10/S11 (Task 4)
- K_dmg retirement

---

## Options

**A) Commit design authority, then implement**  
TD/designer adds `docs/DAMAGE_AND_CATEGORIES_v1.1.md` (at minimum §3 matrix) to the repo. Workshop copies §3 into `data/armor_matrix.json` and proceeds with full WO-013 implementation + sweep + scenarios.

- Tradeoff: one extra relay step; zero invented balance.

**B) Inline matrix in green light**  
TD pastes the 12 multiplier values (4 classes × 3 damage types) directly in the next message. Workshop writes `armor_matrix.json` from those values and proceeds.

- Tradeoff: matrix lives only in chat until committed; workshop can also commit the values into `armor_matrix.json` with a comment citing TD inline ruling.

---

## Recommendation

**Option A** — commit `DAMAGE_AND_CATEGORIES_v1.1.md` to `/docs` so Phase 2+ work orders share the same design authority already cited in rulings and WO-013. Single source of truth; no drift.

---

## Clarification already resolved (no escalation needed)

Formula application order per WO-013 text:

1. `RawDamage_tick = close_damage × Strength% × ContactFrontage% × k_melee_scale`
2. `EffectiveArmor_tick = max(armor × ClassVsType(defender_class, attacker_type) − attacker.anti_armor, 0) × k_armor_scale`
3. `Damage_tick = max(RawDamage_tick − EffectiveArmor_tick, chip_floor_pct × RawDamage_tick)` where `chip_floor_pct = 0.20`
4. If push loser: `Damage_tick × push_loser_damage_factor (1.25)`

Per contact segment; attacker supplies `close_damage`, `melee_damage_type`, `anti_armor`; defender supplies `armor`, `armor_class`.

---

## AWAITING GREEN LIGHT — no implementation code written.

Work order committed to `docs/work_orders/WORK_ORDER_013.md` on branch `cursor/wo-013-real-melee-damage-fd84`.

---

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-013-real-melee-damage-fd84/docs/reports/WO-013_escalation.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/PHASE_1_CLOSURE.md
- Work order: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-013-real-melee-damage-fd84/docs/work_orders/WORK_ORDER_013.md
