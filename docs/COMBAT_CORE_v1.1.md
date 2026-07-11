# FORMATIONS — Combat Core Design Document
## v1.1 — Phase 0 Deliverable (Gate 0 design freeze)
*Changelog from v1.0: rally-into-hold ruling (§4), rally contingency note for Phase 3 (§4), placeholder melee damage (§3.5, new), edge-based contact model replacing angular arcs (§3.6, new), multi-unit engagement & corner pressure (§3.7, new), map scale / pass-through / wavering / general rulings (§8 resolved, moved to §9).*

---

## 0. Design Pillars
1. **Battles are won by breaking will, not annihilation.** Historical armies routed at 10–30% casualties. Cohesion, not Strength, is the true victory meter.
2. **Every internal number must be visible on the block.** Strength = block thickness. Cohesion = edge steadiness. Push = the line physically moving. A player should read a battle like a K&G video, no health bars required.
3. **Deterministic & tunable.** All constants live in one data table (§7). Same seed + same orders = same battle.
4. **The rectangle IS the unit.** Contact, flanking, and pressure are computed from the block's real edges. Geometry is tactics.

---

## 1. Strength (the slow currency)
- Range **100 → 0**. The unit's effective fighting bodies.
- Drops only from combat damage (placeholder melee exchange in §3.5 for Phase 1; full damage stats arrive Phase 2).
- **Everything scales by Strength%**: damage output, Push Score, physical block size on screen.
- No regeneration during battle.
- Units should essentially never reach 0 in a fair fight — they rout first. Strength 0 = destroyed outright.

**Visual:** the block thins/shrinks proportionally.

---

## 2. Cohesion (the fast currency — morale)
- Range **100 → 0**. Order, confidence, will to fight.

### Drains (values in §7)
| Cause | Effect |
|---|---|
| Taking casualties | drain per Strength% lost |
| Losing the push (shoved back) | drain per meter lost |
| Contact on a side edge | ×2 multiplier on combat drains from that contact |
| Contact on the rear edge | ×3 multiplier on combat drains from that contact |
| Corner contact | weighted multiplier between the two touched edges (§3.6) |
| Friendly unit within radius R routs | one-time shock drain (cascades) |
| Army general slain | one-time large drain, army-wide |
| Ordered (feigned) retreat | small drain/sec, reduced by Retreating Skill |

### Recovery
- Slow recovery per second while not engaged and not moving fast.
- **Wavering is escapable:** recovery continues below the waver threshold once disengaged (ruling, was §8 Q2). Pulling shaken units out to rest is an intended tactic.
- Recovery improves with unit quality (later stat) and proximity to the general's flag.

### Thresholds
- **Wavering (< 30):** 80% combat effectiveness; visual = block edges flicker/fray.
- **Rout (< 10):** unit breaks → §4.

---

## 3. The Push
Melee contact is a continuous shoving contest, evaluated every tick (10/sec), **per contact segment** (§3.6):

> **Push Score = PushingPower × Strength% × (0.5 + Cohesion/200) × ContactFrontage% × ContextMods + wobble**

- **PushingPower** — unit stat.
- **Strength%** — thinned units shove weaker.
- **(0.5 + Cohesion/200)** — cohesion degrades push but never zeroes it.
- **ContactFrontage%** — share of the attacker's front edge actually in contact (§3.7). You can't push with soldiers who aren't touching the enemy.
- **ContextMods** — Phase 2+ (charge, brace, slope). Phase 1: 1.0.
- **wobble** — seeded ±5% so mirror matches don't freeze.

**Resolution per tick:** higher total score shifts the contact line toward the loser proportional to the gap (capped). Loser takes ground-lost cohesion drain.

**The intended feedback loop (this is the game):** fresher unit wins the shove → loser bleeds cohesion → wavering pushes 20% worse → line moves faster → rout → neighbors take shock → cascade. A collapsing flank should be visible ~5–10 seconds before it breaks.

### 3.5 Placeholder Melee Damage (Phase 1 only)
Each tick, each engaged unit loses Strength proportional to the *opponent's* Push Score:
> **StrengthLoss/tick = K_dmg × OpponentPushScore**, with the current **push loser taking ×1.25**.
This is deliberately crude. Phase 2 replaces it with real damage stats (close-range damage, armor, anti-armor). It exists so morale, thinning, and routs have fuel.

### 3.6 Edge-Based Contact Model (RULING — replaces angular arcs)
Each block has four oriented edges from its facing: **Front, Left, Right, Rear**.
- Every enemy contact is classified by which of the *defender's* edges it touches.
- Multipliers: Front ×1, Left/Right ×2, Rear ×3 — applied to cohesion drains caused by that contact.
- **Corner contact:** a contact overlapping two edges applies a length-weighted blend of the two multipliers. Example: a charge landing half on Front, half on Left ≈ ×1.5. Corners are genuine soft spots.
- Consequence (intended): angling into an enemy's corner gives a partial-flank bonus without full maneuvering — skirmish-level tactics fall out of pure geometry.

### 3.7 Multi-Unit Engagement (RULING)
- Multiple attackers may engage one defender; each resolves its own contact segment on whichever edge(s) it touches.
- **Frontage cap:** an attacker's push and damage scale with the fraction of its front edge in contact (ContactFrontage%). Stacked blobs gain nothing from bodies that can't reach the line.
- Therefore encirclement kills primarily through the ×2/×3 **morale** multipliers and multi-edge ground loss — terror, not stacked physics. Historically authentic; mechanically blob-proof.
- **Wide vs deep tradeoff (emergent, note for Phase 3 deployment):** wider formation = more frontage engaged = more damage/push delivered, but longer vulnerable side edges. Deeper = compact and corner-resistant. Formation shape becomes a real pre-battle decision.

