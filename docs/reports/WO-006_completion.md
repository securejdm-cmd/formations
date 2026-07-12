# COMPLETION REPORT — WO-006

**Work order:** WO-006 — Scenario 2 (Unequal Push) + Mirror Bias Audit  
**Branch:** `cursor/wo-006-scenario-02-mirror-audit-fd84`  
**Date:** 2026-07-11

---

## Built

1. **Unit profile variants (data-only)** — `test_infantry_push60.json` (pushing_power 60) and `test_infantry_push40.json` (pushing_power 40), duplicates of `test_infantry` otherwise.
2. **Scenario 2 harness** — `Scenario02` extends `Scenario01` with push60 red vs push40 blue, same 200 m layout. Tracks `strength_at_rout`, contact-line ground displacement (first contact → rout), and writes `scenario_02_<seed>.csv` traces.
3. **Mirror audit scene** — `Scenario01Mirror` extends `Scenario01`, swaps starting positions only (no edits to `scenario_01.gd` / `.tscn`). Writes `scenario_01_mirror_<seed>.csv` traces.
4. **WO-006 autotest** — `tests/scenario_wo006_autotest.gd`: Scenario 2 determinism + 11-seed acceptance + mirror bias table (seeds 1000–1004).

No combat constants or Scenario 1 files were modified.

---

## Scenario 2 — 11-seed outcome table

| Seed | Winner | strength_at_rout | Routed unit | Ground displacement | Combat (S2) | Combat (S1) |
|------|--------|------------------|-------------|---------------------|-------------|-------------|
| 1000 | red_1 | 46.42 | blue_1 | 16.40 m | 44.6 s | 76.2 s |
| 1001 | red_1 | 46.55 | blue_1 | 16.26 m | 44.2 s | 83.4 s |
| 1002 | red_1 | 46.38 | blue_1 | 16.35 m | 44.6 s | 77.0 s |
| 1003 | red_1 | 46.54 | blue_1 | 16.26 m | 44.2 s | 84.2 s |
| 1004 | red_1 | 46.54 | blue_1 | 16.28 m | 44.4 s | 96.2 s |
| 1005 | red_1 | 46.38 | blue_1 | 16.34 m | 44.2 s | 75.2 s |
| 1006 | red_1 | 46.54 | blue_1 | 16.28 m | 44.2 s | 73.2 s |
| 1007 | red_1 | 46.53 | blue_1 | 16.27 m | 44.4 s | 77.2 s |
| 1008 | red_1 | 46.51 | blue_1 | 16.32 m | 44.2 s | 82.0 s |
| 1009 | red_1 | 46.51 | blue_1 | 16.28 m | 44.2 s | 91.4 s |
| 12345 | red_1 | 46.47 | blue_1 | 16.30 m | 44.4 s | 78.0 s |

**push60 (red_1) wins:** 11 / 11 (0 upsets).

**strength_at_rout (measured, not tuned):** 46.38–46.55 across all seeds (~46% of max strength). Design target band is 55–80% (60–75% nominal). **Finding for TD review** — rout occurs with substantially more men standing than a wipe, but below the documented band.

**Combat duration vs Scenario 1:** Scenario 2 combat ~44.2–44.6 s vs Scenario 1 mirror grind ~73–96 s on the same seeds — **~40–50% shorter**, as expected for unequal push.

**Ground displacement:** ~16.3 m net toward the loser (blue) on every seed — contact line advances steadily into push40 territory before rout.

---

## Mirror bias audit (Scenario 1, seeds 1000–1004)

| Seed | Normal winner | Mirrored winner | SYMMETRIC |
|------|---------------|-----------------|-----------|
| 1000 | red_1 | red_1 | **NO** |
| 1001 | red_1 | red_1 | **NO** |
| 1002 | blue_1 | blue_1 | **NO** |
| 1003 | blue_1 | blue_1 | **NO** |
| 1004 | red_1 | red_1 | **NO** |

**All 5 seeds asymmetric** — winner is identical after side swap; the occupant of each starting slot does **not** flip. Swapping positions did not change any outcome. **Escalated** per Task 4; see [`docs/reports/WO-006_escalation.md`](WO-006_escalation.md). No patch applied.

---

## Test results

| Criterion | Result |
|-----------|--------|
| Scenario 2 runs on all 11 seeds with full results table | **PASS** |
| push60 wins all or nearly all (≤1 upset) | **PASS** (11/11) |
| strength_at_rout reported as measured | **PASS** (~46%; below design band — finding) |
| Combat shorter than Scenario 1 | **PASS** (~44 s vs ~73–96 s) |
| Ground displacement reported | **PASS** (~16.3 m toward loser) |
| Scenario 2 determinism (seed 12345) | **PASS** |
| Scenario 2 no-overlap assertion | **PASS** |
| Mirror audit table delivered | **PASS** |
| Mirror asymmetries escalated, not patched | **PASS** |
| No constant or scenario-1 changes | **PASS** |

---

## Files changed

| File | Change |
|------|--------|
| `data/units/test_infantry_push60.json` | New push60 profile |
| `data/units/test_infantry_push40.json` | New push40 profile |
| `scripts/scenario_02.gd` | Scenario 2 harness + rout/displacement metrics |
| `scripts/scenario_01_mirror.gd` | Side-swapped Scenario 1 for mirror audit |
| `tests/scenario_02.tscn` | Scenario 2 scene |
| `tests/scenario_01_mirror.tscn` | Mirror audit scene |
| `tests/scenario_wo006_autotest.gd` | WO-006 acceptance harness |
| `docs/reports/WO-006_completion.md` | This report |
| `docs/reports/WO-006_escalation.md` | Mirror bias escalation |

---

## Assumptions made

**NONE**

---

## Known issues

- **strength_at_rout below design band** (~46% vs 55–80% target) — reported as finding; no constants tuned per WO directive.
- **Mirror bias: 5/5 asymmetric** — escalated; winner appears tied to team identity, not starting position (see escalation report).
- **Mirror runs trigger overlap assertions** during late combat on some seeds — observed in mirror scene only; not patched per Task 4 scope.
- Designer hand-confirm items from prior WOs (stat card, bump, front-crack visuals, victory UI) remain open.
