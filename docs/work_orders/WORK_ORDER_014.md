# WORK ORDER 014 - Ranged Combat: Volleys, Ammunition & Fire Doctrines
*Project: FORMATIONS - Phase 2 - Issued by Technical Director*
*GREEN LIGHT: proceed immediately upon reading. Escalate only per governance triggers.*
*Design authority: DAMAGE_AND_CATEGORIES_v1.1 Sec 6 (+6.1-6.4) and Sec 2-4 (Missile damage type through the armor matrix). FOOT ranged only - mounted/PARTHIAN arrives with the cavalry WO.*

## Task 1 - Volley system
- Missile units fire discrete VOLLEYS at a target unit every reload interval (per-profile stat `reload_s`), only while: standing still, target within [min_range_m, range], target permitted by doctrine (Task 3), ammo > 0.
- Volley damage: RawVolley = ranged_damage x Strength% x falloff, resolved through the WO-013b armor pipeline with attack type MISSILE (armor x ClassVsType(Missile) coupling, anti_armor, chip floor). No push contribution; casualty cohesion drain applies normally (front-edge channel - missile fire does NOT use flank multipliers in v1; note this in code).
- Falloff: 100% inside half range, linear to 60% at max range.
- Targeting: nearest valid enemy under doctrine. Deterministic tie-break by unit ID.
- **Visualization:** arrow-cloud arc from shooter to target (simple animated arc of dots/streaks, render-only), impact flicker on the target. Gallery exhibit added.

## Task 2 - Ammunition
- Profile stat `ammo_volleys`. Decrements per volley; at 0 the unit fights on as melee (its usually-poor close stats). No resupply.
- Tier reference (D&C Sec 6) for future profiles; THIS WO creates one: `test_archer` - foot bow: ranged_damage 18, range 150m, min_range 15m, reload_s 5, ammo 30, close_damage 6, armor 4 Leather, pushing_power 25, speed 18, agility 60, profile Low, damage types: Missile (ranged) / Slash (melee).
- Ammo count in stat card (e.g., "[bow] 12") for ranged units and in traces.

## Task 3 - Fire doctrines (D&C Sec 6.2)
Profile/order field `fire_doctrine`: FIRE_ON_SIGHT (default) / FIRE_AT_70 (hold until target inside 70% of max range) / FIRE_ON_ENGAGED (only targets engaged with a friendly). Doctrine is data now; the Phase 3 assignment UI will expose it later.

## Task 4 - Dead zone & panic (D&C Sec 6.3)
- No volleys inside min_range_m (15).
- First enemy penetration of the dead zone while the archer is not already in melee: one-time panic shock Cohesion 10 (constant `dead_zone_panic_shock`), shock floater fires, then normal melee rules take over.

## Task 5 - Friendly fire (D&C Sec 6.1)
- If the volley's target unit is ENGAGED in melee, each friendly unit in contact with that target takes 70% of the rolled volley damage (constant `friendly_fire_pct` = 0.70), through the friendly's own armor. Friendly-fire strength loss drains cohesion normally. Log FF events in trace.

## Task 6 - Scenarios (fast mode, standard seeds)
- **S12 - Attrition march:** test_archer at 200m vs approaching test_infantry. Expect: multiple volleys land during approach (report count + damage), infantry arrives hurt but NOT routed by missiles alone, archer panics at dead zone, melee resolves quickly against archer's weak close stats.
- **S13 - Doctrine timing:** three archers, one approaching enemy, one doctrine each. Expect three distinct first-volley ranges: ~150m / ~105m / only after the enemy engages a friendly blocker. Report first-volley distances.
- **S14 - Friendly fire:** archer volleys into an engaged scrum (friendly melee unit + enemy). Expect: friendly takes ~70% strikes through its armor; report friendly strength lost to FF. Control run with FIRE_ON_ENGAGED targeting the enemy's UNENGAGED reinforcement shows zero FF.
- **S15 - Empty quiver:** archer with ammo 3 vs slow approacher. Expect: 3 volleys, then silent stand, then melee fallback; trace shows ammo 0 state.

## Acceptance Criteria
- [ ] Volley pipeline through armor matrix verified with a hand-traced worked example (Missile vs Leather AND vs Plate)
- [ ] S12-S15 pass; volley counts, first-volley ranges, FF percentages, ammo states all in traces
- [ ] Melee-only regression (S1-S3, S9-S11) byte-identical - ranged code must not touch melee paths
- [ ] All invariants + certs pass; gallery exhibit for volley arc; smoke test covers new scenes
- [ ] No hardcoded numbers; new constants documented in the report
- [ ] Report with Links footer; merge on TD approval

## Out of Scope
Mounted anything, PARTHIAN, charges, magnetism/rotation, terrain/elevation, concealment, per-target priority orders, resupply.

## Note to workshop
Volley resolution against a unit engaged in melee raises geometry questions (which edge, whose frontage). Ruling in advance: volleys ignore edge geometry entirely in v1 - flat hit on the target unit, frontage 100%. If implementation surfaces a case this ruling doesn't cover, ESCALATE.
