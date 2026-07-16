# WO-027 quality_of_day measurable sweep

Seeds: **1000–1499** (n=500). Flat; gait 1.0; defender push=50; march-vs-hold.

SE = 100×√(p(1−p)/n) percentage points.

Mode: `SIGMA`

## sigma = 0.055

| Edge | Atk push | Win% | SE | Rule |
|---:|---:|---:|---:|:---|
| 0% | 50.0 | 50.80 | 2.24 | PASS |
| 2% | 51.0 | 58.00 | 2.21 | PASS |
| 3% | 51.5 | 61.00 | 2.18 | PASS |
| 5% | 52.5 | 68.20 | 2.08 | PASS |
| 10% | 55.0 | 81.40 | 1.74 | PASS |
| 20% | 60.0 | 94.20 | 1.05 | PASS |
| 50% | 75.0 | 98.60 | 0.53 | PASS |

**Rule set (6 edges): PASS** · **Monotonicity: PASS**

## SELECTED sigma = 0.055

Meets all six R21 bands + monotonicity.
