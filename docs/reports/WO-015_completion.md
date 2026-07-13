# COMPLETION REPORT — WO-015 — Date 2026-07-13 — Commit 866acde227ade7a037019191256a8df408d4782b

**Work order:** WO-015 — S6 regression repair + harness PASS/FAIL integrity  
**Branch:** `cursor/wo-015-s6-harness-fd84`  
**Date:** 2026-07-13  
**Commit:** `866acde227ade7a037019191256a8df408d4782b`  
**Base:** WO-014 tip (`cursor/wo-014-ranged-combat-fd84`) — merge of WO-014 held until this greens the suite  
**Evidence:** `docs/reports/evidence_wo015/`

---

## Built

1. **Harness integrity (CRITICAL):** checks that fail set exit 1 and print `FAIL`; they never print `PASS`. Added `_record_check` + meta-assertion that green runs emit exactly `EXPECTED_GREEN_PASS_COUNT=45` PASS lines and reconcile with exit code.
2. **S6 root cause fix:** `scenario_06.gd` no longer mutates a shared profile dict when setting `skip_auto_engage` on `red_pursuer` (duplicate profile before flag).
3. Full suite green; evidence logs attached.

---

## Root-cause report (items 2–4)

### What failed
- `blue_rally` ended **marching** at strength 100 (never fought).
- `pursuit_tick_count == 0` (pursuit never had a routing unit).

### Mechanism
1. **Latent harness bug (WO-013b):** `_spawn_units` configured `red_striker` and `red_pursuer` from the **same** profile Dictionary, then set `_red_pursuer.profile["skip_auto_engage"] = true`, which also marked **`red_striker`**.
2. **Trigger (WO-014):** `sim_battle_core.try_begin_engagement` gained a **partner-side** `skip_auto_engage` continue. Actor-only skip (WO-013b) still allowed `blue_rally` to engage a polluted striker; partner skip blocks that pair entirely → no combat → no rout → no pursuit.

### Pre-existed or introduced?
| Baseline | S6 |
|----------|-----|
| WO-009 / main (pre-`skip_auto_engage`) | PASS historically; different engagement path |
| WO-013b (actor-only skip + shared-dict latent) | **PASS** (latent harmless) |
| WO-014+ (partner skip + shared dict) | **FAIL** until this WO |

**Verdict:** Latent shared-dict bug from WO-013b S6 harness; made fatal by WO-014 partner `skip_auto_engage`. Pursuit formulas/`k_ranged_scale` are not at fault. Partner skip retained (required for S16 static targets).

### Fix
```gdscript
var pursuer_profile: Dictionary = striker_profile.duplicate(true)
pursuer_profile["skip_auto_engage"] = true
# configure red_pursuer with pursuer_profile (striker keeps clean profile)
```

### After fix (this suite)
`S6 PASS rally=removed pursuit_ticks=243 strength=0.00`

---

## Harness audit (print vs exit)

- All scenario checks route through `_record_check(tag, ok, detail)`.
- Failures: `push_error` + `FAIL` line + `_exit_code = 1`; **no PASS**.
- Successes: `PASS` only.
- `_reconcile_and_quit()`: exit 0 ⇒ FAIL=0 and PASS==45; exit ≠0 ⇒ FAIL>0.

---

## Execution evidence (this commit)

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/all_scenes_smoke_test.gd
# SMOKE_EXIT=0 — [SceneSmoke] PASS 22 scenes

$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# SUITE_EXIT=0
# [WO-010] S6 PASS rally=removed pursuit_ticks=243 strength=0.00
# [WO-015] Meta PASS=45 FAIL=0 expected_green_pass=45 exit=0
```

---

## Suite summary (exit 0)

| Gate | Result |
|------|--------|
| Smoke | PASS 22 |
| Compass / Fast cert / Threaded cert | PASS |
| Determinism / Overlap | PASS |
| S1 × 11 / S2 × 11 | PASS |
| S3 / S4 / S5 / **S6** / S7 / S8 | PASS |
| S9 × 11 / S10 / S11 | PASS |
| S12–S16 | PASS |
| Meta PASS/FAIL reconcile | PASS 45/0 exit 0 |

---

## Files changed

- `scripts/scenario_06.gd` — duplicate profile before `skip_auto_engage`
- `tests/scenario_wo010_autotest.gd` — gated PASS/FAIL + meta-assertion
- `docs/reports/WO-015_completion.md` — this report
- `docs/reports/INDEX.md` — link
- `docs/reports/evidence_wo015/` — live logs

## Assumptions made

NONE

## Known issues

None for this WO. WO-014 merge remains held until TD merges this green suite (per TD HOLD).

---

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-015-s6-harness-fd84/docs/reports/WO-015_completion.md
- Index: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-015-s6-harness-fd84/docs/reports/INDEX.md
- Previous (WO-014b): https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-014-ranged-combat-fd84/docs/reports/WO-014b_completion.md
- Suite log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-015-s6-harness-fd84/docs/reports/evidence_wo015/suite_stdout.log
- Smoke log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-015-s6-harness-fd84/docs/reports/evidence_wo015/smoke_stdout.log
