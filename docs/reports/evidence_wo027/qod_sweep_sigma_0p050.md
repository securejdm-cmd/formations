# WO-027 quality_of_day measurable sweep

Seeds: **1000–1499** (n=500). Flat; gait 1.0; defender push=50; march-vs-hold.

SE = 100×√(p(1−p)/n) percentage points.

Mode: `SIGMA`

## sigma = 0.050

| Edge | Atk push | Win% | SE | Rule |
|---:|---:|---:|---:|:---|
| 0% | 50.0 | 50.80 | 2.24 | PASS |
| 2% | 51.0 | 58.80 | 2.20 | PASS |
| 3% | 51.5 | 62.00 | 2.17 | PASS |
| 5% | 52.5 | 70.60 | 2.04 | PASS |
| 10% | 55.0 | 82.60 | 1.70 | PASS |
| 20% | 60.0 | 95.80 | 0.90 | PASS |
| 50% | 75.0 | 99.00 | 0.44 | PASS |

**Rule set (6 edges): PASS** · **Monotonicity: PASS**

## SELECTED sigma = 0.050

Meets all six R21 bands + monotonicity.
