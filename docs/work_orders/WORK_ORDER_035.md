WORK ORDER 035 - UI Handoff Sim Unification + Deploy Reposition
Project: FORMATIONS - Phase 3 (UI) - Issued by Technical Director
GREEN LIGHT: proceed immediately upon reading. Escalate per governance triggers.
Design authority: WO-034 completion; WO-019 sub-stepping; WO-011 sim thread;
WO-008/010 overlap + adhesion; Combat Core contact. Base: WO-034 branch / main
post-merge.

=========================================================
CONTEXT

TD DIAGNOSIS CONFIRMED. Designer re-ran S40 and observed NO pass-through
(clean front-to-front contact with a shared boundary); certified no-overlap
resolution is intact on the scenario path. Merging/tunneling is UI-HANDOFF
ONLY. Cavalry/selected blocks also render "bent at the joint" in both S40 and
UI — separate cosmetic vs geometry question.

=========================================================
TASK 1 - Sim-path unification (root cause)

Diagnose ScenarioFromData / deployment→battle handoff. Report explicitly
whether the UI-launched battle runs the IDENTICAL certified tick as
scenario_01..54: sub-stepping (WO-019), adhesion, no-overlap resolution,
contact coherence, sim-thread routing. Report the diff line by line. If the
handoff forks or degrades the tick in ANY way, THAT is the defect — unify so
the UI battle IS the certified sim.

=========================================================
TASK 2 - Prove it (permanent UI-LAUNCH smoke)

Deploy a battle via the data path the UI produces, run headless, assert
no-overlap AND contact-coherence across the full battle. Include a
FULL-ENCIRCLEMENT case (one unit engaged on 3+ edges by multiple attackers).

=========================================================
TASK 3 - Bent body (cosmetic vs geometry)

Determine if cavalry/selected "bent at the joint" is render-only body-flex
with true footprint rigid, or real geometry. If render-only, state it (fix
visual if trivial); if footprint bends, defect. Report which.

=========================================================
TASK 4 - WO-034 reposition (carried)

Click-to-select + drag-to-move (or unset) placed units before lock-in — still
required, still missing. Ship it.

=========================================================
ACCEPTANCE

[ ] Line-by-line handoff vs certified tick report; forks unified
[ ] UI-launch smoke + full-encirclement: no-overlap + coherence PASS
[ ] Bent body: render-only vs geometry stated (visual fixed if trivial)
[ ] Deploy reposition works
[ ] Designer build; suite exit 0; Assumptions NONE; raw report URL

=========================================================
OUT OF SCOPE

Assignment screen. Battle HUD polish beyond integrity. Mobile touch tuning.
