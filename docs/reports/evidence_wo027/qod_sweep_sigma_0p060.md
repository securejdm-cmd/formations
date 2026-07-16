# WO-027 quality_of_day measurable sweep

Seeds: **1000–1499** (n=500). Flat; gait 1.0; defender push=50; march-vs-hold.

SE = 100×√(p(1−p)/n) percentage points.

Mode: `SIGMA`

## sigma = 0.060

| Edge | Atk push | Win% | SE | Rule |
|---:|---:|---:|---:|:---|
| 0% | 50.0 | 50.80 | 2.24 | PASS |
| 2% | 51.0 | 57.20 | 2.21 | PASS |
| 3% | 51.5 | 59.80 | 2.19 | PASS |
| 5% | 52.5 | 66.60 | 2.11 | PASS |
| 10% | 55.0 | 79.20 | 1.82 | PASS |
| 20% | 60.0 | 91.80 | 1.23 | PASS |
| 50% | 75.0 | 96.40 | 0.83 | FAIL |

**Rule set (6 edges): FAIL** · **Monotonicity: PASS**

## NO SIGMA SATISFIES ALL SIX + MONOTONICITY — ESCALATE
