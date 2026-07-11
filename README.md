# FORMATIONS

Kings & Generals–style historical battle simulator for mobile (Godot 4.x).

## Quick start

1. Open this folder in **Godot 4.x** (Mobile renderer).
2. Press **F5** to run the battlefield placeholder scene.
3. **Desktop:** drag to pan, scroll wheel to zoom.
4. **Touch:** one-finger drag to pan, pinch to zoom.
5. Click **Test RNG** in the debug overlay to verify deterministic randomness.

### Scenario 1 (WO-002)

1. Open `tests/scenario_01.tscn` and press **F6** (Run Current Scene), or set it as main scene temporarily.
2. Two blocks march head-on, fight, and one routs off the map.
3. Click a block to see live stats in the debug panel.
4. Trace CSV is written to `tests/traces/scenario_01_<seed>.csv` when the battle ends.

### Headless tests

```bash
godot --headless --path . -s res://tests/wo001_smoke_test.gd
godot --headless --path . -s res://tests/scenario_01_autotest.gd
```

## Docs

- `docs/DEVELOPMENT_PLAN.md` — master phase plan
- `docs/COMBAT_CORE_v1.1.md` — combat design bible (Gate 0)
- `data/combat_constants.json` — all tunable gameplay constants

## Governance

Project rules live in `.cursor/rules/governance.mdc`.
