# ESCALATION REPORT — WO-027 Task 4 (R21 boundary under committed σ)

**Work order:** WO-027  
**Branch:** `cursor/wo-027-qod-measurable-fd84`  
**Date:** 2026-07-16  
**Committed σ (Task 2):** `0.045` (curve + monotonicity PASS at n=500)

---

## Assumptions made

NONE.

---

## Trigger

Task 4: with committed σ **ENABLED**, re-verify R21 maneuver boundary. Any maneuver outcome a QoD roll can flip is an R21 FAILURE.

---

## Finding — S3 flank ratio band

With `quality_of_day_enabled=true`, `sigma=0.045`, seeds 1000–1004:

| Seed | QoD off ratio | QoD on ratio | Band [0.28,0.45] |
|-----:|-------------:|-------------:|:-----------------|
| 1000 | 0.282 | **0.263** | FAIL |
| 1001 | 0.282 | **0.268** | FAIL |
| 1002 | 0.284 | 0.285 | PASS |
| 1003 | 0.284 | 0.298 | PASS |
| 1004 | 0.284 | **0.276** | FAIL |

- Flank **winner** remains `red_b` (decisive). Ratio stays ≪ 1.0.
- Numeric S3 HOLD band (WO-025 gravity rebaseline) is violated on 3/5 seeds by QoD rolls.
- Same pattern at σ∈{0.04, 0.05} — not unique to 0.045.
- QoD **off** still matches WO-025 S3 metrics (0.282 / rout 76.13 / LEFT 58.68).

Evidence: `docs/reports/evidence_wo027/boundary_focus.log`, `s3_sigma_grid.log`.

---

## Finding — S34 pinning (seed 1000)

| Config | flank_persist | no_reface |
|--------|:-------------:|:---------:|
| QoD off | true | true |
| QoD on σ=0.045 | **false** | true |

Note: WO-025 boundary probe at σ=0.05 also logged `flank_persist=false` on seed 1000 while the completion report claimed HOLD — soft/under-specified check. Seeds 1001–1004 pin with QoD on.

---

## What still HOLDS with σ=0.045 enabled (seed 1000)

S18 braced spears, S19 late brace, S21 flank charge, S23–S26 winners, S36 downhill — qualitative maneuver winners unchanged (`boundary_probe.log`).

---

## Disposition

| Item | Status |
|------|--------|
| Task 2 σ selection | **COMMIT 0.045** (also 0.050, 0.055 PASS) |
| `quality_of_day_sigma` | **0.045** in constants |
| `quality_of_day_enabled` default | **false** until TD rules on S3 band under QoD |
| Task 4 boundary | **ESCALATE** — S3 numeric band not robust to QoD; S34 seed-1000 fragile |

### TD options (costed)

1. **Widen S3 ratio band** under QoD (e.g. [0.25, 0.45]) — low code cost; acknowledges paper-stat blur of grind duration while flank remains decisive.
2. **Enable QoD default true** after (1) + harden S34 multi-seed gate — medium.
3. **Supporting levers** (R21: slow wobble / rout-threshold variance) instead of wider σ — design decision; do not start without TD.
4. **Keep enabled=false** (current) — width locked for opt-in; suite/certs byte-clean.

---

## Not blocked

- Slot-order Task 3 closed (49.2%±2.2 at n=500).
- SLOT-SWAP permanent guard green.
- Suite Meta 73/0 exit 0 with enabled=false.
