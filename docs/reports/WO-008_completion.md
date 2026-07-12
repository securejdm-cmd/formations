# COMPLETION REPORT — WO-008

**Work order:** WO-008 — Edge-Based Contact: Flanks & Corners  
**Branch:** `cursor/fast-harness-wo008-rerun-fd84`  
**Date:** 2026-07-12  
**TD rulings:** Continuous adhesion, classifier single source of truth

---

## Assumptions made

**NONE**

---

## Classifier single source of truth (TD ruling)

| Item | Implementation |
|------|----------------|
| `contact_epsilon_m` | **0.01** in `data/combat_constants.json` — sole touch tolerance |
| Classifier | `EdgeContact.contact_epsilon_m()` — all edge spans derived from constant |
| Head-on geometry | `CombatResolver.contact_epsilon_m()` delegates to classifier |
| Removed | Independent adhesion gap epsilon, `adhesion_gap_m`, `pair_within_adhesion`, misalignment heuristics |

### Adhesion success criterion (classifier truth)

Each tick, for partner-linked **segment** pairs without classifier contact:
1. Binary-search attacker translation along contact normal (multi-direction fallback)
2. Stop when `pair_has_classifier_contact` is **TRUE** or required move exceeds `engage_snap_max_m` → **prune that tick**
3. Head-on pairs: one-shot engage snap only; segment adhesion skipped; head-on geometric prune in `_prune_broken_contacts`

### Permanent invariant assertion

After each adhesion pass, `_assert_partner_classifier_contact_invariant()` requires classifier contact for all **segment** partner pairs in `ENGAGED`/`WAVERING` state. Exposed via `had_adhesion_invariant_failure()`; checked in `scenario_wo008_autotest.gd`.

---

## Regression (fast mode)

| Check | Result |
|-------|--------|
| Fast certification (seed 12345) | **PASS** — byte-identical |
| S1 (11 seeds) | **11/11 PASS** |
| S2 (11 seeds) | **11/11 PASS** |
| Determinism | **PASS** |
| Adhesion invariant | **PASS** |
| Overlap (seed 1000) | **PASS** |

---

## Scenario 3 — Classifier adhesion re-run (seed 1000)

| Metric | TD baseline | Actual |
|--------|-------------|--------|
| Combat | 22.0s | **19.0s** |
| Ratio (S3/S1) | **0.32** | **0.279** (display 0.28) |
| Band [0.28, 0.45] | — | **MARGINAL** — 0.279 rounds to 0.28; strict `<` fails floor by 0.001 |
| Blue `strength_at_rout` | 78.60% | **75.70%** |
| Blue LEFT drain | **50.3** | **58.46** |
| Overlap assertion | — | **PASS** |
| Adhesion invariant | — | **PASS** |

Classifier-driven adhesion restores sustained LEFT flank contact (LEFT drain **58.46** vs prior **8.47**). Ratio slightly below band floor due to faster combat pacing (19.0s vs 22.0s baseline).

---

## Scenario 4 — Drain harness

| Mode | Drain/s | Result |
|------|---------|--------|
| FRONT | 3.163 | strict-between **PASS** |
| SIDE | 6.811 | |
| CORNER | 5.663 | blend **PASS** |

---

## Files changed

| File | Change |
|------|--------|
| `data/combat_constants.json` | `contact_epsilon_m` |
| `scripts/edge_contact.gd` | `contact_epsilon_m()`; remove duplicate const |
| `scripts/combat_resolver.gd` | Classifier-driven adhesion; `pair_has_classifier_contact` |
| `scripts/scenario_01.gd` | Prune-on-fail adhesion; segment invariant assertion |
| `tests/scenario_wo008_autotest.gd` | Adhesion invariant check |

---

## Open items

1. **S3 ratio floor** — actual **0.279** vs band minimum **0.28** (combat 19.0s vs baseline 22.0s). LEFT drain **58.46** exceeds baseline **50.3** by ~16% — TD review whether faster combat / higher drain is acceptable.
