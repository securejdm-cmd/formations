# ESCALATION REPORT — WO-020b Task 1 — Date 2026-07-15

**Work order:** WO-020b Giving Magnetism Teeth — Task 1 (fighting withdrawal ratio)  
**Branch:** `cursor/wo-020b-magnetism-teeth-fd84`  
**Design authority:** DAMAGE_AND_CATEGORIES_v1.1 §5  

---

## What was attempted

Fighting withdrawal is implemented: for the full `3.0×(1−Agility/150)` timer the unit stays partnered, does not translate, cannot strike, and takes free hits each tick (`calc_melee` as push-loser × `disengage_damage_mult`) plus `ordered_retreat_drain_per_sec`.

`disengage_damage_mult` was swept. Pre-authorized selection required all three:

1. spears strength lost ≥ 6.0  
2. skirmisher strength lost ≤ 6.0  
3. ratio spears/skirmisher ∈ [1.6, 1.8] (must track duration 2.40/1.40 ≈ 1.71)

## Sweep table (`disengage_damage_mult`)

| mult | sk_lost | sp_lost | ratio | ≥6 spears | ≤6 skirm | ratio ok |
|------|---------|---------|-------|-----------|----------|----------|
| 1.0 | 2.43 | 3.12 | 1.28 | no | yes | no |
| 1.5 | 3.59 | 4.66 | 1.30 | no | yes | no |
| **2.0** | **4.74** | **6.17** | **1.30** | **yes** | **yes** | **no** |
| 2.5 | 5.89 | 7.68 | 1.30 | yes | yes | no |
| 3.0 | 7.05 | 9.19 | 1.30 | yes | **no** | no |
| 3.5 | 8.20 | 10.69 | 1.30 | yes | no | no |
| 4.0 | 9.35 | 12.20 | 1.30 | yes | no | no |
| 5.0 | 11.66 | 15.22 | 1.30 | yes | no | no |

## Why criterion 3 is unreachable

Both defenders take free hits from the **same** `test_infantry` attacker. Armor differs:

- skirmisher: Armor 4 Leather  
- spears: Armor 10 Mail  

So post-armor DPS_skirm > DPS_spears. Exposure totals ≈ DPS×duration therefore:

`ratio ≈ (DPS_sp/DPS_sk)×(2.40/1.40) ≈ 0.76×1.71 ≈ **1.30**`

A shared `disengage_damage_mult` scales both equally and **cannot** change the ratio. Widening the Sec 5 duration formula is forbidden without a TD ruling.

## Provisional constant

Committed **`disengage_damage_mult = 2.0`** (WO propose value): satisfies criteria 1–2, duration lock demonstrated. Criterion 3 escalated.

## Ask of the TD

Choose one:

1. **Accept ratio≈1.30** as the honest armored-differential outcome (Agility still owns duration; armor owns DPS). Keep mult=2.0.  
2. **Armor-blind free hits** during withdrawal (turning your back → raw attacker damage × mult, ignore defender armor) so ratio tracks duration.  
3. **Separate duration formula** (ruled out unless TD overrides Sec 5).  
4. Other.

Evidence: `docs/reports/evidence_wo020b/constant_sweep.log`

## Assumptions made
NONE — escalation instead of inventing a ratio fix.

## Links

- This escalation: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020b-magnetism-teeth-fd84/docs/reports/WO-020b_escalation.md
- Parent WO-020: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020-full-magnetism-fd84/docs/reports/WO-020_completion.md
- Sweep log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020b-magnetism-teeth-fd84/docs/reports/evidence_wo020b/constant_sweep.log
