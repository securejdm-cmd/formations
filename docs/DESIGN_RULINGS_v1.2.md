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
Coarse height grid under the battlefield, rendered as shaded relief (K&G style). Effects mostly emerge: downhill charges arrive faster (R4), uphill attackers arrive slower, slope push/range modifiers per Damage&Cat §7. Phase 2 ships a single test hill (WO-021: 20m cells, constant 10% ramp) to validate modifiers; full elevation with deployment is Phase 3 (contesting ground becomes a player decision). **STATUS: PHASE 2 TEST HILL BUILT — WO-021; full elevation Phase 3.**

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
Engaged pairs adhere continuously: each tick, pairs separated ≤ engage_snap_max_m (1.0) close the gap; single source of truth for "contact" is the edge classifier via shared contact_epsilon_m; permanent invariant — no pair may persist linked-but-unresolvable. This is the minimal core of §5 engagement gravity; full magnetism (auto-close from 4m, auto-rotate, disengage costs, rotation-under-contact drain) remains Phase 2. **STATUS: BUILT (core + full WO-020).**

## R19. Pinning (TD; WO-020)
Engagement gravity auto-rotates a unit to face contact **only if that unit is NOT already engaged**. A unit already in contact is **PINNED**: it does not auto-rotate toward new contacts, no matter which edge they land on. Refacing while engaged requires an explicit disengage (expensive). This preserves hammer-and-anvil: flank multipliers persist because a pinned line cannot swivel to face the flanker. **STATUS: DESIGN LAW — effective WO-020.**

## R20. Disengage Exposure Differs by Armor Emergently (TD; WO-020b)
Disengage exposure is governed by Agility (duration) and Armor (mitigation) independently; the resulting strength-loss ratio between differently-armored profiles is emergent and is not a tuning target. Keep `disengage_damage_mult = 2.0`. Criterion 3 (WO-020b Task 1) was withdrawn — it assumed armor-blind free hits; a shared free-hit multiplier cannot move an armor-driven ratio by construction, and Option 2 (armor-blind free hits) would break armor at the moment it matters most. Ratio ≈1.30 on S30 is the honest armored-differential outcome (TD Option 1). **STATUS: DESIGN LAW — WO-020b.**

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

## R13. Victory vs unused rally (designer + TD; WO-010)
A routing unit with the **RALLY** trait and `rallies_remaining > 0` does **not** count as defeated for the victory check. Victory requires every enemy unit to be removed, destroyed, or routing with no rally remaining. If victory would otherwise be declared while such a unit exists, the battle continues; a successful rally resumes the fight naturally. **STATUS: BUILT (WO-010).**

## R14. Mirror-winner strength gate superseded (TD; WO-013b)
The legacy expectation that mirror-profile fights (identical units) end with winner strength **< 50–55%** is **SUPERSEDED**. That gate mathematically contradicts the **60–75% strength_at_rout** design band, which is design law. All tuning selection rules drop the mirror-winner gate; sweeps commit on S1 mean combat ∈ [60, 90] nearest 80s and S2 strength_at_rout ∈ [60, 75] only. **STATUS: DESIGN LAW — effective WO-013b.**

## R15. Charge shock vs fresh infantry (TD; WO-016 / WO-016c / WO-017 / WO-018)
A momentum charge (R4) against **FRESH** (100% cohesion) medium infantry on a **FRONTAL + Tier 3 (unaware)** contact MUST drop defender cohesion **into but not through** the wavering band: landing cohesion **∈ [15, 30]** (staggered / wavering), **NOT** routed. Instant frontal charge-delete of full-strength lines is forbidden.

**With R16:** frontal + **Tier 1 instinctive brace** must leave the line **steady (land ≥ 45)**. The [15, 30] band is the **caught-unaware** frontal outcome, not the braced one.

**Directional edge weight (WO-016c):** charge cohesion shock = `base_shock × edge_casualty_mult × brace_tier_mult`. Closing speed for Impact is the attacker's **real** velocity along the contact inward normal (**sim m/s**, R17 — one meter). Spectrum vs fresh: **front+T1 → holds**; **front+T3 → wavering**; **flank/rear → rout**.

