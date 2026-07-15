# Main merge — WO-020 + WO-020b (Magnetism complete)

## Sequence
1. Fast-forward `main` ← WO-020 (`cursor/wo-020-full-magnetism-fd84`)
2. Fast-forward `main` ← WO-020b (`cursor/wo-020b-magnetism-teeth-fd84`)
3. Docs: **R20** (disengage dual-channel; criterion 3 withdrawn; `disengage_damage_mult=2.0`) + Gate 2 **G2-S35** backlog

## Post-merge suite (on main)
| Item | Value |
|------|-------|
| Exit | **0** |
| Meta | PASS=66 FAIL=0 |
| Merged SHA (R20 tip) | `f6b1d8db332b136eccfb81e00995b408ac966c21` |
| Pre-suite tip (WO-020b) | `cc8849c32c6d74eb3a50de28d46d3aee9b57d22a` |
| Perf40 p95 | 1.813 ms (budget 50 ms) |

Magnetism is complete. WO-021 (Test Hill) follows.

## Attestation links
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/evidence_main_wo020/suite_stdout.log
- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/MAIN_MERGE_wo020_completion.md
