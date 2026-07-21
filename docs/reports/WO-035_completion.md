# COMPLETION REPORT — WO-035 UI Handoff Sim Unification

- **Work order:** WO-035 — UI Handoff Sim Unification + Deploy Reposition
- **Built:** Diagnosed UI battle vs certified tick; deferred sim-thread start until battle metadata applied; permanent UI-launch smoke + encirclement integrity; brace/bump render fixes; deploy click-select + drag-to-move.
- **Files changed:** `docs/work_orders/WORK_ORDER_035.md`, this report; `scripts/scenario_from_data.gd`; `scripts/unit.gd` (brace axes + local bump); `scripts/ui/deployment_screen.gd` (reposition); `data/battles/wo035_encirclement.json`; `tests/wo035_ui_launch_smoke.gd`; suite expect **90**.
- **Tests:** Suite **PASS=90 FAIL=0 exit=0**; UI-launch smoke PASS; encirclement 3+ edges PASS; GAMEPLAY_TICK p95 ≈ **47.1ms** @ 40u (cloud)
- **Assumptions made:** NONE
- **Known issues:** none blocking

## Task 1 — Line-by-line handoff vs certified tick

| Stage | scenario_01..54 (certified body) | ScenarioFromData / UI handoff (before fix) | After WO-035 |
|---|---|---|---|
| Tick entry | `SimBattleCore.advance_one_tick` → `advance_one_tick_fast` | **Identical** (inherited; not overridden) | Identical |
| WO-019 sub-stepping | `ChargeCombat.march_substep_count` in proxy march | **Identical** | Identical |
| Allied no-overlap resolve | `resolve_allied_overlaps` every tick | **Identical** | Identical |
| Adhesion (×2) | `apply_contact_adhesion` pre/post combat | **Identical** | Identical |
| Contact coherence | `assert_partner_classifier_contact_invariant` | **Identical** | Identical |
| Overlap **assert** | ON only if `headless ∧ fast_sim` (WO-024) | Same rule (OFF on designer realtime) | Same (smoke uses headless+fast) |
| Sim-thread routing | `_setup_sim_thread` → worker `advance_one_tick` | Same defaults (`use_sim_thread=true`, `fast_sim=false`) | Same |
| **Fork found** | Thread starts inside `Scenario01._ready` when enabled | **Subclass wrote `battle_type` / zones / victory / terrain / height onto core AFTER `super._ready()`** — worker could tick in a partial-init window | **UNIFIED:** temporarily disable auto/thread for `super._ready`, `_apply_battle_metadata_to_core()`, then start thread exactly as Scenario01 |
| First main-thread tick after UI | N/A (threaded path applies snapshots only) | No main-thread `advance_one_tick` while thread active | Unchanged / correct |
| Spawn | Scenario scripts | JSON/`pending_battle` via `BattleScenarioData.spawn_unit_node` | Unchanged (data only) |

**Verdict:** Tick algebra was already the certified function. The handoff defect was **deferred metadata after thread start**. Unified so the UI battle starts the certified sim only when fully configured.

## Task 2 — Prove it

- UI data path (`wo034_pitched_deploy` hand placements → merge → ScenarioFromData headless+fast): no-overlap + coherence for full battle → **PASS**
- Full encirclement (`wo035_encirclement.json`, multi-attacker): no-overlap + coherence; saw **3+ edge channels / partners** → **PASS**
- Suite gate: `[WO-035] UI-launch smoke`

## Task 3 — Bent body

- **Render-only.** True footprint (`FormationGeometry` OBB / sim proxy) stays rigid rectangles.
- Cause: (1) brace/instinctive indicators used **swapped local axes** (T-shaped “joint”); (2) engage bump offset applied **world facing into local** VisualRoot position, skewing the body off the facing axis.
- Fixed both visuals; sim untouched.

## Task 4 — Deploy reposition

- Root cause: Unit `Area2D` ate clicks so `_unhandled_input` never started drag.
- Fix: pointer on `_input`; `input_pickable=false` on deploy visuals; click-select + drag-to-move + remove still available.

## How to test (designer)

1. F5 `scenes/deployment_screen.tscn`
2. Place units; click a placed block and drag to reposition; R / right-drag to face; Delete to unset
3. READY → battle; confirm clean contact faces (no merge) and straight blocks (no kinked brace)
4. Optional: `godot --headless -s res://tests/wo035_ui_launch_smoke.gd`

## Designer hand-confirm

- [ ] Reposition works
- [ ] UI battle contact looks clean like S40
- [ ] Blocks no longer bent at the joint
