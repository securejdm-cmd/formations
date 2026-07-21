# WORK ORDER 033 — Full Elevation & Feigned Retreat: Closing the Sim Layer

**Project:** FORMATIONS — Phase 3  
**Issued by:** Technical Director  
**GREEN LIGHT:** proceed immediately upon reading. Escalate per governance triggers.  
**Design authority:** DESIGN_RULINGS R6 (elevation); DAMAGE_AND_CATEGORIES Sec 7
(slope); COMBAT_CORE Sec 5 (feigned retreat — cited as Sec 5 in WO; authority is
Combat Core §5); order schema (WO-031).  
**Base:** main post WO-032 merge.

=========================================================
CONTEXT

This is the LAST headless simulation work order. After it, every combat and
command mechanic exists and is trace-proven; all remaining Phase 3 work is UI
over a frozen sim. Two pieces remain:
  1. Full elevation - WO-021 built ONE test hill to validate Sec 7 modifiers;
     R6 requires a general height field so terrain becomes a deployment
     decision. The modifiers already emerge (WO-021 proved charges need zero
     slope-specific code); this WO generalizes the terrain, it does not
     re-derive the physics.
  2. Feigned retreat as an ORDER - the Sec 5 mechanics exist (disengage,
     retreating-skill drain, turn-and-fight); WO-031 added feign_retreat as a
     primitive. This task hardens and proves it as a first-class battlefield
     tactic, including the deception requirement.

=========================================================
TASK 0 - Carried perf micro-profile (from WO-032)

Before new work: micro-profile the order/trigger per-tick path at 40 units,
GAMEPLAY config, to isolate the ~3-6ms residual (post empty-skip, vs pre-WO-031
26.9ms). Report ms + call counts for: trigger evaluation, queue-step advance
checks, order-state event emission, any per-unit allocation in the order path.
Report only - fix only if trivial and byte-identical. If non-trivial,
escalate with the profile; the UI phase will be planned around it. Do NOT let
new elevation work mask this measurement - measure on a pitched no-order
scenario.

=========================================================
TASK 1 - General height field (R6)

Generalize WO-021's single hill to a full per-scenario height grid:
  - Grid loaded from scenario data (propose 20m cells, per WO-021); bilinear or
    nearest sampling - state which and why.
  - Units sample height + gradient at position each tick (already built for the
    test hill - extend, do not rewrite).
  - Deterministic sampling identical across fast/threaded/realtime.
  - Multiple elevation features per map (ridges, valleys, multiple hills), not
    just one.
  - Flat scenarios (no height data, or all-zero grid) MUST behave byte-
    identical to today - every slope modifier is identity at grade 0.

=========================================================
TASK 2 - Elevation effects (already emergent - VERIFY, do not re-derive)

Confirm the Sec 7 / R6 effects hold across the general field exactly as they did
on the WO-021 test hill:
  - Push +/- with grade; missile range +/- with grade; movement speed +/- with
    grade (charges emerge downhill via real velocity - NO slope-specific charge
    code; grep and state empty).
  - Effects scale with the ALONG-AXIS grade at the unit, not global hill height.
Report calibration on a known grade (e.g. 10% => Sec 7 published values) to
prove the general field matches the test-hill calibration.

=========================================================
TASK 3 - Multi-slope scenarios (11 seeds, evidence)

S49 - RIDGE LINE: defender holds a ridge crest; attacker climbs from one side.
      Expect: defender advantage compounds (uphill attacker slower arrival +
      push penalty + shorter effective range). Report winner, strength_at_rout,
      combat time vs a flat control.

S50 - VALLEY CHARGE: cavalry charges DOWN one valley side into the floor.
      Expect: higher closing velocity => higher Impact than a flat-ground
      charge of equal run-up. Report velocities and Impacts vs flat.

S51 - CROSS-SLOPE FLANK: an engagement on a hillside where one unit's flank
      faces uphill. Expect: the elevation and edge systems compose without
      special-casing - report the edge classification AND the slope modifier
      both applying, no interaction bug.

