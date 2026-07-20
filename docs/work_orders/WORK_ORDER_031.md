# WORK ORDER 031 — The Order System: Data Model & Headless Execution

**Project:** FORMATIONS — Phase 3  
**Issued by:** Technical Director  
**GREEN LIGHT:** proceed immediately upon reading. Escalate per governance triggers.  
**Design authority:** DEVELOPMENT_PLAN Phase 3; DESIGN_RULINGS R23–R25 (queue cap 3; horn; battle-types-as-data).  
**Base:** main @ v0.2-phase2-sim.

=========================================================
CONTEXT

Phase 3 opens sim-first, as every system has: orders are DATA, executed
headlessly, proven by trace - before one pixel of UI exists. The UI (later WOs)
becomes a thin editor over this model. Gate 3's proof battles (hammer-and-anvil,
Cannae) are built HERE as scripted scenarios; the UI merely lets the designer
author what these files author.

=========================================================
TASK 1 - Order data model (R23)

Per-unit order queue in scenario data: up to 3 steps. Each step:
  { primitive, params, trigger (optional) }
Steps execute in sequence; a step with a trigger WAITS until it fires. The
queue's final completed step leaves the unit in that step's terminal behavior.
Rally contingency remains a separate field (existing ruling), outside the cap.

PRIMITIVES (v1, headless):
  advance_to(point)         - march to a map point, engage per normal gravity
  hold                      - stand; fight if attacked; normal behavior
  absolute_hold             - stand; fight in place; NEVER advances, pursues
                              routers, or drifts from its post; gravity may
                              square facing but not displace it (state the
                              implementation of that constraint)
  attack_nearest            - seek and engage nearest enemy
  attack_target(unit)       - seek and engage a named enemy unit
  feign_retreat(dist)       - Sec 5 feigned withdrawal: turn away, retire dist
                              meters under retreating-skill drain, then turn
                              and re-engage. The ORDER for mechanics that
                              already exist. Deception requirement (first ~2s
                              visually resembles a rout) is a UI-phase note,
                              not sim work.
  flank_move(side, point)   - wide approach path around the given side to a
                              point (waypoint arc; no pathfinding beyond
                              existing movement)
  swing_and_charge(side, target) - flank_move around side, then charge-commit
                              the target on arrival (gait engages per R17).
                              Composite primitive per designer request.

TRIGGERS (v1):
  at_start | after_seconds(T) | enemy_within(X m of self)
  | unit_engages(friendly U) | unit_routs(any/enemy/friendly U)
  | my_cohesion_below(C) | horn_sounded

ARMY ORDER (R24): sound_horn - once per battle per side; all units switch to a
fall-back behavior (orderly withdrawal toward own edge under retreating-skill
drain; braced/absolute_hold units abandon post and comply). Scriptable in
scenarios via after_seconds for testing.

If any primitive/trigger interaction is ambiguous (e.g. feign_retreat
interrupted by horn; absolute_hold vs gravity), ESCALATE - do not choose.

=========================================================
TASK 2 - Battle-type schema (R25)

Scenario definition file gains: battle_type metadata, per-side deployment zones
(rects), per-unit starting posture (normal | concealed - concealment MECHANICS
are a later WO; the schema field lands now), victory conditions (existing rout
conditions; extensible). Pitched = current default. Document the schema in
/docs. No new mechanics in this task - structure only.

=========================================================
TASK 3 - Proof battles (headless; these become Gate 3's sim-side evidence)

S41 - HAMMER AND ANVIL: infantry line ordered absolute_hold as the anvil;
      cavalry ordered swing_and_charge(flank) triggered on unit_engages(anvil).
      Expect: anvil pins, cavalry arcs wide, flank charge lands on the engaged
      enemy's side/rear edge with full directional shock. Report the charge's
      contact edge, shock, and battle outcome across 11 seeds.

S42 - CANNAE: center unit feign_retreat(40) triggered on enemy_within(30);
      two wing units advance_to converging points triggered on the center's
      feign beginning (use unit-state trigger or after_seconds - state which
      and why); cavalry swing_and_charge(rear) triggered on unit_engages(wing).
      Expect: center draws the enemy in, wings envelop (flank edges), cavalry
      seals the rear. Report edge classifications achieved, the enemy's
      cohesion collapse cascade, and outcome across 11 seeds.

S43 - THE HORN: a losing engagement; horn sounded at T. Expect: all units
      disengage per Sec 5 fighting-withdrawal rules and retire; report
      per-unit disengage costs and the army's surviving strength vs a no-horn
      control (which fights to destruction). The horn should SAVE MEN - that
      is its point. Report the margin.

S44 - ABSOLUTE HOLD vs HOLD: routers stream past both; enemy follows. Expect:
      hold unit may pursue/drift per normal rules; absolute_hold unit does not
      move a meter. Report positions over time.

=========================================================
TASK 4 - Order-state observability

Trace gains per-unit: current queue step, active trigger + its live evaluation,
primitive state. The results screen and future UI will need this; the TD needs
it to review S41/S42 without guessing.

=========================================================
TASK 5 - Regression

- S1-S40 byte-identical (order system must be a pure superset: scenarios
  without queues behave exactly as before). Any drift ESCALATES.
- Certs fast+threaded, coherence, SLOT-SWAP, matrix determinism, S8/S8b.
- Suite exit 0, meta reconciled. GAMEPLAY_TICK reported (trigger evaluation is
  per-unit per-tick - it must be cheap; if it measurably regresses the tick,
  report before optimizing anything).

=========================================================
ACCEPTANCE CRITERIA

[ ] Order schema + executor implemented; primitives and triggers per Task 1;
    ambiguities escalated, not resolved silently
[ ] Battle-type schema landed and documented; structure only
[ ] S41-S44 pass across 11 seeds with edge/shock/cascade evidence in traces
[ ] Order-state visible in traces
[ ] Regression byte-identical; suite exit 0; GAMEPLAY_TICK reported
[ ] Assumptions: NONE; header stamp; atomic commit; attestation as final chat
    content

=========================================================
OUT OF SCOPE

ALL UI (deployment/assignment screens, multi-select, preset formations - later
Phase 3 WOs). Concealment mechanics (next WO after this). Full elevation.
Drop-in control and command points (Phase 4). Deployment-reset after horn
(backlogged per R24).
