# WO-027 quality_of_day measurable sweep

Seeds: **1000–1499** (n=500). Flat; gait 1.0; defender push=50; march-vs-hold.

SE = 100×√(p(1−p)/n) percentage points.

Mode: `SIGMA`

## sigma = 0.070

| Edge | Atk push | Win% | SE | Rule |
|---:|---:|---:|---:|:---|
| 0% | 50.0 | 51.00 | 2.24 | PASS |
| 2% | 51.0 | 56.00 | 2.22 | PASS |
| 3% | 51.5 | 59.00 | 2.20 | PASS |
| 5% | 52.5 | 63.80 | 2.15 | PASS |
| 10% | 55.0 | 74.60 | 1.95 | FAIL |
| 20% | 60.0 | 87.80 | 1.46 | FAIL |
| 50% | 75.0 | 93.80 | 1.08 | FAIL |

**Rule set (6 edges): FAIL** · **Monotonicity: PASS**

## NO SIGMA SATISFIES ALL SIX + MONOTONICITY — ESCALATE
