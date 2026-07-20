# ESCALATION REPORT — WO-032 Concealment & Ambush

- **Work order:** WO-032 — Concealment & Ambush
- **Blocker:** Sec 10 / Task 1 require forest cohesion drain from “over-wide formations” with “threshold + rate as constants,” but neither DAMAGE_AND_CATEGORIES §10 nor the WO gives numeric values. S48 must assert the drain. Inventing numbers would be a silent balance decision.
- **No concealment / ambush code written** (sim_battle_core restored clean after a bad edit). WO doc commit only on branch.

## Ambiguity 1 — Forest over-wide frontage threshold

What frontage (meters) counts as “over-wide” inside a FOREST patch?

**Options:**
- **A)** `forest_overwide_frontage_m = 40.0` — equal to `default_infantry_block_frontage_m`. Anything wider than a standard block drains. Simple anti-exploit; S48 can spawn 60m-wide vs 30m-wide controls.
- **B)** `forest_overwide_frontage_m = 30.0` — equal to test cavalry frontage; tighter.
- **C)** Designer supplies an exact meter value (write it here).

**Recommendation:** **A** — matches the only existing “standard block” constant; clear for S48.

## Ambiguity 2 — Forest over-wide cohesion drain rate

How fast does cohesion fall while over-wide and inside FOREST?

**Options:**
- **A)** `forest_overwide_cohesion_drain_per_sec = 2.0` — same magnitude as `rotate_under_contact_drain` (2/sec). Noticeable in a short S48 window; not instantly catastrophic.
- **B)** `forest_overwide_cohesion_drain_per_sec = 1.0` — same as `ordered_retreat_drain_per_sec`. Milder.
- **C)** Designer supplies an exact per-second rate (write it here).

**Recommendation:** **A** — anti-exploit should bite on the timescale of a march through cover.

## Stated implementations (not blockers — confirm or correct)

These will be coded as stated unless TD objects in the green light:

1. **Enemy invisibility:** Concealed units are omitted from `SimBattleCore.enemies_for` (covers gravity, charge commit, brace clock, march auto-behaviors) and from `OrderExecutor._is_living_enemy` (covers enemy `enemy_within` triggers and `attack_nearest` / `attack_target` seek). Direct unit walks in volley targeting / dead-zone also skip concealed-from-viewer. Own-side triggers and allies still see them (asymmetric). Physical contact/engage still possible once the ambusher closes; firing or attacking reveals.
2. **Brace clock from reveal:** Because concealed chargers are absent from the defender’s `enemies` list, `_threat_front_sec` does not accumulate until reveal. After reveal they re-enter immediately → clock starts at reveal, not approach. Ambush contact inside `brace_reaction_s` of reveal → Tier 3.
3. **“Moving” for detection ×2:** `current_speed_m_s > brace_stationary_speed` (existing 0.2 m/s constant). HOLD/creep below that = stationary radius.
4. **Detection distance:** center-to-center meters via existing `ChargeCombat.distance_m` (matches all other radii).
5. **Cavalry forest −40% speed:** applies when unit `profile == "High"` (Sec 10.1: High = all mounted).
6. **Empty-queue perf (Task 5):** Root cause of 26.887→31.834 — every tick still calls `_tick_orders` → `activate_if_needed()`, which **scans all units** even when no queues exist. Claimed “no-op when empty” is not free. Trivial fix planned: sticky army-wide `orders_armed` (set when any queue/horn registered); skip executor entirely when false. 5-run variance will be reported with the implementation commit.

## Merge note (WO-031)

- Main tip / WO-031 merge SHA: `29ad884b057ca064025f5a13b39568e8ee9a9ad1`
- Suite was green on main at merge (PASS=78). R26 remains drafted, not appended.

**AWAITING GREEN LIGHT — no concealment code written.**

Example reply: `GREEN LIGHT: 1A, 2A` (and any corrections to stated implementations).
