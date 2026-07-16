# S3 flank-benchmark confirmation — WO-025 (pre-R21, working gravity)

**Date:** 2026-07-16  
**Base:** WO-024 tip (surface-gap gravity)  
**Purpose:** TD conditional ratification of WO-024 S3 A/B escalation — confirm flank metrics before quality_of_day lands.

## Seed 1000 (canonical suite S3)

| Metric | Required | Measured | Verdict |
|--------|----------|---------:|---------|
| combat_sec / S1_1000 (75.8s) | ∈ [0.28, 0.45] | **0.282** (21.40s) | **HOLD** |
| strength_at_rout | > 67% | **76.13** | **HOLD** |
| LEFT edge drain | present + material | **58.68** | **HOLD** |
| front / right / rear drains | (report) | 0.00 / 0.00 / 0.39 | OK |
| winner | flanker `red_b` | `red_b` | OK |

## Notes

- Trace-vs-file "baseline" checks were tautological (gitignored traces rewritten each run); replaced with explicit flank gates above.
- Gravity A/B (radius 4 vs 0) remains non-byte-identical on S3 (expected — angled approach); winner/combat identical per WO-024 escalation.
- This confirmation is committed **before** R21 / `quality_of_day` so the two changes stay disentangled.

Evidence: `docs/reports/evidence_wo025/s3_metrics_before.log`
