# WO-027 quality_of_day measurable sweep

Seeds: **1000–1499** (n=500). Flat; gait 1.0; defender push=50; march-vs-hold.

SE = 100×√(p(1−p)/n) percentage points.

Mode: `SIGMA`

## sigma = 0.080

| Edge | Atk push | Win% | SE | Rule |
|---:|---:|---:|---:|:---|
| 0% | 50.0 | 50.80 | 2.24 | PASS |
| 2% | 51.0 | 55.80 | 2.22 | PASS |
| 3% | 51.5 | 58.40 | 2.20 | PASS |
| 5% | 52.5 | 61.80 | 2.17 | FAIL |
| 10% | 55.0 | 73.40 | 1.98 | FAIL |
| 20% | 60.0 | 85.00 | 1.60 | FAIL |
| 50% | 75.0 | 89.80 | 1.35 | FAIL |

**Rule set (6 edges): FAIL** · **Monotonicity: PASS**

## NO SIGMA SATISFIES ALL SIX + MONOTONICITY — ESCALATE
