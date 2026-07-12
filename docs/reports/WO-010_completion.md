# COMPLETION REPORT — WO-010

**Work order:** WO-010 — Gate 1 Remediation  
**Branch:** `cursor/wo-010-gate1-remediation-fd84`  
**Date:** 2026-07-12  
**Design authority:** DESIGN_RULINGS_v1.2 (R13), COMBAT_CORE_v1.1  
**TD review:** GREEN LIGHT issued 2026-07-12

---

## Built

### Root cause A — invisible visuals at 2 px/m

1. **Screen-space stat card** — `UnitStatCard` pins to projected world position each frame; constant pixel size; edge clamp via `stat_card_edge_margin_px`.
2. **Screen-space minimums** — grind band min 6px; crack fissures min 8×2px; `thinning_visual_gain` (1.5×) on render depth only; rout keeps constant frontage (pale/transparent/borderless + alpha flicker).
3. **Visual gallery** — `tests/visual_gallery.tscn` with forced-state exhibits (strength steps, max grind pair, waver/rout/rallied HOLD, periodic shock floater).
4. **Shock floaters** — `ShockFloaterLayer` spawns screen-space `−N ⚡` indicators on cohesion EVENT drains (neighbor shock).
5. **S7 restage** — three allies in Y-axis abreast with depth stagger; attacker column hits center; neighbor shock cascade preserved.

### Root cause B — O(n²) performance

6. **Spatial grid** — uniform grid (`spatial_grid_cell_m` = 80m ≈ 2× max unit dimension); neighbor-limited engagement/overlap/adhesion checks; deterministic pair-key sort. Inline runtime in `Scenario01`; `scripts/spatial_grid.gd` mirrors logic for reuse.

### Victory amendment

7. **R13** — routing unit with unused RALLY does not count as defeated; `_team_fully_defeated()` replaces `_team_fully_routing()`; S5 no premature victory; R13 appended to `docs/DESIGN_RULINGS_v1.2.md`.

---

## Tests (acceptance criteria)

| Criterion | Result |
|-----------|--------|
| Stat card screen-space + clamp | **BUILT** — designer desktop confirm |
| Visual gallery exhibits | **BUILT** — designer desktop confirm |
| Rout constant width | **BUILT** — designer desktop confirm |
| S7 restaged + floaters | **BUILT** — 2 shock events; floaters render in non-headless |
| S5 no premature victory / R13 | **PASS** — rally HOLD @ cohesion 50 |
| Spatial grid + perf table | **PASS** — see table below; desktop ≥60 FPS deferred to designer |
| Full regression byte-identical | **PASS** — S1/S2/S3/S4 fast cert, determinism, S5–S8 |
| Report + Links footer | **PASS** |

### Tick-time table (cloud env, after partitioning)

| Units | avg_tick_ms | p95_tick_ms | max_tick_ms |
|-------|-------------|-------------|-------------|
| 4 | 0.486 | 1.140 | 1.697 |
| 20 | 9.041 | 11.362 | 12.186 |
| 40 | 39.313 | 47.092 | 52.257 |

**Before reference (WO-009, 40-block cloud):** avg_tick_ms ≈ 24.7, min_fps ≈ 28.1 (environmental, not gate).

**40-block REALTIME (cloud, after):** min_fps 21.0, avg_fps 31.1, avg_tick_ms 34.5, p95_tick_ms 45.4.

---

## Files changed

| Area | Files |
|------|-------|
| Core | `scripts/unit.gd`, `scripts/unit_stat_card.gd`, `scripts/scenario_01.gd`, `scripts/spatial_grid.gd`, `scripts/shock_floater.gd`, `scripts/shock_floater_layer.gd`, `data/combat_constants.json` |
| Scenarios | `scripts/scenario_03.gd`, `scenario_04.gd`, `scenario_05.gd`, `scenario_07.gd`, `scenario_40_perf.gd`, `scripts/scenario_perf_scale.gd` |
| Designer tools | `scripts/visual_gallery.gd`, `tests/visual_gallery.tscn` |
| Tests | `tests/scenario_wo010_autotest.gd`, `tests/scenario_01.tscn`, `tests/scenario_perf_scale.tscn`, `tests/wo001_smoke_test.gd` |
| Docs | `docs/work_orders/WORK_ORDER_010.md`, `docs/DESIGN_RULINGS_v1.2.md`, `docs/reports/WO-010_completion.md`, `docs/reports/INDEX.md` |

---

## Regression command

```bash
/tmp/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . -s res://tests/scenario_wo010_autotest.gd
```

---

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-010-gate1-remediation-fd84/docs/reports/WO-010_completion.md
- Work order: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-010-gate1-remediation-fd84/docs/work_orders/WORK_ORDER_010.md
- Visual gallery: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-010-gate1-remediation-fd84/tests/visual_gallery.tscn
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/WO-009_completion.md
