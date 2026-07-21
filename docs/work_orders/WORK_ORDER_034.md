WORK ORDER 034 - The Deployment Screen
Project: FORMATIONS - Phase 3 (UI) - Issued by Technical Director
GREEN LIGHT: proceed immediately upon reading. Escalate per governance triggers.
Design authority: DEVELOPMENT_PLAN Phase 3; DESIGN_RULINGS R25 (battle types),
R3 (no auto-envelopment - placement is the player's), R2 (uniform contact),
Combat Core 3.7 (wide-vs-deep). Base: main @ v0.3-sim-complete.
Reference skill: frontend-design (read /mnt/skills/public/frontend-design/
SKILL.md before building UI - it defines this project's styling constraints).

=====================================================================
CONTEXT

The first work order that puts the game in the designer's hands. The simulation
is frozen and complete; this is INTERFACE over it. Deployment is the first of
three stages (deploy -> assign -> battle). Sim-first discipline still holds: the
UI edits the SAME scenario data model the S41/S42 scenario files author by hand
- it must produce a data structure the existing headless executor runs
unchanged. If a UI action cannot be expressed in the existing data model,
ESCALATE - do not extend the sim to fit the UI without a ruling.

=====================================================================
TASK 1 - Deployment data <-> UI binding

- The deployment screen reads a battle_type scenario (R25): map (height field +
  terrain patches), per-side deployment zones (rects), and the player's roster
  (a list of unit profiles to place).
- Every placement action writes to the same scenario data structure the
  headless scenarios use. Prove it: a battle deployed via UI, then saved and run
  headless, must produce an identical starting state to the same deployment
  authored by hand. Assert this (UI-deploy -> serialize -> headless-load ->
  identical initial trace tick).

=====================================================================
TASK 2 - Placement interactions

- Drag a unit from the roster into a deployment zone; it snaps to a valid
  position. Placement outside the zone is rejected (visual feedback).
- Rotate a placed unit to set facing (drag-rotate or a handle).
- Set formation WIDTH: a placed unit can be made wider (shallower) or narrower
  (deeper) within min/max frontage bounds, holding its body count (Strength)
  constant - this is the wide-vs-deep tradeoff (Combat Core 3.7) going live as a
  player choice. Width maps to the sim's frontage/depth; verify the deployed
  footprint matches what the sim will use.
- Reposition and remove placed units freely before lock-in.
- Units may not overlap at deployment (reuse the no-overlap rule); allied
  spacing respected.

=====================================================================
TASK 3 - Deployment readability

- Render the real battlefield the sim will use: height field as shaded relief
  (WO-021/033 rendering), terrain patches (forest/shrub), deployment zones as
  tinted rectangles, enemy deployment shown per R25 visibility (fully visible
  for v1 - no scouting/fog yet; that ruling is deferred).
- Each placed unit shows its type, facing, and current frontage clearly at
  deployment zoom.
- A "deployment summary" readout: units placed / roster remaining.

=====================================================================
TASK 4 - Presets (designer-requested)

- A small set of preset formations that place/arrange the current roster in one
  action: LINE (all units abreast), then at least COLUMN (march order) and
  a REFUSED FLANK (one wing held back). State which presets shipped.
- A preset is just a placement macro writing the same data model - no new sim.
- Presets are a starting point the player then edits; they do not lock.

=====================================================================
TASK 5 - Lock-in and handoff

- A "Ready / Deploy" action validates (all required units placed, in-zone, no
  overlap) and serializes the deployment to the scenario data model.
- For THIS WO, lock-in hands off to the EXISTING headless battle (the assign
  screen is the next WO; for now, deployed units use a default hold/attack
  order so the designer can watch their deployment actually fight).
- The designer must be able to: open a provided battle, deploy by hand, hit
  Ready, and watch their own deployment play out at 60 FPS.

=====================================================================
TASK 6 - Regression + perf

- Pure addition: no sim scenario (S1-S54) may change. Headless suite byte-
  identical. Certs, coherence, determinism all hold.
- The UI must not run sim logic on the render thread (WO-011 seam); deployment
  is static, battle handoff uses the sim thread. Report FPS on the deployment
  screen and on the handed-off battle.
- Suite exit 0, meta reconciled.

=====================================================================
DESIGNER HAND-CONFIRM (this WO's real gate)

The TD cannot see the UI. This WO is accepted only when the DESIGNER confirms,
by hand, on their hardware:
  [ ] Can drag-place, rotate, and re-space units in the zone
  [ ] Can make a unit wider/deeper and see the footprint change
  [ ] Presets place the roster sensibly and remain editable
  [ ] Ready validates and the deployment plays out in a real battle
  [ ] Reads clearly at deployment zoom; 60 FPS
Provide a build/scene the designer runs. Ship a short (5-line) "how to test"
note in the report.

=====================================================================
ACCEPTANCE CRITERIA

[ ] UI deployment writes the existing scenario data model; UI-deploy ==
    hand-authored initial state (asserted)
[ ] Drag/rotate/width/reposition/remove all work; overlap + zone rules enforced
[ ] Battlefield renders real height + patches + zones; enemy per R25
[ ] Presets implemented (LINE + >=2 more) as editable macros
[ ] Ready validates + serializes + hands to a real battle at 60 FPS
[ ] Headless regression byte-identical; suite exit 0; FPS reported
[ ] frontend-design SKILL.md consulted; styling follows it
[ ] Designer-runnable build + 5-line test note; Assumptions: NONE; header
    stamp; atomic commit
[ ] Attestation as final chat content INCLUDING the raw report URL
    (raw.githubusercontent.com, current branch) per the new governance rule

=====================================================================
OUT OF SCOPE

The assignment/order-editor screen (next WO). The battle-view HUD, order
arrows, drop-in (Phase 4). Scouting/fog/enemy-intel (deferred ruling).
Multi-select command issuing (assign WO). Mobile touch tuning (desktop-first;
touch works but is not the gate here). Campaign/roster progression (Phase 5).
