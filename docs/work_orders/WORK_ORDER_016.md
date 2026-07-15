# WORK ORDER 016 - Mounted Units: Momentum Charges, Mass & Brace
*Project: FORMATIONS - Phase 2 - Issued by Technical Director*
*GREEN LIGHT: proceed immediately upon reading. Escalate only per governance triggers.*
*Design authority: DESIGN_RULINGS_v1.2 R4 (momentum charge), R5 (mass/inertia, NO knockback), DAMAGE_AND_CATEGORIES_v1.1 Sec 7 (charge/brace). Baseline: main post-WO-015 (confirm suite exit 0 in report).*

## Objective
Cavalry that wins by impact and loses by lingering - via measured physics, not a charge stat. Includes mass, acceleration/inertia, the charge impact model, and the brace counter. PARTHIAN (fire-while-moving) is deferred to a later ranged-cavalry WO.

## Task 1 - Mass & inertia (R5)
- `mass_by_profile` data table: Low / Medium / High / Massive -> mass values (propose 0.6 / 1.0 / 1.6 / 3.0; tune later).
- Acceleration & deceleration rates scale inversely with mass: accel = base_accel / mass (constants base_accel, base_decel). Units build to Speed over time; heavy units are sluggish to start AND stop.
- Turn rate also scales inversely with mass (heavier = wider turns), layered on Agility.
- **HARD LINE (R5): no momentum transfer, no knockback, no free-body physics.** Mass affects ONLY: charge impact (Task 2), and accel/decel/turn feel. Engaged lines still move solely via the push contest. If any implementation path would push a unit via collision physics, ESCALATE.

## Task 2 - Momentum charge (R4)
- At the moment melee contact begins, compute **Impact = mass x closing_speed x Strength% x charge_impact_scale** (new constant), where closing_speed is the attacker's actual current speed along the contact normal (real, measured - not a stat).
- Impact converts to: (a) one-time **cohesion shock** to the defender (impact x charge_cohesion_coeff), and (b) a **damage/push amplification** window: close_damage and push xcharge_amp for charge_amp_decay_s (~3s), decaying linearly to 1.0.
- Below a minimum closing speed (constant charge_min_speed), no charge bonus - a unit shuffling into contact gets nothing. This makes run-up emergent (acceleration means short run-ups can't reach charge_min_speed).
- Charge applies to ANY unit meeting the speed threshold (infantry get modest charges from a run-up); it is not cavalry-flagged. Cavalry excel via high Speed + Mass, emergently.
- New mounted test profile `test_cavalry`: propose close_damage 14, armor 8 Leather (combined horse+rider), speed 40, agility 70, pushing_power 40, profile High, melee type Slash, ammo 0. Modest melee stats - it must WIN by charge, FADE in grind.

## Task 3 - Brace counter (D&C Sec 7)
- A stationary unit with melee_damage_type Pierce that has held facing toward an incoming charger for >= brace_time_s (1.5) enters BRACED state.
- Braced defender vs a charge: NEGATE the charge amplification and cohesion shock; reflect brace_reflect_pct of the computed Impact back as damage/cohesion to the charger.
- Braced state visualized (e.g., a facing-edge indicator); shown in gallery.
- New profile `test_spears`: close_damage 9, armor 10 Mail, pushing_power 55, speed 14, agility 30, profile Medium, melee type **Pierce**. The anti-charge anchor.

## Task 4 - Scenarios (fast mode, standard seeds; evidence logs required)
- **S17 - Charge vs unbraced:** test_cavalry charges test_infantry (long run-up). Expect: large cohesion shock at impact, amplified opening damage, infantry routs fast at HIGH strength (shock, not attrition). Report impact value, shock, combat time vs a no-run-up control (cavalry starting adjacent = no charge).
- **S18 - Charge vs braced spears:** test_cavalry charges test_spears that have held facing >=1.5s. Expect: charge negated, reflected damage to cavalry, cavalry then loses the grind (modest melee). Report cavalry strength_at_rout.
- **S19 - Brace timing:** cavalry charges spears that turned to face only 0.5s before impact (not yet braced). Expect: brace FAILS, charge lands - proving the timing window matters.
- **S20 - Run-up / acceleration:** identical cavalry charge from 20m vs 120m. Expect: 20m never reaches charge_min_speed (no bonus), 120m reaches full impact. Report closing speeds and impacts.

## Acceptance Criteria
- [ ] Impact formula hand-traced worked example (one charge, all terms) in report
- [ ] S17-S20 pass expectations; impacts, shocks, closing speeds, brace outcomes in evidence logs
- [ ] Melee + ranged regression (S1-S16) byte-identical / genuinely green - new physics must not alter existing scenarios (charge_min_speed ensures standing contacts are unaffected; VERIFY head-on marchers don't accidentally trip charge). If S1/S2 combat drifts, ESCALATE.
- [ ] NO knockback/momentum-transfer anywhere; engaged movement still push-only
- [ ] All invariants + certs + the 45-count meta-assertion pass; full suite exit 0; evidence dir attached
- [ ] Gallery: braced indicator + a charge-impact flash exhibit
- [ ] Atomic code+report commit; attest with header stamp

## Out of Scope
PARTHIAN / fire-while-moving, mounted archers, magnetism auto-rotation (next WO), terrain/elevation, pursue-as-order.

## Note to workshop
The regression risk is the charge accidentally triggering on normal head-on marches (they close at Speed too). charge_min_speed and the contact-normal speed check must ensure two infantry lines marching to contact at walking pace do NOT register charges - S1/S2 MUST stay byte-identical. If they can't without special-casing, ESCALATE with the numbers before hacking.
