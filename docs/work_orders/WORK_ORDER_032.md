# WORK ORDER 032 — Concealment & Ambush

**Project:** FORMATIONS — Phase 3  
**Issued by:** Technical Director  
**GREEN LIGHT:** proceed immediately upon reading. Escalate per governance triggers.  
**Design authority:** DAMAGE_AND_CATEGORIES_v1.1 Sec 10 (FINAL, incl. 10.1 Profile
multipliers); DESIGN_RULINGS R25 (battle types); order schema posture field
(WO-031).  
**Base:** main post WO-031 merge.

=========================================================
CONTEXT

The ambush is the payoff mechanic of the assignment phase, designed since the
flight and waiting for the order system. Sec 10 is FINAL - this WO implements
it as written. No fog of war: the field is fully visible EXCEPT units concealed
in terrain. This is Lake Trasimene / Teutoburg, and it is the first battle type
beyond pitched (R25).

=========================================================
TASK 1 - Concealment terrain

- Terrain patches in scenario data: FOREST (detect 10m) and SHRUB (detect 20m),
  rectangles for v1. Rendered simply (darker green fill; K&G-flat).
- Movement penalties per Sec 10: forest slows cavalry (-40% speed) and drains
  cohesion from over-wide formations inside (threshold + rate as constants).
- Forest missile penalty: -25% ranged damage firing OUT of and INTO forest
  (symmetric, per ruling). Shrub: no missile penalty.

=========================================================
TASK 2 - Concealment state

- posture: concealed (schema field exists) is valid only if the unit's FULL
  footprint is inside a patch (fit rule) at battle start.
- A concealed unit is invisible to the enemy SIDE: excluded from enemy unit
  auto-behaviors - fire doctrines, targeting, engagement gravity, charge
  commitment, attack_nearest - until detected. (Enemy ORDER TRIGGERS like
  enemy_within must also not see it; state the implementation.)
- Detection: enemy within effective radius = base (by terrain) x Profile
  multiplier (Sec 10.1: Low 0.75 / Medium 1.0 / High 1.5 / Massive = cannot
  conceal) x2 while the concealed unit is MOVING.
- Reveal triggers: detection radius breach; the unit fires or attacks; the unit
  leaves the patch. REVEALED IS PERMANENT for the battle (ruling).
- Reveal is an EVENT in traces; on reveal the unit re-enters all enemy
  auto-behaviors immediately.

=========================================================
TASK 3 - The ambush order

- Concealed units may hold queues per R23. The canonical pattern must work:
  step 1: hold (concealed), trigger enemy_within(X)
  step 2: swing_and_charge / attack_target
- Charging FROM concealment: the defender's Tier 1 instinctive brace requires
  brace_reaction_s of visible front-arc approach (R16). A charger that is
  CONCEALED until inside the reaction window must be treated as UNSEEN for
  brace purposes - the defender gets Tier 3 (caught unaware) unless the
  charger was revealed early enough. State the implementation: the brace
  clock starts at REVEAL, not at approach. This is the shock-and-awe payoff
  the designer specified; if the interaction is ambiguous anywhere, ESCALATE.

=========================================================
TASK 4 - Scenarios (11 seeds, evidence logs)

S45 - TEUTOBURG (battle_type: ambush): victim column marches along a road
      corridor past a forest; ambusher units concealed with hold-until-
      enemy_within -> charge queues. Expect: no reveal until trigger range or
      the charge itself; defenders get NO Tier 1 (brace clock from reveal);
      flank/rear edges; catastrophic cohesion collapse. Report reveal timing,
      brace tier applied, edges, and outcome vs an identical NON-concealed
      control (ambush must materially outperform a visible flank attack -
      report the margin; this number IS the value of stealth).

S46 - DETECTION MATRIX: stationary vs moving, Low/Medium/High profiles, forest
      vs shrub. Assert effective detection distances = base x profile x
      movement on every combination. Massive: assert cannot conceal (fit rule
      irrelevant - posture rejected).

S47 - FIT RULE + REVEAL PERMANENCE: a unit half-out of the patch cannot start
      concealed; a revealed unit re-entering forest stays revealed. Assert
      both.

S48 - FOREST PENALTIES: cavalry speed -40% inside; over-wide formation drains;
      archer volleys across the forest boundary at -25% both directions.
      Assert each against flat-ground controls.

=========================================================
TASK 5 - Regression + the carried perf question

- S1-S44 byte-identical (pitched scenarios have no patches; concealment must
  be a pure superset). Any drift ESCALATES.
- Certs, coherence, SLOT-SWAP, matrix determinism, S8/S8b. Suite exit 0.
- GAMEPLAY_TICK: report 5-run variance, and answer the WO-031 carry: why did
  perf_40 (no queues) rise 26.887 -> 31.834 if the executor is no-op when
  empty? If the empty path has real per-tick cost, report it; fix only if
  trivial (e.g. skip executor entirely when zero queues exist army-wide).

=========================================================
ACCEPTANCE CRITERIA

[ ] Sec 10 implemented as written: radii, profile multipliers, movement x2,
    reveal triggers + permanence, fit rule, forest penalties, missile symmetry
[ ] Concealed units provably invisible to ALL enemy auto-behaviors AND enemy
    order triggers until reveal
[ ] Brace clock starts at reveal; S45 shows Tier 3 on ambush contact
[ ] S45 margin vs visible control reported (the value of stealth, quantified)
[ ] S46-S48 assert every rule combination
[ ] Regression byte-identical; suite exit 0; perf question answered with
    variance
[ ] Assumptions: NONE; header stamp; atomic commit; attestation as final chat
    content

=========================================================
OUT OF SCOPE

All UI (patches in the deployment screen arrive with the UI WOs). Re-hiding
after reveal (backlog). Line-of-sight/fog of war (never - design says no).
Full elevation (next WO). Scouting/counter-detection units (backlog).
