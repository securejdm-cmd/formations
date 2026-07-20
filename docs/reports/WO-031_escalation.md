# ESCALATION REPORT — WO-031 Order System Ambiguities

- **Work order:** WO-031 — The Order System: Data Model & Headless Execution
- **Blocker:** Several primitive/trigger interactions and geometry/schema details are not specified. WO Task 1 says escalate these rather than choose silently. Implementation is blocked until green-lighted options below.

## Ambiguities

### 1) Horn interrupts an active primitive (incl. feign_retreat)
WO example escalate. R24 says horn forces all units into orderly withdrawal (absolute_hold abandons post). Unclear when an in-progress `feign_retreat` (or `flank_move` / `swing_and_charge` mid-arc) is interrupted.

**Options:**
- **A)** Horn **immediately aborts** any active primitive and queue; unit begins fighting-withdrawal then retires toward own edge under ordered-retreat drain × Retreating Skill. Simplest; matches “all units switch.”
- **B)** Horn **queues** after the current primitive completes (feign finishes its turn-and-fight, then withdraws). Preserves feign integrity; weaker “emergency retreat.”
- **C)** Horn aborts movement primitives immediately but allows a unit already in melee under `absolute_hold`/`hold` to finish its disengage duration first (existing Sec 5 disengage), then retire.

**Recommendation:** **A** — horn is an army panic/orderly retreat; it must win over local plans immediately.

### 2) absolute_hold vs gravity / push / facing
WO asks to *state* the gravity constraint, and also lists absolute_hold vs gravity as an escalate example.

**Proposed statement (needs confirm):**
- Gravity **may rotate facing** toward a contact (square up) but **must not translate** the unit (no magnetism closure displacement, no march, no pursuit).
- **Combat push ground-shift** still applies (shove is physics of the contest, not an order).
- S44 “does not move a meter” asserts against **order/pursuit/drift**, not against push while engaged.

**Options:**
- **A)** Accept proposed statement (face-only gravity; push still shifts).
- **B)** Absolute hold freezes world position entirely (even push shift is zeroed / absorbed).
- **C)** Absolute hold also forbids auto-facing from gravity (facing frozen too); only fight edges it already has.

**Recommendation:** **A** — matches WO wording “gravity may square facing but not displace.”

### 3) flank_move / swing_and_charge arc geometry
“Waypoint arc; no pathfinding” — lateral offset, number of waypoints, and when the arc is “done” are unspecified. Gameplay values must live in data.

**Options:**
- **A)** Single intermediate waypoint: from unit position, offset perpendicular to (point − start) by `flank_arc_offset_m` (constant, exportable) on the chosen side, then final `point`. `swing_and_charge` uses that arc toward a staging point near the target’s flank/rear, then `set_march_to(target)` so R17 gait commits.
- **B)** Two intermediate waypoints (quarter-circle polyline) with offset = `flank_arc_offset_m`.
- **C)** Designer supplies explicit waypoint list in params; primitive only sequences them (no auto-arc).

**Recommendation:** **A** — cheapest, deterministic, enough for S41/S42 if offset is large (e.g. 80–120 m in data).

### 4) attack_nearest / attack_target vs routers
Do seek/engage orders pursue routing enemies or only non-routing?

**Options:**
- **A)** Only seek non-routing enemies; ignore routers (pursuit remains explicit/scripted as today).
- **B)** Seek includes routers (order becomes pursuit when target routes).
- **C)** attack_* engages living; on target rout, terminal behavior becomes HOLD (no pursuit).

**Recommendation:** **A** for v1 — keeps pursuit deliberate; S44 scripts pursuit separately.

### 5) Order-state in traces vs S1–S40 byte-identical
Adding CSV columns breaks baselines. Order-state must be observable for S41–S44.

**Options:**
- **A)** Emit `EVENT,order_state,...` lines **only when a unit has a non-empty queue** (or army horn active). Legacy scenarios emit zero new lines → byte-identical.
- **B)** Separate `*_orders.csv` sidecar for order-bearing scenarios.
- **C)** Append columns to all traces and regenerate S1–S40 baselines (violates “byte-identical” unless baselines updated in-WO — still a drift).

**Recommendation:** **A** — pure superset; no baseline churn.

### 6) Cannae wing trigger (WO says state which — not blocked)
**Stated choice (informational, not a blocker):** wings use a new trigger flavor `unit_feign_begins(center)` / or `unit_state(center, feigning)` evaluated when the center’s `feign_retreat` primitive **starts executing** (not when its wait-trigger fires). Prefer this over `after_seconds` so timing stays coupled to the center’s `enemy_within(30)` rather than a brittle constant. If TD prefers only the listed v1 trigger set, map this to existing `unit_engages` is wrong; would need green light to extend triggers with `unit_primitive_started(U, feign_retreat)`.

**Options if only listed triggers allowed:**
- **A)** Extend v1 triggers with `unit_order_started(unit_id, primitive)`.
- **B)** Use `after_seconds(T)` calibrated from seed-1000 timing (fragile across 11 seeds).
- **C)** Pre-arm wings with `enemy_within` on a shared threshold (not “center’s feign beginning”).

**Recommendation:** **A** (extend) — matches Cannae intent; still data-driven.

### 7) R23–R25 text not in repo
WO cites DESIGN_RULINGS R23–R25; `docs/DESIGN_RULINGS_v1.2.md` currently ends at R21. Content is embedded in the WO.

**Options:**
- **A)** Append R23–R25 to DESIGN_RULINGS from the WO text as part of this commit.
- **B)** Leave rulings only in the WO until a separate rulings update arrives.

**Recommendation:** **A**.

---

## Recommendation summary
Green-light bundle: **1A, 2A, 3A, 4A, 5A, 6A, 7A**.

- **AWAITING GREEN LIGHT — no order-executor code written.**
- Work order file staged for commit: `docs/work_orders/WORK_ORDER_031.md`.
