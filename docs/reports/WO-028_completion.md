# COMPLETION REPORT — WO-028 — 2026-07-16 — Commit 8e80bd4964566c6854aef0522f4041b03de8fce6

**Work order:** WO-028 Boundary vs Band: Closing Phase 2's Simulation  
**Branch:** `cursor/wo-028-boundary-vs-band-fd84`  
**Tip SHA:** `8e80bd4964566c6854aef0522f4041b03de8fce6`  
**Base:** WO-027 tip `9e31142` (`cursor/wo-027-qod-measurable-fd84`)  
**Evidence:** `docs/reports/evidence_wo028/`  
**Design authority:** DESIGN_RULINGS R21

---

## Assumptions made

NONE.

---

## Known issues

NONE.

---

## WO-026 report (TD request)

GAMEPLAY_TICK **46.285 → 29.184** (WO-026 suite/profile) was caused by march enemy query always using `charge_commit_range_m` (~150 m) for all marchers, plus uncached max scans and double `enemies_for`. Fix scoped commit radius to `charge_gait_mult > 1`, cached max closing/dim per tick, one `enemies_for` per unit. Movement ~25.7 → ~9.3 ms.

Full report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-026-movement-diagnostic-fd84/docs/reports/WO-026_completion.md

This WO’s suite GAMEPLAY_TICK p95 = **27.058** ms (post-WO-026 path, QoD on).

---

## Governance

Appended permanent separation to `.cursor/rules/governance.mdc`:

| Type | Asserts | Waivable? |
|------|---------|-----------|
| **(a) R21 BOUNDARY** | DIRECTION — who wins, edge class, counter still counters, pin/reface | **Never** |
| **(b) REGRESSION BANDS** | MAGNITUDE — must be derived under the config they guard | Re-derive from data; never widen by judgement |

Never list a numeric magnitude band as a boundary check again.

---

## Task 1 — S34 pinning under QoD

**Verdict: (b) CLASSIFICATION DRIFT** — not (a) un-pinning.

| Evidence | QoD off (seed 1000) | QoD on (seed 1000) |
|----------|---------------------|--------------------|
| Facing angle | 180° locked | 180° locked |
| Max turn | 0.00° | 0.00° |
| Max facing·to_flanker | ~0 | ~0 |
| Soft `leftish≥15` | true | true on 1000; **false on 1004** |
| Mean morale mult | 1.425 | 1.293–1.500 |
| Hard pin (no reface + mean_mult>1) | PASS | PASS all 1000–1009 |

Soft LEFT-label count flickered when contact sat on a LEFT/FRONT corner; defender never refaced; morale mult stayed >1. Soft check that can log false while a report says HOLD is removed.

**Hardened assert (seeds 1000–1009):**
- defender facing does not rotate toward flanker (`max_dot < 0.5`, turn < 5°)
- engagement mean flank mult > 1.0 and ≥50% of samples > 1.0

---

## Task 2 — S3 bands re-derived (QoD on, σ=0.045, n=500)

Rule chosen: **mean ± 3SD** (covers full observed support; preferred over 0.5/99.5 pct for permanent instrument width).

| Metric | mean | SD | min | max | p01 | p99 | band (mean±3SD) |
|--------|------|-----|-----|-----|-----|-----|-----------------|
| ratio (vs QoD-off S1 75.8s) | 0.284124 | 0.011235 | 0.254617 | 0.313984 | 0.262533 | 0.308720 | **[0.250, 0.318]** |
| strength_at_rout | 76.298 | 0.494 | 75.095 | 77.567 | 75.232 | 77.367 | **[74.82, 77.78]** |
| LEFT drain | 59.123 | 3.224 | 50.719 | 67.014 | 52.146 | 66.025 | **[49.45, 68.80]** |

Flank wins: **500/500**. Provenance: `evidence_wo028/s3_rederive_merged_summary.txt`.

### Other magnitude bands QoD perturbed (same treatment)

