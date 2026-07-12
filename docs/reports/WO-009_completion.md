# COMPLETION REPORT — WO-009

**Work order:** WO-009 — Routs, Rally & the Phase 1 Finale  
**Branch:** `cursor/wo-009-routs-rally-fd84`  
**Date:** 2026-07-12  
**Design authority:** COMBAT_CORE_v1.1 §4, DESIGN_RULINGS_v1.2 (R8, R9)

---

## Built

- **RALLY trait:** `routing → rallying (1s reform) → hold` with cohesion reset 50, max 1/battle; `test_infantry_rally.json` profile.
- **Pursuit:** Proximity damage (`pursuit_contact_m` 3m, ×4 close damage via `k_dmg`); Phase 1 scope — marching pursuers only (S6 scripted); rally timer resets on marching threat within `pursuit_radius_m` (25m) or pursuit contact.
- **Neighbor-rout shock:** One-time −15 cohesion to allies within 30m; logged as `EVENT,neighbor_rout_shock` trace rows.
- **Scenarios S5–S8** + **40-block perf** scene; `scenario_wo009_autotest.gd` extends permanent regression suite.
- **Governance:** Report Links footer rule + `docs/reports/INDEX.md`; design docs committed.

---

## Files changed

| Area | Files |
|------|-------|
| Core | `scripts/unit.gd`, `scripts/scenario_01.gd`, `scripts/combat_resolver.gd`, `data/combat_constants.json`, `data/units/test_infantry_rally.json` |
| Scenarios | `scripts/scenario_05.gd`–`scenario_08.gd`, `scripts/scenario_40_perf.gd`, `tests/scenario_05.tscn`–`scenario_08.tscn`, `tests/scenario_40_perf.tscn` |
| Tests | `tests/scenario_wo009_autotest.gd`, `tests/wo001_smoke_test.gd` |
| Docs | `docs/DESIGN_RULINGS_v1.2.md`, `docs/work_orders/WORK_ORDER_009.md`, `docs/reports/INDEX.md`, `docs/reports/WO-009_completion.md`, `.cursor/rules/governance.mdc` |

---

## Tests (acceptance criteria)

| Criterion | Result |
|-----------|--------|
| S5 — standard exits; RALLY reforms HOLD @ cohesion 50 | **PASS** — standard `removed`, rally `hold` cohesion 50.0 |
| S6 — pursuit denies rally | **PASS** — final state `rallying`, 56 pursuit_damage events, strength 60.99 |
| S7 — neighbor shock −15 on rout | **PASS** — 2 shock events; shock alone does not tip neighbors to wavering |
| S8 — blob ratio ≪ 3× | **PASS** — single 27.00 vs triple 44.33, ratio **1.642** |
| S1/S2/S3/S4 byte-identical regression | **PASS** — baseline trace match all seeds |
| Fast certification, determinism, compass, overlap, adhesion invariant | **PASS** |
| 40-block REALTIME perf (desktop ≥60fps) | **REPORT ACTUALS** — min 28.1 fps, avg 45.7 fps, avg tick 24.7 ms (cloud runner; below 60 fps gate) |

---

## Trace excerpts

### S5 — Rally timeline (`blue_rally`, seed 1000)

```
104.0s routing → 141.0s hold (cohesion 50.0 after rallying at 140.0s)
```

### S6 — Pursuit ticks (sample)

```
pursuit_damage events: 56 total; rally blocked in rallying state at end
```

### S7 — Shock events (tick 40.0s)

```
40.0,EVENT,neighbor_rout_shock,victim=red_left,source=red_center,drain=15.0
40.0,EVENT,neighbor_rout_shock,victim=red_right,source=red_center,drain=15.0
```

---

## Assumptions made

**NONE**

---

## Known issues

- **Perf gate on cloud runner:** 20v20 REALTIME min_fps 28.1 on this environment (avg 45.7). Numbers reported as actuals per standing rules; desktop TD verification recommended for Gate 1 60 fps criterion.

---

## Regression command

```bash
/tmp/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . -s res://tests/scenario_wo009_autotest.gd
```

---

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/WO-009_completion.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/MERGE_BATCH_completion.md
- Trace S5: https://raw.githubusercontent.com/securejdm-cmd/formations/main/tests/traces/scenario_05_1000.csv
- Trace S6: https://raw.githubusercontent.com/securejdm-cmd/formations/main/tests/traces/scenario_06_1000.csv
- Trace S7: https://raw.githubusercontent.com/securejdm-cmd/formations/main/tests/traces/scenario_07_1000.csv
- Trace S8 single: https://raw.githubusercontent.com/securejdm-cmd/formations/main/tests/traces/scenario_08_1000_1.csv
- Trace S8 triple: https://raw.githubusercontent.com/securejdm-cmd/formations/main/tests/traces/scenario_08_1000_3.csv
