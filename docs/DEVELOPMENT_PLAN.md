# FORMATIONS (working title)
## Master Development Plan — v1.0
*A Kings & Generals–style historical battle simulator for mobile*

---

## 1. The Studio

| Role | Who | Responsibilities |
|---|---|---|
| Designer & Product Owner | You | Vision, design decisions, human play-testing, final say on everything |
| Technical Director & Studio Voice | Claude | Translate design into specs, review reports, approve/reject changes, plan phases, analyze balance data |
| Workshop (Engineering) | Cursor AI + Godot | Implement specs exactly as written, run tests, produce reports, escalate all deviations |

### The Workflow Loop
1. **You + Claude** define a work order (small, specific, testable).
2. **You** paste the work order into Cursor.
3. **Cursor** implements it under the governance rules (see CURSOR_RULES file).
4. **Cursor** produces a completion report (or an escalation report if blocked).
5. **You** paste the report back to Claude.
6. **Claude** reviews, then issues: ✅ Approved / 🔁 Revise / 🛑 Stop & discuss.
7. **You** play-test at every phase gate. No gate passes without your hands-on approval.

### Ground Rules
- **Small work orders.** Nothing bigger than ~1 session of work. Big tasks hide big mistakes.
- **Cursor never invents.** Ambiguity = escalation, not improvisation.
- **You are the courier and the veto.** Claude cannot see the code directly; reports must include the relevant details. When in doubt, paste more, not less.
- **Version control from day one.** Git commit at every approved work order. This is your undo button and it is non-negotiable.

---

## 2. Engine & Project Setup Decisions (Locked)

- **Engine:** Godot 4.x (free, excellent 2D, exports to iOS/Android, GDScript is readable enough that you can paste it to Claude for review)
- **View:** 2D top-down. Units are colored rectangles (formations), NOT individual soldiers. This is both the prototype aesthetic and close to the final aesthetic.
- **Orientation:** Landscape.
- **Simulation model:** Each "unit" is one entity (a block) with stats, facing, formation width/depth, cohesion, and morale. We do NOT simulate individual soldiers. This keeps mobile performance trivial and matches the K&G look.
- **Determinism goal:** Same battle + same orders = same result (seeded RNG). Critical for testing and balancing.

---

## 3. Phase Plan

Each phase ends with a **GATE**: written acceptance criteria + your hands-on play-test + Claude's report review. All three pass, or we don't move on.

---

### PHASE 0 — Design Bible & Project Skeleton
*Goal: agree on rules before code exists.*

**Deliverables**
- Game Design Document v1: unit stat list (final names + what each does), the 3 unit categories and their rock-paper-scissors relationships, morale model, combat resolution math (written in plain English + formulas)
- Godot project created, git repo initialized, CURSOR_RULES installed
- Placeholder scene: empty battlefield, camera pans/zooms with touch

**GATE 0 criteria**
- [ ] You can read the combat math doc and explain it back in your own words
- [ ] Project opens in Godot, runs on your phone or emulator, camera works
- [ ] Cursor has acknowledged the rules file in a test escalation

---

### PHASE 1 — Core Simulation ("Two Blocks Fighting")
*Goal: prove the math. Ugly is mandatory.*

