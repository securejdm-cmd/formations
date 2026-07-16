# WO-027 quality_of_day measurable sweep

Seeds: **1000–1499** (n=500). Flat; gait 1.0; defender push=50; march-vs-hold.

SE = 100×√(p(1−p)/n) percentage points.

Mode: `SIGMA`

## sigma = 0.040

| Edge | Atk push | Win% | SE | Rule |
|---:|---:|---:|---:|:---|
| 0% | 50.0 | 50.80 | 2.24 | PASS |
| 2% | 51.0 | 59.80 | 2.19 | PASS |
| 3% | 51.5 | 65.60 | 2.12 | PASS |
| 5% | 52.5 | 74.00 | 1.96 | PASS |
| 10% | 55.0 | 88.60 | 1.42 | PASS |
| 20% | 60.0 | 99.20 | 0.40 | FAIL |
| 50% | 75.0 | 100.00 | 0.00 | PASS |

**Rule set (6 edges): FAIL** · **Monotonicity: PASS**

## NO SIGMA SATISFIES ALL SIX + MONOTONICITY — ESCALATE
