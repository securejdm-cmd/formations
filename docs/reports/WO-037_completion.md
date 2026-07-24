# COMPLETION REPORT — WO-037 Facing Unit-Length Invariant

- **Work order:** WO-037 — Facing Unit-Length Invariant
- **Built:** Facing is normalize-on-write on Unit + SimUnitProxy; FormationGeometry / magnetism / march turns harden unit length; permanent per-tick facing assert; S56 cavalry charge→engage→wheel smoke; debug panel no longer rounds facing (false `(-1,-1)` alarm).
- **Files changed:** `docs/work_orders/WORK_ORDER_037.md`, this report; `scripts/formation_geometry.gd`; `scripts/unit.gd`; `scripts/sim/sim_unit_proxy.gd`; `scripts/magnetism.gd`; `scripts/sim/sim_battle_core.gd`; `scripts/scenario_01.gd`; `scripts/scenario_56.gd`; `tests/scenario_56.tscn`; `tests/wo037_facing_normalize_smoke.gd`; `scripts/scenario_debug_overlay.gd`; suite expect **92**.
- **Tests:** Suite **PASS=92 FAIL=0 exit=0**; facing smoke PASS (static `(-1,-1)`→unit; wheeled=true; max_err=0); S1 seed 1000 combat=54.8s unchanged; Fast/Threaded cert byte-identical; GAMEPLAY_TICK p95=**35.029ms**.
- **Assumptions made:** NONE
- **Known issues:** none blocking

## (1) Facing-write audit

| Site | Normalizes? (before) | After WO-037 |
|---|---|---|
| `Unit.configure` → `facing = face_direction.normalized()` | Yes | Setter also normalizes |
| `Unit` / `SimUnitProxy` march auto-turn: `facing = desired` (already unit) | Yes | Setter |
| `Unit` / `SimUnitProxy` march auto-turn: `facing = facing.rotated(...)` | **Preserves length** (drift / prior non-unit sticks) | **Re-normalize after rotate** + setter |
| `Magnetism.rotate_toward`: `facing = want` / `facing.rotated(...)` | want yes; rotated preserves | **Re-normalize after rotate** + setter |
| `begin_wheel_facing` / snap to `wheel_facing_target` | Target normalized | Setter |
| `complete_disengage` → `facing = to_target.normalized()` | Yes | Setter |
| `_face_nearest_threat` → `facing = to_enemy.normalized()` | Yes | Setter |
| Proxy↔Unit sync (`facing = unit.facing`) | Copy | Setter re-asserts unit length |
| Scenario / deploy / `facing_from_dict` | Mostly yes | Unchanged; setter is backstop |
| **Debug panel** `facing.round()` | **Display bug:** (−0.707,−0.707) prints as (−1.0,−1.0) | Shows `(x,y) \|len\|=…` |

**Suspect class (TD):** incremental `rotated()` without re-normalize — confirmed as the only sim path that could *preserve* a non-unit facing once introduced. Gravity / charge / wheel / hold-threat writes already preferred `.normalized()` destinations.

**Note on SAT / OBB:** `get_corners` already used `facing.normalized()` before this WO, and `_obb_overlap` already normalized SAT axes. So a non-unit facing alone would **not** skew the contact OBB used by WO-036. The designer panel’s `(-1,-1)` was consistent with a **rounded unit diagonal**. Regardless, normalize-on-write + invariant close the hole for every consumer that reads raw `facing` (dots, debug, future code).

## (2)–(4) Boundary + invariant + defensive SAT

- `FormationGeometry.normalize_facing` / `facing_is_unit` / FACING_UNIT_EPS=0.01
- `Unit.facing` and `SimUnitProxy.facing` setters call `normalize_facing`
- `left_vector` / `right_vector` normalize input
- `_obb_overlap` keeps explicit `axis.normalized()` (documented WO-037)
- `SimBattleCore.assert_facing_unit_length` runs with overlap asserts (headless+fast)

## (5) Smoke — rotate while engaged

- S56: cavalry from NE → engage → `begin_wheel_facing(+90°)` under contact
- Asserts: engaged, combat damage, wheel observed, facing unit-length every tick, core facing assert clean
- Suite: `[WO-037] facing-normalize smoke`
- Standalone: `godot --headless -s res://tests/wo037_facing_normalize_smoke.gd`

## (6) Regression

- S1 seed 1000 combat=**54.8s**; Fast-mode + Threaded cert **byte-identical**
- PASS=**92** FAIL=0 exit=0

## How to test (designer)

1. F5 deploy → READY → angled cavalry contact + rotate
2. Debug panel Facing line now shows true components and `|len|` (must be ≈1.000)
3. Optional: `tests/scenario_56.tscn` / headless smoke above
