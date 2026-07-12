# FORMATIONS — Design Rulings Addendum v1.2
*Layered on COMBAT_CORE_v1.1 and DAMAGE_AND_CATEGORIES_v1.1. Where this addendum conflicts with those documents, this addendum wins. Each entry notes its origin and build status.*

---

## R1. Allied Collision (ruled during WO-008)
Allied units NEVER overlap (non-routing). Implemented: per-tick minimal-translation separation — unengaged yields to engaged; equal states split the correction; deterministic order by unit ID. **STATUS: BUILT (WO-008).**

## R2. Uniform Contact Weight (designer ruling)
Push/damage contribution is uniform per meter of contact — no center-vs-corner weighting within an edge. Readability principle: "more touching = more fighting." Corners keep their identity exclusively through the morale-multiplier blend. **STATUS: BUILT (inherent in ContactFrontage%).**

## R3. No Auto-Envelopment (designer ruling)
Uncommitted frontage (a wide unit overlapping a narrow enemy) does NOT automatically fold around the target. Envelopment is a player order and a player skill. UI may later hint at overlap opportunities. **STATUS: DESIGN LAW — enforce when movement orders arrive (Phase 3).**

## R4. Momentum Charge Model (designer + TD; SUPERSEDES Damage&Cat §7 "Charge")
No charge stat. Impact is measured physics at contact:
> **Impact = Mass × ClosingSpeed × Strength%**
- Converts to: one-time cohesion shock to defender + brief damage/push amplification decaying over ~3s into normal melee.
- **Acceleration is real:** units build to top speed over seconds (rate scales inversely with Mass). Run-up requirement, downhill bonus, and attrition-scaled impact all emerge — no special rules.
- Brace (stationary Pierce, facing, ≥1.5s) negates the impact multiplier and reflects damage — unchanged from §7.
**STATUS: DESIGNED — build with Phase 2 category work orders.**

## R5. Mass & Inertia via Profile (designer + TD)
Profile tag doubles as weight class: Low/Medium/High/Massive → Mass values (data table). Mass drives charge Impact (R4) and accel/decel/turn rates.
**HARD LINE: no momentum transfer, no knockback, no free-body physics.** Engaged lines move ONLY via the push contest. Mass shapes impact moments and movement feel — never post-contact physics. **STATUS: DESIGNED — Phase 2.**

## R6. Elevation (designer request; TD phasing)
Coarse height grid under the battlefield, rendered as shaded relief (K&G style). Effects mostly emerge: downhill charges arrive faster (R4), uphill attackers arrive slower, slope push/range modifiers per Damage&Cat §7. Phase 2 keeps the single test hill; full elevation ships with Phase 3 deployment (contesting ground becomes a player decision). **STATUS: DESIGNED — Phase 3.**

## R7. Per-Channel Edge Multipliers (designer ruling; SUPERSEDES Combat Core §2 "×2/×3 on all combat drains")
Edge multipliers split by drain channel, four constants:
| Channel | Side | Rear |
|---|---|---|
| Ground-loss (shift) drain | ×2.0 | ×3.0 |
| Casualty drain | ×1.5 | ×2.0 |
Corners blend per channel by contact length. Rationale: being displaced from a flank is maximal terror; flank casualties panic men more than frontal ones but not compoundingly. Front = ×1 both channels. **STATUS: BUILT (WO-008).**

## R8. Rout Collision & Visual (TD ruling during WO-008)
ROUTING units drop collision entirely (formless fugitives streaming past formations); rendered pale, formless, semi-transparent. Pursuit interaction uses proximity, not collision. No-overlap assertions exempt routing units, explicitly. **STATUS: BUILT.**

## R9. Contact Adhesion — Phase 1 Magnetism Core (TD ruling; derived from Damage&Cat §5)
Engaged pairs adhere continuously: each tick, pairs separated ≤ engage_snap_max_m (1.0) close the gap; single source of truth for "contact" is the edge classifier via shared contact_epsilon_m; permanent invariant — no pair may persist linked-but-unresolvable. This is the minimal core of §5 engagement gravity; full magnetism (auto-close from 4m, auto-rotate, disengage costs, rotation-under-contact drain) remains Phase 2. **STATUS: BUILT (core), Phase 2 (full).**

## R10. Battle End, Results & Kill Accounting (designer rulings, WO-004)
Victory declared victory_delay_s (2.5) after last enemy unit begins routing; flee is a skippable epilogue; results table ranks units by soldiers defeated. men_per_full_unit = 1000 (display-only conversion; per-unit data later). **STATUS: BUILT.**

## R11. Backlog additions (logged, NOT scheduled)
- **SHOCK/TERROR trait:** direct cohesion burst on first contact/close approach (Carrhae unveiling, elephants). Uses existing event-drain channel.
- **"Flank covered" shield icon:** UI presentation of flank security (designer concept) — Phase 3+ readability feature, not a mechanic.
- **"Casualties = ground yielded"** as real mechanic: DEFERRED (WO-005 ruling) — revisit only with proven gameplay value.
- Pass-through as unique ability; re-hiding after reveal; ammo resupply; general as physical unit + abilities. (Carried from v1.1.)

## R12. Infrastructure law (TD, standing)
- Fast-mode harness: all automated testing runs decoupled from wall-clock; fast certification is a permanent assertion.
- Merge discipline: TD approval ⇒ PR merged to main before next WO.
- Reports of record: committed .md in /docs/reports/ with raw-link footer + INDEX.md.
- Permanent assertion suite: determinism, reflection symmetry, no-overlap (non-routing), fast certification, compass (32 cases), contact coherence invariant.
