# COMPLETION REPORT — WO-027 — 2026-07-16 — Commit 3c380136c92f13feee108b3b42935ba872c65d3a

**Work order:** WO-027 Quality of the Day: Measurable Sweep  
**Branch:** `cursor/wo-027-qod-measurable-fd84`  
**Tip SHA:** `3c380136c92f13feee108b3b42935ba872c65d3a`  
**Base:** WO-026 tip `57a54ed` (`cursor/wo-026-movement-diagnostic-fd84`)  
**Evidence:** `docs/reports/evidence_wo027/`  
**Escalation:** `docs/reports/WO-027_escalation.md` (Task 4 — S3 band under QoD)

---

## Assumptions made

NONE.

---

## Known issues

Task 4: with σ=0.045 **enabled**, S3 flank ratio exits [0.28,0.45] on some seeds (flank still wins). Default remains **disabled** pending TD. See escalation.

---

## Task 1 — Sample size

| Item | Value |
|------|-------|
| Seeds | **1000–1499** |
| n | **500** / cell |
| SE | √(p(1−p)/n) as percentage points, reported per cell |
| Wall-clock | ~31 min/σ; 4-wide parallel batches ≈ **90 min** total — n not reduced |

---

## Task 2 — Focused σ sweep + selection

σ ∈ {0.03, 0.04, 0.045, 0.05, 0.055, 0.06, 0.07, 0.08, 0.09}.  
Monotonicity: non-decreasing on rule edges within 2-SE tolerance — **all σ PASS mono**.

| Result | σ |
|--------|---|
| **SELECTED** | **0.045** (first ascending PASS) |
| Also PASS | 0.050, 0.055 |
| FAIL (steep) | 0.03; 0.04 (20%=99.2>98) |
| FAIL (flat) | 0.06 (50%=96.4); 0.07–0.09 |

Committed: `quality_of_day_sigma = 0.045`. Full table: `qod_sweep.md`.

---

## Task 3 — Slot-order

| Check | Result |
|-------|--------|
| 0% edge, QoD **disabled**, n=500 | **49.20% ± 2.24 SE** ∈ 50±5 → **fair** |
| WO-025 63.6% @ n=33 | Closed as sampling noise |
| Permanent SLOT-SWAP | Suite gate `[WO-027] SLOT-SWAP` — winner swaps; combat_sec + winner str/coh mirror |

---

## Task 4 — Boundary + regression

| Item | Result |
|------|--------|
| σ enabled boundary | S18/S19/S21/S23–S26/S36 HOLD qualitatively; **S3 band FAIL** some seeds → **ESCALATE** |
| `quality_of_day_enabled` default | **false** — width locked; enable after TD clears S3 band (R21 must not flip maneuver gates) |
| Disabled A/B | Default off = WO-026 no-op path; certs byte-identical |
| Suite | Meta **73/0 exit 0** (SLOT-SWAP added) |
| GAMEPLAY_TICK | p95 **29.184** ms PASS |

---

## Files changed

- `data/combat_constants.json` — sigma **0.045** (enabled false)
- `scripts/scenario_01.gd` — `suppress_io`
- `scripts/rng_service.gd` — quiet seed print for bulk
- `tests/wo027_qod_sweep.gd`, `wo027_slot_swap.gd`, `wo027_boundary_probe.gd`
- `tests/scenario_wo010_autotest.gd` — SLOT-SWAP gate; meta 73
- `docs/reports/evidence_wo027/`, `WO-027_completion.md`, `WO-027_escalation.md`
