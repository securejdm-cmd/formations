# WORK ORDER 013 — Real Melee Damage: Stats, Armor & the Chip Floor
*Project: FORMATIONS · Phase 2 · Issued by Technical Director*
*GREEN LIGHT: proceed immediately upon reading. Escalate only per governance triggers.*
*Design authority: DAMAGE_AND_CATEGORIES_v1.1 §§1–4 + DESIGN_RULINGS_v1.2. This WO retires the K_dmg placeholder (Combat Core §3.5).*

## Objective
Melee damage flows from unit stats through the armor system. Ranged, cavalry, and magnetism are LATER work orders — this is melee-only.

## Task 1 — Data schema
- Unit profiles gain the full nine-stat line + tags (any already present stay): close_damage, ranged_damage, armor, anti_armor, speed, agility, pushing_power, retreating_skill, range; armor_class (Plate/Mail/Leather/None); melee_damage_type (Slash/Pierce); traits; profile.
- `/data/armor_matrix.json`: the 4×3 class-vs-type multiplier table from D&C §3, exactly as documented.
- Test profiles updated: test_infantry gets close_damage 10, armor 10, armor_class Mail, melee_damage_type Slash, anti_armor 0 (other stats unchanged). Variants (push60/push40/rally) inherit the same.

## Task 2 — Melee damage formula (per tick, per contact segment)
> RawDamage_tick = close_damage × Strength% × ContactFrontage% × k_melee_scale
> EffectiveArmor_tick = max(armor × ClassVsType(defender_class, attacker_type) − attacker.anti_armor, 0) × k_armor_scale
> Damage_tick = max(RawDamage_tick − EffectiveArmor_tick, chip_floor_pct × RawDamage_tick)
- chip_floor_pct = 0.20 (constant). Push-loser ×1.25 factor RETAINED, applied after the floor.
- k_melee_scale and k_armor_scale are the two new tuning constants; K_dmg is DELETED.
- Cohesion casualty-drain pipeline unchanged (drains from strength lost, per-channel edge multipliers per R7).
- If any formula-order ambiguity arises (rounding, floor-vs-loser-multiplier sequencing, multi-segment armor application), ESCALATE — do not choose.

## Task 3 — Tuning sweep with pre-authorized commit (WO-007b pattern)
Sweep k_melee_scale × k_armor_scale (grid of your choosing, ≥ 9 cells, justify the grid in the report) over the standard 11 seeds:
- SELECTION RULE (pre-authorized): commit the cell where S1 mean combat lands nearest 80s within [60, 90] AND S2 strength_at_rout lands within [60, 75] AND mirror-profile fights (identical units) end with winner strength < 55%. If no cell satisfies all three, ESCALATE with the matrix.
- After commit: full re-baseline tables for S1/S2/S3 (winners, durations, rout metrics). S3's flank ratio band will be RE-DERIVED by TD from the new numbers — report actuals, enforce nothing.

## Task 4 — New acceptance scenarios (fast mode, standard seeds)
- **S9 — Armor differential:** armor 20/Mail vs armor 5/Leather, identical otherwise (Slash). Expect: high-armor side wins ≥ 10/11 seeds; report casualty ratio.
- **S10 — Chip floor proof:** armor 50/Plate defender vs standard attacker. Expect: attacker's damage clamps at the 20% floor (verify in trace), battle still ENDS (no immortal units), defender wins.
- **S11 — Anti-armor:** attacker with anti_armor 15 vs armor 20/Plate, control run with anti_armor 0. Expect: anti-armor run shows materially higher damage-through and shorter combat; report both.

## Acceptance Criteria
- [ ] Formula implemented per Task 2; worked per-tick example in report (numbers traced by hand)
- [ ] Sweep matrix + committed constants + re-baseline tables delivered
- [ ] S9/S10/S11 pass; chip-floor clamp visible in S10 trace
- [ ] All invariants pass (determinism, symmetry, coherence, smoke, fast + threaded certs) on new baselines
- [ ] No hardcoded numbers; armor matrix lives in its data file
- [ ] Report with Links footer; merge on TD approval

## Out of Scope
Ranged combat, ammo, doctrines, cavalry/charges, magnetism, terrain, Pierce-specific mechanics beyond the matrix lookup (brace is a later WO).
