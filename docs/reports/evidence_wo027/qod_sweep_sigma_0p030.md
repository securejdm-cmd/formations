# WO-027 quality_of_day measurable sweep

Seeds: **1000–1499** (n=500). Flat; gait 1.0; defender push=50; march-vs-hold.

SE = 100×√(p(1−p)/n) percentage points.

Mode: `SIGMA`

## sigma = 0.030

| Edge | Atk push | Win% | SE | Rule |
|---:|---:|---:|---:|:---|
| 0% | 50.0 | 50.40 | 2.24 | PASS |
| 2% | 51.0 | 63.60 | 2.15 | PASS |
| 3% | 51.5 | 70.60 | 2.04 | FAIL |
| 5% | 52.5 | 80.00 | 1.79 | FAIL |
| 10% | 55.0 | 95.00 | 0.97 | FAIL |
| 20% | 60.0 | 100.00 | 0.00 | FAIL |
| 50% | 75.0 | 100.00 | 0.00 | PASS |

**Rule set (6 edges): FAIL** · **Monotonicity: PASS**

## NO SIGMA SATISFIES ALL SIX + MONOTONICITY — ESCALATE