| Check | Old | New (derived) | n / config |
|-------|-----|---------------|------------|
| S8 blob ratio max | 2.0 | **4.36** (mean+3SD) | n=10 seeds 1000–1009; mean=1.984 sd=0.793 |
| S30 sk_lost | ≤6.0 | **[3.86, 5.36]** | n=500; mean=4.608 sd=0.251 |
| S30 sp_lost | ≥6.0 | **[4.64, 7.42]** | n=500; mean=6.029 sd=0.462 |
| S10 chip expectation | raw without QoD | includes `quality_of_day` | formula match to CombatResolver |

---

## Task 3 — R21 boundary as DIRECTION checks

QoD on σ=0.045, seeds **1000–1009**, every seed:

| Check | Result |
|-------|--------|
| S3 flank wins; ratio ≪ 1 | **10/10** |
| S34 hardened pin | **10/10** |
| S18 braced spears stop cav | **10/10** |
| S19 late brace fails | **10/10** |
| S21 flank routs fresh | **10/10** |
| S21 rear routs fresh | **10/10** |
| S23 T1 holds / S24–S26 T3 breaks | **10/10** |
| S36–S39 downhill/high-ground direction | **10/10** |

`fails=0` — `evidence_wo028/r21_direction.log`. No R21 escalation.

---

## Task 4 — Enable

| Item | Value |
|------|-------|
| `quality_of_day_enabled` | **true** |
| `quality_of_day_sigma` | **0.045** |
| QoD-off A/B no-op | combat=81.6 winner=blue_1 identical=true (`qod_off_noop.log`) |
| S1/S2 | Rebaselined under QoD-on |
| Bugfix | QoD rolled via stale static `SimRngBridge._worker_rng` → cert/determinism desync; now rolls from `SimBattleCore._rng` directly |

### Final R21 curve at committed σ=0.045 (n=500)

From WO-027 measurable sweep (same σ, retained in `evidence_wo028/r21_curve_sigma_0p045.md`):

| Edge | Win% ± SE | Rule |
|------|-----------|------|
| 0% | 50.60 ± 2.24 | PASS |
| 2% | 59.20 ± 2.20 | (informational) |
| 3% | 63.00 ± 2.16 | PASS |
| 5% | 72.80 ± 1.99 | PASS |
| 10% | 86.00 ± 1.55 | PASS |
| 20% | 97.80 ± 0.66 | PASS |
| 50% | 99.60 ± 0.28 | PASS |

Monotonicity PASS. Slot-order QoD-off 0%: 49.20 ± 2.24 (WO-027).

---

## Task 5 — Regression

| Gate | Result |
|------|--------|
| Fast + threaded certs | byte-identical **PASS** |
| Determinism A/B | **PASS** |
| SLOT-SWAP | **PASS** (sidecar capture) |
| S12 | **18 volleys / 8.04%** PASS |
| Charge spectrum R15/R16 | direction + re-derived bands PASS |
| Suite meta | **73/0 exit 0** |
| GAMEPLAY_TICK p95 | **27.058** ms PASS |

```
/tmp/godot/Godot_v4.4.1-stable_linux.x86_64 --headless --path . --script res://tests/scenario_wo010_autotest.gd
→ [WO-015] Meta PASS=73 FAIL=0 expected_green_pass=73 exit=0
```

---

## Files changed

- `.cursor/rules/governance.mdc` — boundary vs band separation
- `data/combat_constants.json` — `quality_of_day_enabled: true`
- `scripts/scenario_34.gd` — hardened pin metrics
- `scripts/sim/sim_battle_core.gd` — QoD from core `_rng`; clear stale bridge
- `scripts/scenario_01.gd` / `scenario_03.gd` — bridge clear; suppress_io on S3 I/O
- `tests/scenario_wo010_autotest.gd` — S3/S8/S10/S30 bands; S34; SLOT-SWAP sidecar
- `tests/wo027_slot_swap.gd` — sidecar for suite capture
- `tests/wo028_*.gd`, `docs/reports/evidence_wo028/`, this report

---

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-028-boundary-vs-band-fd84/docs/reports/WO-028_completion.md
- Previous (WO-027): https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-027-qod-measurable-fd84/docs/reports/WO-027_completion.md
- WO-026 (TD): https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-026-movement-diagnostic-fd84/docs/reports/WO-026_completion.md
- Suite log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-028-boundary-vs-band-fd84/docs/reports/evidence_wo028/suite_stdout.log
