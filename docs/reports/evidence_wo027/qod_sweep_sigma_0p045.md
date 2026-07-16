# WO-027 quality_of_day measurable sweep

Seeds: **1000–1499** (n=500). Flat; gait 1.0; defender push=50; march-vs-hold.

SE = 100×√(p(1−p)/n) percentage points.

Mode: `SIGMA`

## sigma = 0.045

| Edge | Atk push | Win% | SE | Rule |
|---:|---:|---:|---:|:---|
| 0% | 50.0 | 50.60 | 2.24 | PASS |
| 2% | 51.0 | 59.20 | 2.20 | PASS |
| 3% | 51.5 | 63.00 | 2.16 | PASS |
| 5% | 52.5 | 72.80 | 1.99 | PASS |
| 10% | 55.0 | 86.00 | 1.55 | PASS |
| 20% | 60.0 | 97.80 | 0.66 | PASS |
| 50% | 75.0 | 99.60 | 0.28 | PASS |

**Rule set (6 edges): PASS** · **Monotonicity: PASS**

## SELECTED sigma = 0.045

Meets all six R21 bands + monotonicity.