=========================================================
TASK 4 - Feigned retreat as a first-class order (Sec 5)

Harden feign_retreat(dist) beyond WO-031's primitive:
  - The unit disengages (Sec 5 fighting-withdrawal cost, reduced by Retreating
    Skill), retires `dist` meters, then turns and re-engages / resumes queue.
  - DECEPTION (Sec 5, the design requirement): for the first ~2 seconds a
    feigned retreat must be INDISTINGUISHABLE from a rout to the OPPOSING side.
    Implement so that enemy order-triggers keyed on unit_routs(enemy) do NOT
    fire on a feign (a feint is not a rout), but the visual/state exposed to the
    enemy for those first ~2s matches a rout's. State exactly how the sim
    represents this (a feign flag hidden from the enemy-visible state for the
    window, revealed as "still ordered" after). If this cannot be represented
    without leaking to enemy logic, ESCALATE.
  - Counter-play (Sec 5): low Retreating-Skill units attempting feign bleed real
    cohesion; verify a low-skill feign can itself trigger a genuine rout.

=========================================================
TASK 5 - Feigned retreat scenarios (11 seeds, evidence)

S52 - CLASSIC FEINT: high Retreating-Skill unit feigns, pursuer follows, feint
      unit turns and a friendly flanker (triggered on unit_order_started(feint
      unit, ...) or the pursuer's advance) hits the exposed pursuer. Expect: the
      pursuer is baited out of position and caught. Report the trap springing
      and outcome vs a no-feint control.

S53 - FEINT BACKFIRE: low Retreating-Skill unit ordered to feign. Expect: the
      withdrawal bleeds enough cohesion to risk/trigger a real rout - feigning
      is HARD and punishes the unskilled. Report cohesion trajectory and
      whether it routs.

S54 - DECEPTION WINDOW: verify the enemy cannot mechanically distinguish feign
      from rout for the first ~2s - assert enemy unit_routs triggers do NOT
      fire on the feint, and that the enemy-visible state matches a rout for the
      window. Report the state exposed each tick.

=========================================================
TASK 6 - Regression + sim-layer freeze

- S1-S48 byte-identical (elevation/feign are supersets; flat + non-feign
  scenarios unchanged). Any drift ESCALATES.
- Certs fast+threaded, coherence, SLOT-SWAP, matrix determinism, S8/S8b.
- Suite exit 0, meta reconciled. GAMEPLAY_TICK reported (with Task 0 profile).
- On approval this WO is tagged the SIMULATION-COMPLETE baseline; state the
  proposed tag (v0.3-sim-complete) in the report for TD confirmation.

=========================================================
ACCEPTANCE CRITERIA

[ ] Task 0 order-path micro-profile delivered; residual isolated; fixed-if-
    trivial or escalated
[ ] General height field; multi-feature maps; flat = byte-identical; grade-0
    identity proven
[ ] Elevation effects verified emergent across the general field; charge-slope
    grep empty; 10%-grade calibration matches WO-021
[ ] S49-S51 pass; elevation+edge compose without special-casing
[ ] feign_retreat hardened; deception window implemented without leaking to
    enemy logic (or escalated); low-skill counter-play verified
[ ] S52-S54 pass; deception window asserted tick-by-tick
[ ] Regression byte-identical; suite exit 0; GAMEPLAY_TICK reported
[ ] Proposed v0.3-sim-complete tag stated for TD confirmation
[ ] Assumptions: NONE; header stamp; atomic commit; attestation as final chat
    content

=========================================================
OUT OF SCOPE

ALL UI (deployment/assignment/battle screens, multi-select, presets - the next
WOs). Concealment changes (done). Drop-in control + command points + R26
General's Command (Phase 4). Mobile movement optimization (Phase 6/7 debt).
Passable/impassable terrain, water, roads (backlog - this WO is elevation only).
