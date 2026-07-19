# WO-029b Task 0 — S8 variance diagnosis (n=500)

## Direction check (Combat Core §3.7)

- Instrument: DIRECTION — `ratio = triple_dmg / single_dmg` must be `< 3.0` on every seed.
- Mean+3SD band: **removed** (magnitude informational only).
- Settings: QoD on, σ=0.045, seeds 1000–1499 (n=500).

| metric | value |
|--------|------:|
| n | 500 |
| mean | 1.702297 |
| sd | 0.800819 |
| cv | 0.4704 |
| min | 0.805779 |
| max | 3.856754 |
| **ge3 (ratio ≥ 3.0)** | **20** |

Suite seed 1000 alone: ratio ≈ 2.805 (PASS). Population ge3≠0 → see Escalation in completion report.

## Variance driver (named; not tuned)

**Frontage geometry / incomplete single-attacker engagement (bimodal), not a small-sample artifact.**

Evidence:

1. **CV stays high at n=500** (0.47) — WO-028’s ~40% CV at n=10 (seeds 1000–1009: cv≈0.40) was not a small-n illusion.
2. **Bimodal `single_dmg`:**
   - low cluster (`single_dmg` < 30): n=246, ratio mean≈2.455, **all 20 ge3 hits**
   - high cluster (`single_dmg` ≥ 30): n=254, ratio mean≈0.973, ge3=0
3. Triple damage is stable (cv≈0.12); single damage is volatile (cv≈0.36). High ratios are **denominator collapses** when the lone attacker gets a short/edge/partial front contact while the triple still fills the FRONT edge.
4. Linear `corr(ratio, single_dmg)` ≈ 0 overall because of the two regimes — the structure is geometric, not a smooth QoD scale effect.

Not primary drivers: adhesion timing (combat times co-vary with the same engagement regimes); engagement order alone does not explain the bimodal single_dmg split without frontage fill.

**No balance tuning applied** (WO-029b Task 0).
