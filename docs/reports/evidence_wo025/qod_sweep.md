# WO-025 quality_of_day sigma sweep

Seeds: **1000–1032** (n=33). Flat; gait 1.0; defender push=50; march-vs-hold.

Distribution: Gaussian N(1, σ) via Box-Muller on battle RNG stream.

## sigma = 0.02

| Edge | Atk push | Win% | Rule |
|---:|---:|---:|:---|
| 0% | 50.0 | 48.5 | PASS |
| 2% | 51.0 | 63.6 | PASS |
| 3% | 51.5 | 93.9 | FAIL |
| 5% | 52.5 | 84.8 | FAIL |
| 10% | 55.0 | 97.0 | FAIL |
| 20% | 60.0 | 100.0 | FAIL |
| 50% | 75.0 | 100.0 | PASS |

**Rule set (6 edges): FAIL**

## sigma = 0.03

| Edge | Atk push | Win% | Rule |
|---:|---:|---:|:---|
| 0% | 50.0 | 51.5 | PASS |
| 2% | 51.0 | 60.6 | PASS |
| 3% | 51.5 | 66.7 | PASS |
| 5% | 52.5 | 78.8 | FAIL |
| 10% | 55.0 | 90.9 | FAIL |
| 20% | 60.0 | 100.0 | FAIL |
| 50% | 75.0 | 100.0 | PASS |

**Rule set (6 edges): FAIL**

## sigma = 0.04

| Edge | Atk push | Win% | Rule |
|---:|---:|---:|:---|
| 0% | 50.0 | 42.4 | PASS |
| 2% | 51.0 | 54.5 | PASS |
| 3% | 51.5 | 66.7 | PASS |
| 5% | 52.5 | 75.8 | FAIL |
| 10% | 55.0 | 87.9 | PASS |
| 20% | 60.0 | 100.0 | FAIL |
| 50% | 75.0 | 97.0 | FAIL |

**Rule set (6 edges): FAIL**

## sigma = 0.05

| Edge | Atk push | Win% | Rule |
|---:|---:|---:|:---|
| 0% | 50.0 | 45.5 | PASS |
| 2% | 51.0 | 60.6 | PASS |
| 3% | 51.5 | 69.7 | FAIL |
| 5% | 52.5 | 72.7 | PASS |
| 10% | 55.0 | 93.9 | FAIL |
| 20% | 60.0 | 100.0 | FAIL |
| 50% | 75.0 | 100.0 | PASS |

**Rule set (6 edges): FAIL**

## sigma = 0.06

| Edge | Atk push | Win% | Rule |
|---:|---:|---:|:---|
| 0% | 50.0 | 36.4 | FAIL |
| 2% | 51.0 | 48.5 | PASS |
| 3% | 51.5 | 60.6 | PASS |
| 5% | 52.5 | 54.5 | FAIL |
| 10% | 55.0 | 72.7 | FAIL |
| 20% | 60.0 | 93.9 | PASS |
| 50% | 75.0 | 90.9 | FAIL |

**Rule set (6 edges): FAIL**

## sigma = 0.08

| Edge | Atk push | Win% | Rule |
|---:|---:|---:|:---|
| 0% | 50.0 | 51.5 | PASS |
| 2% | 51.0 | 63.6 | PASS |
| 3% | 51.5 | 60.6 | PASS |
| 5% | 52.5 | 66.7 | PASS |
| 10% | 55.0 | 69.7 | FAIL |
| 20% | 60.0 | 84.8 | FAIL |
| 50% | 75.0 | 100.0 | PASS |

**Rule set (6 edges): FAIL**

## sigma = 0.10

| Edge | Atk push | Win% | Rule |
|---:|---:|---:|:---|
| 0% | 50.0 | 48.5 | PASS |
| 2% | 51.0 | 63.6 | PASS |
| 3% | 51.5 | 60.6 | PASS |
| 5% | 52.5 | 60.6 | FAIL |
| 10% | 55.0 | 81.8 | PASS |
| 20% | 60.0 | 72.7 | FAIL |
| 50% | 75.0 | 84.8 | FAIL |

**Rule set (6 edges): FAIL**

## sigma = 0.12

| Edge | Atk push | Win% | Rule |
|---:|---:|---:|:---|
| 0% | 50.0 | 57.6 | PASS |
| 2% | 51.0 | 51.5 | PASS |
| 3% | 51.5 | 69.7 | FAIL |
| 5% | 52.5 | 51.5 | FAIL |
| 10% | 55.0 | 63.6 | FAIL |
| 20% | 60.0 | 75.8 | FAIL |
| 50% | 75.0 | 78.8 | FAIL |

**Rule set (6 edges): FAIL**

## sigma = 0.15

| Edge | Atk push | Win% | Rule |
|---:|---:|---:|:---|
| 0% | 50.0 | 54.5 | PASS |
| 2% | 51.0 | 63.6 | PASS |
| 3% | 51.5 | 57.6 | PASS |
| 5% | 52.5 | 63.6 | PASS |
| 10% | 55.0 | 69.7 | FAIL |
| 20% | 60.0 | 72.7 | FAIL |
| 50% | 75.0 | 75.8 | FAIL |

**Rule set (6 edges): FAIL**

## enabled=false baseline (0% edge)

Win% = **63.6** (expect ~63.6 marcher bias)

## NO SIGMA SATISFIES ALL SIX — ESCALATE
