# COMPLETION REPORT — WO-009

**Work order:** WO-009 — Routs, Rally & the Phase 1 Finale  
**Branch:** `cursor/wo-009-routs-rally-fd84`  
**Date:** 2026-07-12  
**Design authority:** COMBAT_CORE_v1.1 §4, DESIGN_RULINGS_v1.2 (R8, R9)  
**TD review:** APPROVED with amendments (2026-07-12)

---

## Built

- **RALLY trait:** `routing → rallying (1s reform) → hold` with cohesion reset 50, max 1/battle; `test_infantry_rally.json` profile.
- **Pursuit:** Proximity damage (`pursuit_contact_m` 3m, ×4 close damage via `k_dmg`); Phase 1 scope — marching pursuers only (S6 scripted); rally timer resets on marching threat within `pursuit_radius_m` (25m) or pursuit contact.
- **Neighbor-rout shock:** One-time −15 cohesion to allies within 30m; logged as `EVENT,neighbor_rout_shock` trace rows.
- **Scenarios S5–S8** + **40-block perf** scene; `scenario_wo009_autotest.gd` extends permanent regression suite.
- **Governance:** Report Links footer rule + `docs/reports/INDEX.md`; design docs committed.

---

## TD amendments (recorded)

### S6 — Pursuit-denial expectation (formal)

**Tested mechanic:** pursuit **denies rally** (timer reset / indefinite `routing`/`rallying` under pressure).  
**Not required in Phase 1:** destruction or map exit by a same-speed pursuer. Destruction under pursuit requires **pursuer speed > flee speed** (cavalry — Phase 2).  
**Observed (accepted):** same-speed `red_pursuer` denies rally indefinitely; final state `rallying`, 56 pursuit_damage events, strength 60.99.

### Perf — Gate 1 criterion

**Transferred** to designer desktop verification. Cloud-agent numbers are **environmental actuals only** (not a pass/fail gate on CI/cloud).

### Links footer — branch at review time

Pre-merge report footers use **current branch** raw URLs; `INDEX.md` retains `main` links per governance.

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
| S6 — pursuit denies rally (TD-amended) | **PASS** — rally denied (`rallying`), 56 pursuit_damage events; destruction not required Phase 1 |
| S7 — neighbor shock −15 on rout | **PASS** — 2 shock events; shock alone does not tip neighbors to wavering |
| S8 — blob ratio ≪ 3× | **PASS** — single 27.00 vs triple 44.33, ratio **1.642** |
| S1/S2/S3/S4 byte-identical regression | **PASS** — baseline trace match all seeds |
| Fast certification, determinism, compass, overlap, adhesion invariant | **PASS** |
| 40-block REALTIME perf (desktop ≥60fps) | **DEFERRED** — designer desktop verification; cloud actuals: min 28.1 fps, avg 45.7 fps, avg tick 24.7 ms |

---

## Trace excerpts

### S5 — Rally timeline (`blue_rally`, seed 1000)

```
104.0s routing → 141.0s hold (cohesion 50.0 after rallying at 140.0s)
```

### S6 — Pursuit denial (TD-amended expectation)

```
pursuit_damage events: 56 total; rally timer never completes; final state rallying (not HOLD)
Same-speed pursuer denying rally = accepted Phase 1; kill-off-map requires faster pursuer (Phase 2)
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

- **Perf:** Gate 1 60 fps criterion assigned to designer desktop run; cloud runner logged as environmental actuals only (min 28.1 fps).

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
