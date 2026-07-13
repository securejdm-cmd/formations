# FORMATIONS — Damage, Armor & Unit Categories
## Phase 2 Design Doc — v1.1 (DESIGN FREEZE)
*Changelog from v1.0: §10 Concealment finalized — reveal permanence, movement multiplier, symmetric forest missile penalty (Napoleonic-proofing), and the new **Profile** tag (§1, §10.1). All open questions resolved. This doc and Combat Core v1.1 together constitute the complete pre-code design.*

---

## 1. The Stat Line (final)
Nine stats: **Close Damage · Ranged Damage · Armor · Anti-Armor · Speed · Agility · Pushing Power · Retreating Skill · Range**

Plus four tags:
- **Traits** (RALLY, PARTHIAN, …)
- **Armor Class** (Plate / Mail / Leather / None)
- **Damage Type** on each attack (Slash / Pierce / Missile)
- **Profile** (Low / Medium / High / Massive) — physical size & visibility class (§10.1)

## 2. Damage Types
Slash · Pierce · Missile. Data-extensible for future eras.

## 3. Armor Classes
| | vs Slash | vs Pierce | vs Missile |
|---|---|---|---|
| Plate | ×1.2 | ×1.0 | ×1.2 |
| Mail | ×1.0 | ×1.1 | ×1.2 |
| Leather | ×1.1 | ×0.8 | ×0.8 |
| None | ×1.0 | ×1.0 | ×1.0 |
Mounted = one combined horse+rider Armor stat/class.

## 4. Damage Formula
> EffectiveArmor = max(Armor × ClassVsType − Attacker.AntiArmor, 0)
> Damage = max(Raw − EffectiveArmor, ChipFloor 20% of Raw)

## 5. Engagement Gravity & Stickiness
EngageRadius 4m auto-close/rotate · disengage 3s × (1 − Agility/150) with free hits taken · rotation under contact drains 2/sec × (1 − Agility/150).

## 6. Ranged Combat
Volleys + falloff (100% → 60%). Ammo: Sling 40 · Foot bow 30 · Horse bow 20 · Javelin 10 · Pila 2–3. PARTHIAN = fire moving.
- **6.1 Friendly fire:** friendlies adjacent to the target take 70% of rolled damage.
- **6.2 Fire doctrines (assignment phase):** Fire on sight (default) / Fire at 70% range / Fire on engaged only.
- **6.3 Dead zone 15m** + one-time panic shock −10 cohesion on first penetration.

## 7. Context Modifiers
Charge (×2 dmg, ×1.5 push, 2s, needs 3s run-up) · Brace (stationary Pierce facing charge ≥1.5s negates it) · Slope (+10% push, +15% range downhill).

## 8. Phase 2 Test Scenarios
(unchanged from v1.0 — ten scenarios; add #11 below)
11. **Profile check:** identical forest patch — Low-profile skirmisher, High-profile cavalry, Massive elephant unit ordered to conceal → detected at 7.5m / 15m / never concealed at all.

---

## 10. Concealment & Ambush (FINAL — build target: Phase 3)
- **No general fog of war.** Full K&G-style visibility EXCEPT units concealed in terrain.
- **Base detection radii:** Forest 10m · Shrubland 20m.
- **Reveal triggers:** enemy inside detection radius · firing/attacking · leaving the patch.
- **RULING — permanence:** once revealed, revealed for the rest of the battle. (Re-hiding: deferred backlog.)
- **RULING — movement:** concealed units may move through large cover effectively, but detection radius **×2 while moving**. Creep, don't sprint.
- **RULING — forest missile penalty, symmetric:** −25% ranged damage firing OUT of forest and INTO forest. (Deliberate engine-proofing for a future ranged-primary era — Napoleonic variant.) Shrubs: no penalty.
- **Anti-exploit:** forests slow cavalry −40% and drain cohesion from over-wide formations · **fit rule:** full footprint inside the patch or no concealment · firing reveals instantly.
- **Order synergy:** conditional triggers ("hold concealed until enemy within X → charge") are the crown jewels of the assignment phase. Enemy scenarios may hide units too.

### 10.1 Profile Tag (FINAL)
Multiplies detection radius; the unit's physical visibility class:
| Profile | Units | Detection multiplier |
|---|---|---|
| **Low** | skirmishers, light foot | ×0.75 |
| **Medium** | formed infantry | ×1.0 |
| **High** | ALL mounted (incl. horse archers) | ×1.5 |
| **Massive** | elephants, future siege engines | **cannot conceal** |

Stacks with the movement ×2. Worked examples: stationary cavalry in forest → 15m (hard but possible — Trasimene's hidden cavalry) · moving cavalry in forest → 30m (no real surprise) · creeping skirmishers in shrub → 15m.
Profile is a reusable hook: future accuracy bonuses vs Massive, artillery targeting, UI silhouettes — one enum, many payoffs.

---

## 11. Design Status
**FROZEN.** Combat Core v1.1 + this document = the complete simulation design. No further design work scheduled until Phase 1 stat traces arrive from the workshop. Changes from here require a versioned changelog entry and Technical Director sign-off — including our own ideas. The plan protects the prototype from everyone's ambition, ours included.
