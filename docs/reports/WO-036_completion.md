# COMPLETION REPORT — WO-036 Rotated Contact Detection (OBB Unification)

- **Work order:** WO-036 — Rotated Contact Detection (OBB Unification)
- **Built:** Contact path floors on true oriented footprints (OBB SAT). Angled corner clips engage and resolve combat instead of staying MARCHING while visually merged. Permanent S55 + suite smoke. Head-on axis-aligned path unchanged (center-gap primary; S1 combat times byte-identical).
- **Files changed:** `docs/work_orders/WORK_ORDER_036.md`, this report; `scripts/combat_resolver.gd`; `scripts/edge_contact.gd`; `scripts/sim/sim_unit_proxy.gd`; `scripts/unit.gd`; `scripts/scenario_55.gd`; `tests/scenario_55.tscn`; `tests/wo036_rotated_contact_smoke.gd`; `tests/scenario_wo010_autotest.gd` (expect **91**).
- **Tests:** Suite **PASS=91 FAIL=0 exit=0**; S55/rotated smoke PASS; WO-035 UI-launch PASS; S1 seed 1000 combat=54.8s (unchanged); Fast-mode + threaded cert byte-identical; GAMEPLAY_TICK p95 from suite log below.
- **Assumptions made:** NONE
- **Known issues:** Battle-speed presentation (log only — see below); not blocking.

## (1) Geometry report — AABB vs OBB

| Path | Geometry used (before WO-036) | After WO-036 |
|---|---|---|
| **Render footprint** | Oriented rectangle from facing + frontage/depth (`FormationGeometry.get_corners`) | Unchanged — true OBB |
| **Allied separation** | `FormationGeometry.rectangles_overlap` — **OBB SAT** | Unchanged |
| **Head-on engage** | `center_gap_m` / depth-sum along facing (**not** full OBB∩OBB) | Unchanged as primary; **OBB floor** if gap still open |
| **Edge classifier** (`EdgeContact._classify_contact_impl`) | Defender-local projection of attacker corners (AABB of corners in defender frame) + **edge slabs**. Head-on early-out returned **empty** until center-gap closed — **missed rotated corner clips** | Same slabs for edge labels; early-out skipped when OBB hits; empty slabs + OBB → dominant-edge fallback contact |
| **`units_have_any_contact`** | Center-gap (head-on) OR edge-slab contact | Same, then **`FormationGeometry.rectangles_overlap` OBB floor** |
| **Overlap assert (`units_overlap`)** | Head-on used center-gap penetration; could flag partnered combat | Enemy OBB merge is a defect only when **unpartnered** and **not** `auto_engage_locked` (horn/disengage walk-away remains intentional) |
| **True OBB SAT** | `FormationGeometry.rectangles_overlap` / `_obb_overlap` | Contact floor |

**Verdict:** The defect was not a world-axis AABB on the unit body, but an **insufficiently oriented contact test**: head-on deferred to center-gap, and edge slabs could miss interior/angled interpenetration. Render and allied resolve already used OBB; contact did not. Unified: **any true OBB overlap ⇒ contact**.

**Follow-on hardening (same WO, no behavior change to horn/ambush):** `complete_disengage` must not clobber ROUTING/RALLYING into MARCHING (prevents false revive after formless tunnel).

## (2)–(3) Angled repro + permanent smoke

- **Static fixture:** ~45° relative facing, OBB overlap with center-gap still open (~7.8 m) → `units_have_any_contact == true`.
- **S55:** Attacker from NE (~45°), defender HOLD +X; gravity rotates on approach (first-contact facing ~39° off world ±X). Asserts ENGAGED/WAVERING, damage dealt, and **never** OBB-overlap while MARCHING without partners.
- Suite gate: `[WO-036] rotated-contact smoke`
- Standalone: `godot --headless -s res://tests/wo036_rotated_contact_smoke.gd`

## (4) Head-on byte-identical

- Axis-aligned head-on still uses center-gap first; for square facing±X, OBB overlap coincides with gap≤0.
- S1×11 combat times unchanged (seed 1000 = **54.8s**).
- Fast-mode certification + threaded certification: **trace byte-identical**.
- Full suite green **PASS=91**.

## Battle speed (non-blocking — for battle-view WO)

Designer runs **16×** to progress; playback feels too slow. This is a **presentation** control only:

- Default battle view ~**3–4×**
- Selector: **1× / 2× / 4× / 16×**
- **Do not** change sim tick rate, closing speeds, or combat timing

Logged here; not implemented in this WO.

## How to test (designer)

1. F5 `scenes/deployment_screen.tscn` → place → READY
2. Approach at an angle / let gravity rotate into contact — units should leave MARCHING, show partners, take/deal damage; no “merged but idle” blocks
3. Optional: open `tests/scenario_55.tscn` for the staged angled duel
4. Optional headless: `godot --headless -s res://tests/wo036_rotated_contact_smoke.gd`

## Suite attestation

- **PASS=91 FAIL=0 exit=0**
- `[WO-036] rotated-contact smoke` PASS (static OBB+contact, engaged, combat, obb_march=false, off_x≈39.3°)
- `[WO-035] UI-launch smoke` PASS
- S1 seed 1000 combat=54.8s; Fast-mode cert PASS; Threaded cert PASS; Determinism PASS
- GAMEPLAY_TICK p95=**34.782ms** @ 40u (GATE_50MS PASS)