**Speed / gait (WO-018 R17 supersedes WO-016b SI scale):** tactical movement keeps `speed_stat_meters_per_10s=1.0`. Charge Impact is measured from the unit's real velocity after charge-gait acceleration — **no `charge_speed_si_scale`**. **STATUS: DESIGN LAW — effective WO-018.**

## R16. Three-tier brace (TD; WO-017)
Charge shock is modulated by the defender's readiness at the moment of contact:

1. **Tier 1 — Instinctive brace (automatic, any unit).** All must hold at impact: (a) charger was in the defender's front arc with closing (sim m/s) ≥ own `Speed × charge_min_speed_pct` (R18) for ≥ `brace_reaction_s`; (b) defender is not already engaged with another enemy; (c) defender own speed ≤ `brace_max_own_speed_pct` of its top tactical speed; (d) contact edge is **front**. Effect: shock × `instinctive_brace_mult`. Never applies to side/rear.

2. **Tier 2 — Set to receive (Pierce).** Stationary Pierce facing ≥ `brace_time_s` negates shock and reflects. Supersedes Tier 1 when both qualify.

3. **Tier 3 — Caught unaware.** Full directional shock.

Steady infantry that sees a charge holds; busy, moving, surprised, or outflanked infantry is shattered. **STATUS: DESIGN LAW — effective WO-017.**

## R17. Charge gait (TD; WO-018)
A unit's Speed stat governs **tactical** movement (march / trot). A unit may also have a **charge gait**: when committed to a charge it physically accelerates toward `Speed × charge_gait_mult`, and momentum Impact is measured from that **real** velocity. No conversion constants — what the player sees is what the defender feels.

- `charge_gait_mult` is a per-profile stat (default 1.0 = no gait).
- Cavalry gait 3.375 → target gallop 13.5 sim-m/s; infantry_charge gait 2.0 → ~3.0 sim-m/s run.
- Commitment: move/attack toward an enemy within `charge_commit_range_m` in front arc and gait > 1. Acceleration uses R5 inertia (`base_accel / mass`) — run-up distance is emergent.
- On losing the target / contact / order change: decelerate back to tactical Speed.

**STATUS: DESIGN LAW — effective WO-018.**

## R18. Reachable gait + relative charge threshold (TD; WO-019)
1. **`base_accel`** is tuned so a cavalry unit reaches its gait ceiling within a realistic run-up: standstill distance-to-gait ∈ **[100m, 160m]**. Committed value must also produce a real S29 velocity/Impact curve (short run-ups cannot gallop).
2. **`charge_min_speed_pct`** (propose 1.25): a charge registers only when closing speed exceeds the attacker's **own** tactical `Speed × charge_min_speed_pct`. Absolute `charge_min_speed` is deleted. Units with `charge_gait_mult = 1.0` are structurally incapable of charging.

High-speed movement integration sub-steps so per-substep displacement stays **< `engage_snap_max_m`**. **STATUS: DESIGN LAW — effective WO-019.**

## R21. Quality of the Day — Persistent Like-vs-Like Variance (designer + TD; WO-025)

Like-vs-like fights must be **genuine contests**. Per-tick zero-mean wobble cannot produce that: it averages out over hundreds of ticks while any persistent push/cohesion bias compounds into certainty (WO-024 sensitivity: 2% push edge → 100% win; ±15% wobble Δ = 0.0).

**Mechanism:** at battle start each unit rolls a **persistent** `quality_of_day` multiplier from the battle-seeded RNG (same stream — no new RNG). The multiplier applies for the whole battle to that unit's **effective combat and push output** (melee strength loss and push score). It does **not** dilute maneuver advantages: charge shock, brace tiers, flank/rear edge multipliers, pinning, and slope direction remain decisive. **No good day saves a unit from a rear charge.**

**Boundary (inviolable):** variance may blur paper stats only. Maneuver outcomes (flank, brace timing, charge spectrum, pinning, slope direction, rear charge) must remain decisive under the committed width.

**Supporting levers (logged, not this WO):** slow (low-frequency) wobble; rout-threshold variance. Adding them is a TD decision if the committed width cannot meet the R21 curve alone.

**STATUS: DESIGN LAW — effective WO-025.**
