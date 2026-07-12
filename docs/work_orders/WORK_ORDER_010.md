# WORK ORDER 010 — Gate 1 Remediation
*Project: FORMATIONS · Phase 1 · Issued by Technical Director*
*GREEN LIGHT: proceed immediately upon reading. Escalate only per governance triggers.*
*Context: Gate 1 designer review found visual-scale and performance failures. Gate 1 remains open until this WO passes designer re-review. Items 5, 6 (flow), and 9 passed.*

## Root cause A — world-meter visuals are invisible at 2 px/m

### Task 1 — Stat card: true screen-space (Gate item 1)
Move the card to a CanvasLayer (screen-space UI). Each frame, project the unit's world position to screen coordinates and pin the card above it. Constant pixel size ALWAYS — zoom changes the world, never the card. Clamp to screen edges when the unit is off-view toward that edge.

### Task 2 — Screen-space minimums for battle effects (Gate items 2, 3)
All combat visuals gain minimum on-screen sizes (constants, in px):
- Grind band: min height 6px on screen regardless of zoom; intensity modulates brightness/alpha, not below-minimum size.
- Crack fissures: min length 8px, min width 2px on screen; count scales with damage as before.
- Front-crack recession + strength thinning: verify the render offset is actually applied (designer reports NO visible effect — audit first, it may be broken not just small); if functional, ensure thinning is visually exaggerated by constant `thinning_visual_gain` (start 1.5×) applied to RENDER depth only.

### Task 3 — Visual gallery scene (permanent designer tool)
`tests/visual_gallery.tscn`: static side-by-side exhibits — units at 100/75/50/25% strength; an engaged pair with forced max grind + fissures; a wavering unit; a routing unit; a rallied HOLD unit; a shock floater firing every 3s. No simulation, just forced states. This becomes the standing hand-confirm tool: every future visual feature gets a gallery exhibit.

### Task 4 — Rout visual ruling (Gate item 4)
Routing units keep CONSTANT frontage. Formlessness = pale + semi-transparent + no border + slight alpha flicker. Remove the ×1.2 width change.

### Task 5 — Shock floaters (Gate item 7)
Cohesion EVENT drains (neighbor shock, future general-slain, panic) spawn a brief floating indicator above the unit: "−15" with a small icon, rises and fades ~1.5s, screen-space sized. Constants for size/duration. Render-only.
Also restage S7: three allied units clearly in line abreast, attacker column crushes the center only; neighbors never engaged — their flinch (floater + card) is the whole show.

## Root cause B — O(n²) pair processing

### Task 6 — Spatial partitioning + perf pass (Gate item 8)
- Implement a uniform spatial grid (cell ≈ 2× max unit dimension); contact/adhesion/separation checks only test units in neighboring cells.
- Profile before/after: report tick-time distribution at 4, 20, 40 units.
- Target: 40-block REALTIME scenario ≥60 FPS on designer desktop with headroom (cloud actuals reported alongside, labeled environmental).
- Determinism warning: iteration order must remain deterministic (sort candidate pairs by unit ID before resolution). Fast certification + full regression suite must stay byte-identical. If ANY trace changes, the partitioning has altered resolution order — ESCALATE, do not rebaseline.

## Task 7 — Victory condition amendment (Gate item 6; log as DESIGN_RULINGS R13)
A routing unit with an UNUSED rally (RALLY trait, rallies_remaining > 0) does NOT count as defeated for the victory check. Victory requires all enemy units removed, destroyed, or routing with no rally remaining. If victory would otherwise be declared while such a unit exists, the battle continues; a successful rally resumes the fight naturally. Update S5's expected flow (no premature victory screen) and append R13 to DESIGN_RULINGS_v1.2 in /docs.

## Acceptance Criteria
- [ ] Stat card: constant px size at min/max zoom, mid-combat — DESIGNER confirms
- [ ] Gallery scene exists; grind band, fissures, thinning, front-crack, rout, HOLD, floater all plainly visible in it — DESIGNER confirms each exhibit
- [ ] Rout width constant — DESIGNER confirms
- [ ] S7 restaged; floaters visible at the cascade moment — DESIGNER confirms
- [ ] No premature victory in S5; R13 appended
- [ ] 40-block: tick-time table (4/20/40 units) before/after partitioning; ≥60 FPS on designer desktop
- [ ] FULL regression byte-identical (S1–S8, all invariants, fast certification) — partitioning changes NOTHING
- [ ] Report with branch-URL Links footer; merge on TD approval + designer confirms

## Out of Scope
New mechanics, constants tuning, Phase 2 anything.
