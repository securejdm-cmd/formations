# COMPLETION REPORT — WO-038 Facing Readout + Invariant Visibility

- **Work order:** WO-038 — Facing readout fix, facing-length census, silent-invariant explanation
- **Built:** Correct Facing debug interpolation; per-tick `facing.length()` census on UI/integrity path; DEBUG realtime OBB asserts (was gated off by WO-024); OBB assert uses independent `FormationGeometry.get_corners` geometry.
- **Files changed:** `docs/work_orders/WORK_ORDER_038.md`; this report + `docs/reports/evidence_wo038/*`; `scripts/scenario_debug_overlay.gd`; `scripts/sim/sim_battle_core.gd`; `scripts/scenario_from_data.gd`; `tests/wo038_facing_readout_diag.gd`; `tests/wo038_readout_visual.gd`
- **Tests:** See acceptance table below
- **Assumptions made:** NONE
- **Known issues:** Unnormalized-facing hypothesis is **FALSIFIED**; designer MARCHING+interpenetration needs a new diagnosis (not patched here)

---

## (1) FIX THE READOUT — PASS

**Bug:** nested format `"Facing: %(%.3f, %.3f) |len|=%.4f"` — GDScript treats `%( ` as named-format start → prints the literal string (confirmed: historic sample still shows `Facing: %(%.3f, %.3f) |len|=%.4f`).

**Fix:** single format `"Facing: (%.3f, %.3f) |len|=%.4f" % [f.x, f.y, f.length()]`.

**Verified in running build** (`DISPLAY=:99`, OpenGL/llvmpipe):

```
Facing: (-0.876, 0.482) |len|=1.0000
```

Screenshot: `docs/reports/evidence_wo038/wo038_facing_readout.png`

---

## (2) FACING.LENGTH CENSUS — UNNORMALIZED HYPOTHESIS FALSIFIED

UI-path rotating charge (S56, `fast_sim=false`, `debug_facing_len_log=true`, charge→engage→wheel, seed 1000):

| Metric | Value |
|---|---|
| samples | 5000 (2 units × 2500 ticks) |
| min magnitude | **0.99999994** |
| max magnitude | **1.00000000** |
| first tick `\|len-1\| > 1e-4` | **none** (`first_dev_tick=-1`) |
| engaged / wheeled | true / true |

**Verdict: UNNORMALIZED-FACING HYPOTHESIS FALSIFIED.** Magnitudes are clean through angled contact and rotate-while-engaged. Do not continue patching facing-normalization as the cause of designer MARCHING+interpenetration.

Artifact: `docs/reports/evidence_wo038/wo038_facing_census.txt`

---

## (3) SILENT INVARIANTS — ANSWER (a)

**Which is true: (a).**

`SimBattleCore.overlap_assert_enabled()` was `headless_mode and fast_sim_mode` only (WO-024). UI battles use `fast_sim=false`, so **nothing checked** while `scenario_from_data.gd` still printed `overlap_fail=false` / `coherence_fail=false` from sticky flags that never get set. Not (b): the assert was not running, so it could not "agree with the bug."

**Fix applied:**

1. Gate opens when `debug_integrity_checks` **or** (`OS.is_debug_build() and not headless`) **or** classic headless+fast.
2. UI integrity watch (`ScenarioFromData.ui_integrity_watch`) sets `debug_integrity_checks` + `debug_facing_len_log` and prints facing min/max on the FPS strip.
3. `assert_no_overlaps` now audits via **independent** geometry: `FormationGeometry.rectangles_overlap` → `get_corners(pos, facing, extents)` / OBB SAT — **not** `CombatResolver.units_overlap` / `could_have_contact` / edge-slab paths. Partnered / `auto_engage_locked` enemy merge remains a non-defect (WO-036); routing has no volume.

---

## (4) WO-037 PRESENCE + RE-DIAGNOSIS

| Item | Value |
|---|---|
| This branch | `cursor/wo-038-facing-readout-fd84` |
| This tip (pre-report commit may bump) | stacked on WO-037 |
| WO-037 tip included | **`94f17d6`** — `WO-037: completion report suite attestation PASS=92` |
| Normalize-on-write / S56 smoke | **present** in this build (ancestor commits `7718bae`, `cf52b12`) |
| Designer build | Must include WO-037 (`94f17d6`+) **and** this WO-038 readout fix to see magnitudes; prior panel showed a **literal format string**, not a real vector |

**Re-diagnosis (no further code patches — per directive):**

1. Unnormalized facing is **out** as the explanation for OBB miss / MARCHING-while-merged.
2. Realtime `overlap_fail=false` was **instrumentation blindness** (assert off), not proof of geometric cleanliness.
3. Remaining live symptom (designer: `blue_cav_1` MARCHING while visually interpenetrating, many kills dealt / ~0 taken) points elsewhere — candidates for a **new** WO, not silent continuation:
   - contact / engage not partnering despite OBB merge (state stays MARCHING while damage somehow accrues);
   - render footprint vs sim proxy desync on the UI thread;
   - defect exemptions (`auto_engage_locked` / partnership) masking overlap once contact flickers;
   - kill accounting / combat path without sustained contact partnership.

---

## Acceptance

| Criterion | Result |
|---|---|
| Facing readout correct (verified) | **PASS** — running-build panel `|len|=1.0000` |
| Facing-length min/max; hypothesis | **PASS** — min≈1 max=1; **FALSIFIED** |
| Silent-invariant explanation + DEBUG OBB | **PASS** — **(a)**; gate + independent OBB |
| WO-037 presence + re-diagnosis | **PASS** — present at `94f17d6`; re-diagnose above |
| Assumptions | **NONE** |

## How to re-run

```bash
godot --headless -s res://tests/wo038_facing_readout_diag.gd
DISPLAY=:99 godot -s res://tests/wo038_readout_visual.gd
```

## Attestation

- Branch: `cursor/wo-038-facing-readout-fd84`
- Base: `cursor/wo-037-facing-normalize-fd84` @ `94f17d6`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-038-facing-readout-fd84/docs/reports/WO-038_completion.md
- Diag log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-038-facing-readout-fd84/docs/reports/evidence_wo038/wo038_diag.log
- Visual log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-038-facing-readout-fd84/docs/reports/evidence_wo038/wo038_visual.log
