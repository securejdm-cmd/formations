# WO-025 Task 3 — 0% cell anomaly diagnosis

## Observation (WO-024)

Equal push (50 vs 50), gait 1.0, march-vs-hold protocol → **63.6% attacker win** over 11 seeds. Raising wobble ±5%→±15% moved win% by **0.0**.

## Hypotheses tested

| Setup | Atk win% (11 seeds) | Same winners/combat as march-vs-hold? |
|-------|--------------------:|----------------------------------------|
| march vs hold (WO-024 protocol) | **63.6** | — |
| hold vs march (roles swapped) | **63.6** | **YES — identical seed→winner map** |
| march vs march | **63.6** | **YES — identical** |
| hold vs hold | 0.0 (no contact) | n/a |

Contact speeds differ across postures (`1.5/0` vs `0/1.5` vs `1.5/1.5`); `charge_amp` is 1.0 everywhere (gait 1.0). **Posture does not change outcomes.**

## Mechanism

The bias is **not** “marcher vs standing.” It is a **slot / RNG-call-order bias** on the battle-seeded stream (WO-007 / `SIMULATION_SYMMETRY.md`): units are stored `[attacker, defender]`; each tick the attacker draws push-wobble first. Over ~500 combat ticks that ordered noise has a **persistent non-zero mean per seed×slot**, so the first unit wins ~7/11 seeds. Zero-mean amplitude changes (±15%) do not flip the order structure — matching the WO-024 null result.

Evidence: `docs/reports/evidence_wo025/anomaly_diag.log`.

## Implication for R21

`quality_of_day` must overcome this structured bias by giving each unit a **true persistent multiplicative edge** independent of draw order. The 0% cell with QoD on must land at **50% ± 10** over 33 seeds without widening σ just to swamp the anomaly (selection rule).
