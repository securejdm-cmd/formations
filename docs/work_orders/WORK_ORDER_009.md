# WORK ORDER 009 — Routs, Rally & the Phase 1 Finale
*Project: FORMATIONS · Phase 1 · Issued by Technical Director*
*GREEN LIGHT: proceed immediately upon reading. Escalate only per governance triggers.*
*Design authority: COMBAT_CORE_v1.1 §4 + DESIGN_RULINGS_v1.2 (R8, R9). Baseline: current main.*

## Objective
Complete Phase 1's remaining mechanics: the RALLY trait, pursuit, rout shock cascades, the blob-proof test, and the 40-block performance check. After this WO, Gate 1 review begins.

## Task 1 — RALLY trait
- Trait field activates per COMBAT_CORE §4: on rout, unit flees (existing behavior); if **t_rally (8s)** elapse with no enemy within **pursuit_radius_m (NEW constant: 25)**, unit rallies — stops, reforms at current Strength, Cohesion = rally_cohesion_reset (50), enters **HOLD state** (stands ground, faces nearest threat, fights if attacked, takes NO initiative, does NOT resume prior orders). Max rallies_per_battle (1).
- New unit profile `/data/units/test_infantry_rally.json`: identical to test_infantry + Traits ["RALLY"].
- Rally timer, state transitions, and HOLD behavior logged in trace (new state values: routing → rallying → holding).

## Task 2 — Pursuit
- Per R8: fleeing units have no collision; pursuit contact is PROXIMITY-based — an enemy within **pursuit_contact_m (NEW constant: 3)** of a routing unit inflicts damage at pursuit_damage_multiplier (×4, existing constant) using its Close Damage; no push contest, no drains to the pursuer.
- Pursued RALLY units: rally timer resets whenever an enemy is inside pursuit_radius_m.
- Phase 1 scope: pursuit only happens if an enemy unit happens to be near/ordered onto the flee path (scripted in scenarios). Pursue-as-an-order is Phase 3.

## Task 3 — Neighbor-rout shock
- When a unit begins routing, all friendly units within neighbor_shock_radius_m (30) take a one-time cohesion drain of neighbor_rout_shock (15). Applies per routing event; log as event row in trace.

## Task 4 — Scenarios (Combat Core §6, renumbered; fast mode; standard seeds)
- **S5 — Rally vs standard:** standard unit and RALLY unit each routed by identical pressure, no pursuit. Expect: standard exits map; RALLY reforms after 8s at Cohesion 50 in HOLD, ignoring stale orders.
- **S6 — Rally denied:** RALLY unit routed WITH a scripted pursuer on the flee path. Expect: timer never completes; unit destroyed or driven off map. Report pursuit damage ticks.
- **S7 — Cascade:** three allied units in line; center unit forced to rout (scripted overwhelming attack). Expect: both neighbors show the −15 shock at the rout moment in traces; report whether shock alone tips either into wavering.
- **S8 — Blob test:** three attackers stacked against one defender's FRONT edge. Expect: total damage ≈ what contact frontage allows, NOT 3× a single attacker; report single-attacker vs triple-attacker damage ratio.

## Task 5 — Performance check (Gate 1 criterion, desktop-adjusted)
- Scenario: 40 blocks (20v20 grid of test_infantry), all engaged within ~30s, REALTIME mode on desktop. Report min/avg FPS across the battle and tick-processing time distribution. (Mobile target deferred with the export; desktop must hold 60fps with headroom.)

## Acceptance Criteria
- [ ] S5–S8 pass their expectations; full trace excerpts for rally timeline, pursuit ticks, shock events
- [ ] Contact coherence invariant, determinism, fast certification, no-overlap (non-routing), compass: ALL still pass
- [ ] S1/S2/S3/S4 regression: byte-identical (none of this WO touches engaged combat) — any drift is a defect, ESCALATE
- [ ] New constants in combat_constants.json only; all state transitions in traces
- [ ] 40-block realtime: ≥60fps desktop, numbers reported
- [ ] Report committed to /docs/reports/ with Links footer; INDEX.md updated; PR merged on approval

## Out of Scope
Feigned retreat (Phase 3 — it's an order), rally contingency UI, pursue-as-order, ranged anything, magnetism beyond existing adhesion.

## Note to workshop
HOLD state is deliberately minimal: stand, face nearest threat, fight back. If "face nearest threat" requires rotation behavior that doesn't exist yet, ESCALATE with options rather than building rotation — a facing snap may suffice for Phase 1.