**Scope**
- Unit entity: position, facing, speed, formation footprint
- Movement with basic collision (blocks can't overlap)
- Melee resolution when blocks contact: damage exchange using close-range attack vs armor, pushing power resolves who gives ground
- Morale: units accumulate shock (casualties, flanked, rear-charged); at threshold → rout (block turns pale, flees to map edge)
- Casualty visualization: block shrinks/thins as it takes losses (the K&G signature)
- Debug overlay: live stat readout per unit
- **No player controls yet** beyond starting the sim. Battles are pre-scripted test scenarios.

**Test scenarios (Cursor must build these as runnable tests)**
1. Identical blocks head-on → near-mutual destruction, slight advantage to random seed
2. High armor vs low armor → armor wins with expected casualty ratio
3. Flank attack → flanked unit routs before destroyed
4. High pushing power → visibly drives enemy backward

**GATE 1 criteria**
- [ ] All 4 scenarios pass and Claude has reviewed the numbers report
- [ ] You watch each scenario and it *looks* like a K&G battle moment
- [ ] 60fps with 40 blocks on a mid-range phone

---

### PHASE 2 — Unit Categories & Ranged Combat
*Goal: the triangle. Foot / Archer / Mounted.*

**Scope**
- Archers: range, ammunition, damage falloff, can't fire while moving (design decision pending), vulnerable in melee
- Mounted: speed, devastating charge bonus (first contact), weak in prolonged melee vs braced spears
- Anti-armor stat now active (e.g., armor-piercing arrows vs knights)
- Terrain v1: passable/impassable, and one modifier (e.g., hill = ranged bonus)

**GATE 2 criteria**
- [ ] Rock-paper-scissors verified by automated matchups: cavalry beats archers, archers attrit infantry, braced infantry beats cavalry — with margins Claude reviews
- [ ] A mixed 6v6 scripted battle looks dynamic and readable to you

---

### PHASE 3 — The Command Layer (YOUR KILLER FEATURE)
*Goal: deployment + conditional orders. This is the phase that makes it your game.*

**Scope**
- **Deployment stage:** drag blocks into a deployment zone, rotate facing, snap-to-line helpers
- **Assignment stage:** per unit-group ("general"), build an order queue from primitives:
  - Advance to point / Hold position / Attack nearest / Attack specific target
  - Feigned retreat (fall back X distance, then turn)
  - Flank left/right (path around engagement)
  - **Conditional triggers:** "when enemy closes within X" / "when unit Y engages" / "when my morale below X" / "after T seconds"
- **Battle stage v1:** orders execute, you watch. Pause allowed. No mid-battle input yet.
- Order visualization: arrows on map (the K&G look, again)

**GATE 3 criteria**
- [ ] You can script a hammer-and-anvil (pin with infantry, flank with cavalry) using only the order UI, and it works
- [ ] You can script a Cannae-style feigned center retreat + double envelopment
- [ ] A first-time tester (friend/family) understands the order UI in <5 minutes

---

### PHASE 4 — Player Agency in Battle
*Goal: drop-in control + the AI opponent.*

**Scope**
- **Drop-in:** tap a unit during battle → issue direct move/attack/retreat commands, overriding its script; costs Command Points (limited resource)
- Battle speed controls (pause / 1x / 2x)
- **Enemy AI v1:** plays scripted plans per scenario (not adaptive yet — that's fine)
- Win/loss conditions: rout %, objective held, general slain

**GATE 4 criteria**
- [ ] You lose a battle on autopilot, then win the same battle using drop-in interventions — proving agency matters
- [ ] Command Point costs feel like meaningful choices (your judgment)

---

### PHASE 5 — Content Framework & Balance Harness
*Goal: dozens of units WITHOUT dozens of balance nightmares.*

**Scope**
- **Unit template system:** base archetypes (levy spear, professional heavy foot, skirmisher, foot archer, horse archer, shock cavalry, etc.) defined in data files (JSON/resource files), not code — so YOU can create units by editing numbers
- First 2 cultures built from templates + 3–5 unique rule-breaker units each (e.g., Rome: pilum volley before contact; Steppe: shoot while moving)
- **Auto-balance harness:** headless batch simulator runs N thousand matchups overnight, outputs win-rate matrices → Claude reads these reports and recommends stat changes
- Point-cost system so armies can be compared fairly

**GATE 5 criteria**
- [ ] You created a new unit yourself by editing a data file, without touching code
- [ ] Balance matrix shows no unit above/below agreed win-rate bounds vs its counters
- [ ] Battles between the 2 cultures feel distinct to you

---

### PHASE 6 — Presentation Pass
*Goal: make it feel like a K&G video.*

**Scope**
- Final block visual language (colors, borders, unit-type icons, elevation shading)
- Casualty thinning, rout animations, dust/impact feedback, arrow volleys visualized
- Map art style (parchment? satellite-documentary?), UI skin
- Sound: ambient battle, horns for orders, narrator-style stingers (stretch)
- Onboarding tutorial built from Phase 3–4 mechanics

**GATE 6 criteria**
- [ ] Side-by-side: a screenshot of your game vs a K&G video frame reads as "same family"
- [ ] New tester completes tutorial unaided

---

### PHASE 7 — Campaign & Ship
*Goal: the first sellable slice.*

**Scope**
- Scenario campaign #1 (e.g., Second Punic War: ~8–10 battles, briefing screens, persistent army between battles: veterans, casualties)
- Difficulty settings, save system
- Store-readiness: icons, screenshots, page copy, builds via Godot export, TestFlight / Play internal testing
- Monetization scaffolding for future DLC (locked, empty — architecture only)

**GATE 7 criteria**
- [ ] You finish the campaign start-to-end on a real phone with zero crashes
- [ ] 5 external testers complete battle 1–3 and report via a feedback form Claude designs

---

## 4. Deferred (Post-Launch Backlog — do NOT build early)
- Additional culture DLC packs (by era)
- Adaptive enemy AI
- Multiplayer (async "send your battle plan" mode is the realistic version)
- Risk-style conquest map
- Weather, fatigue, supply
- User scenario editor

---

## 5. Standing Report Formats

**Cursor Completion Report** (every work order)
- Work order ID + summary of what was built
- Files changed
- Test results (pass/fail per criterion)
- Any assumptions made (should be NONE — assumptions are escalations)
- Known issues

**Cursor Escalation Report** (any blocker/deviation)
- What was asked, what blocks it
- 2–3 options with tradeoffs in plain English
- Recommendation (Cursor may recommend; may not proceed)

**Claude Balance Review** (Phase 5+)
- Win-rate matrix anomalies, suspected causes, proposed stat deltas, predicted effects

---

## 6. Risks & Honest Notes

- **The courier model has friction.** You'll paste a lot of text between Claude and Cursor. Keep work orders small so reports stay digestible.
- **Rules files aren't handcuffs.** Cursor can still drift. Your defenses: small phases, git commits, acceptance tests you run yourself, and pasting suspicious code/reports to Claude.
- **Scope is the killer.** Everything in section 4 stays deferred until Phase 7 ships. The plan's job is to protect the prototype from our own ambition.
- **Budget reality:** Godot + Cursor + Claude ≈ subscription costs only. Your costs are time, an Apple/Google developer account (~$99/yr + $25 one-time), and eventually sound/music licensing.