---

## 4. Routing (the hybrid rule)
When Cohesion < rout threshold:

**Standard units:** turn pale, lose formation shape, flee toward own map edge at 130% speed, ignore all orders, cannot fight; contacted while fleeing = rapid strength loss (pursuit multiplier). Reaching map edge or Strength 0 = **permanently removed**.

**Units with the RALLY trait:** same flight, BUT if the unit spends **T_rally consecutive seconds** (default 8) with no enemy inside pursuit radius, it rallies: stops, reforms at current Strength, **Cohesion resets to 50**. Max **once per battle**. Caught while fleeing = dies like anyone else.

### Post-rally behavior (RULING)
A rallied unit enters a defensive **HOLD state**: it stands its ground, faces the nearest threat, fights if attacked — but takes **no initiative** and does NOT resume its pre-rout order queue (the plan it belonged to is stale) and does NOT free-attack (suicide at half strength). It is now a reserve awaiting fresh command.
- Rationale: the ~8s rally ≈ 20–30 historical minutes of reforming; the battle has moved on. A rallied unit is a *decision*, not a free unit.
- Phase 4 hook: re-tasking a rallied unit via drop-in costs Command Points.

### Rally contingency (Phase 3 design option — deferred)
In the assignment UI, RALLY-trait units may accept ONE pre-scripted contingency: "if rallied → hold" (default) / "→ fall back to camp" / "→ move to general." A standing regimental order, not a full queue. Do not build before Phase 3.

**Pursuit dilemma (intended consequence):** the winner must choose — chase routers to guarantee kills and deny rallies (losing those pursuers from the main line), or hold formation and risk the enemy reforming.

---

## 5. Feigned Retreat ≠ Rout
- Feigned retreat is an **order** executed with intact cohesion: withdraw facing-away at normal speed, only the small ordered-retreat drain, heavily reduced by **Retreating Skill**.
- On its trigger (distance / timer / command) the unit turns and fights instantly. No rally timer, no per-battle limit — it never broke.
- **Deception requirement:** for the first ~2 seconds, feigned retreat and real rout must look similar to the opponent. Divergence after (routs: faster, pale, formless).
- Counter-play: low Retreating Skill units attempting feints bleed real cohesion. Orderly withdrawal is hard; feign-spam self-punishes.

---

## 6. Phase 1 Test Scenarios — Expected Outcomes
| # | Setup | Must observe |
|---|---|---|
| 1 | Identical blocks, head-on | Long grind; wobble decides; winner ends <50% strength, low cohesion |
| 2 | PushingPower 60 vs 40 | Steady ground gain; weaker side routs with ~60–75% strength remaining — morale, not HP, decides |
| 3 | Identical + third block into one side edge | Flanked unit routs in ~half the time of scenario 1 |
| 4 | Corner charge: attacker lands half-Front/half-Left | Cohesion drain measurably between pure-front and pure-flank rates |
| 5 | Standard rout vs RALLY rout, no pursuit | Standard exits map; RALLY reforms after 8s at Cohesion 50, enters HOLD, ignores old orders |
| 6 | RALLY rout WITH pursuit | No rally; destroyed or driven off |
| 7 | Neighbor-rout shock | Adjacent unit's cohesion visibly drops when neighbor routs |
| 8 | Blob test: 3 attackers stacked on one Front edge | Total damage ≈ what contact frontage allows, NOT 3× a single attacker |

Each scenario = runnable Godot scene with pass/fail assertions where possible + per-second stat trace logs for review.

---

## 7. Tunable Constants (v1.1 starting values — Phase 1 tunes these)
| Constant | Start | Notes |
|---|---|---|
| Tick rate | 10/sec | |
| Wobble | ±5% | seeded |
| Waver threshold / effect | 30 / 80% | |
| Rout threshold | 10 | |
| K_dmg (placeholder melee) | tune in Phase 1 | target: scenario 1 lasts 60–90s |
| Push-loser damage factor | ×1.25 | |
| Drain per 1% strength lost | 1.5 | |
| Drain per meter lost | 0.8 | |
| Side / Rear edge multipliers | ×2 / ×3 | corner = length-weighted blend |
| Neighbor-rout shock | −15 (radius 30m) | |
| General slain | −25 army-wide | |
| Idle recovery | +2/sec | continues while wavering if disengaged |
| Rout flee speed | 130% | |
| Pursuit damage | ×4 | |
| T_rally / reset / per battle | 8s / 50 / 1 | |
| Ordered-retreat drain | 1/sec × (1 − RetreatSkill/100) | |

---

## 8. World & Scale Rulings (resolved)
- **Battlefield:** ~600m × 400m playable, sized for up to **~20 units per side** (40 blocks total — matches the Phase 1 performance gate). Default infantry block frontage ~40m.
- **Pass-through: NO.** Friendly blocks pathfind around each other. (Future unique ability may allow it — e.g., skirmishers filtering through lines. Deferred to content phases.)
- **General:** abstract flag position (affects cohesion recovery radius and the general-slain event), NOT a physical unit. General abilities = deferred backlog item.

## 9. Deferred by Ruling
- General as physical unit + general abilities
- Pass-through as a unique unit ability
- Rally contingency UI (Phase 3)
- Real damage/armor stats (Phase 2 design doc)
