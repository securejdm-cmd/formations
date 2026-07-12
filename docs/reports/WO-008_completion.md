# COMPLETION REPORT — WO-008

**Work order:** WO-008 — Edge-Based Contact: Flanks & Corners  
**Branch:** `cursor/fast-harness-wo008-rerun-fd84`  
**Date:** 2026-07-12  
**TD rulings applied:** S3 band, S4 corner, allied overlap release, accelerated harness, continuous contact adhesion

---

## Assumptions made

**NONE**

---

## Continuous contact adhesion (TD ruling)

| Item | Implementation |
|------|----------------|
| Constant | `engage_snap_max_m = 1.0` in `data/combat_constants.json` |
| Per-tick driver | `_apply_contact_adhesion()` in `scenario_01.gd` (before + after combat) |
| Segment pairs | Attacker (FRONT-edge unit per `pick_segment_orientation`) moves along contact normal; ties by `unit_id` |
| Head-on pairs | One-shot `snap_pair_to_contact` at engagement begin only (preserves S1/S2 traces) |
| Contact break | Segment pairs pruned when `adhesion_gap_m > engage_snap_max_m`; head-on uses geometric contact prune |
| Overlap safety | Binary-search partial move (`_max_adhesion_move_m`); respects allied separation order |
| Flank release | `scenario_03.gd` calls adhesion immediately after scripted 9.5s release (no position clamp) |

---

## Accelerated test harness

| Check | Result |
|-------|--------|
| Fast certification (seed 12345) | **PASS** — realtime vs fast trace **byte-identical** |
| S1 regression (11 seeds) | **11/11 PASS** |
| S2 regression (11 seeds) | **11/11 PASS** |
| Determinism | **PASS** |

---

## Scenario 3 — Continuous adhesion re-run (seed 1000, fast mode)

| Metric | TD baseline | Actual (post-adhesion) |
|--------|-------------|------------------------|
| Combat | 22.0s | **54.6s** |
| Ratio (S3/S1) | **0.32** | **0.80** |
| Blue `strength_at_rout` | 78.60% | **67.46%** |
| Blue LEFT drain | **50.3** | **8.47** |
| Overlap assertion | — | **PASS** |

**ESCALATE:** Ratio **0.80** outside band **[0.28, 0.45]**. LEFT drain **8.47** vs baseline **50.3**.

### Escalation specifics (tick data)

After flank release (~tick 950+), `red_b`/`blue_a` remain in the partner list (within 1m adhesion) but `EdgeContact.classify_contact` returns **`has_contact=false`** on most post-release ticks while `adhesion_gap_m` reports **0** on the primary approach axis — adhesion does not translate (gap ≤ ε), and segment `_combat_tick` skips the pair (`contact.has_contact` gate). Net effect: flank engagement is **partner-linked but not segment-resolved**, producing minimal LEFT-channel drain.

Trace: `tests/traces/scenario_03_1000.csv`

---

## Scenario 4 — Three-mode drain (seed 1000, 50 ticks)

| Mode | Drain/s | Ordering |
|------|---------|----------|
| FRONT | **3.163** | front < corner < side **PASS** |
| SIDE | **6.811** | |
| CORNER | **5.663** | blend within 0.5 tol **PASS** |

---

## Files changed (adhesion pass)

| File | Change |
|------|--------|
| `data/combat_constants.json` | `engage_snap_max_m` |
| `scripts/combat_resolver.gd` | `adhesion_gap_m`, `apply_contact_adhesion_pair`, partial move search |
| `scripts/scenario_01.gd` | Per-tick adhesion; head-on vs segment prune split |
| `scripts/scenario_03.gd` | Flank-release adhesion; tick order aligned |
| `scripts/edge_contact.gd` | `pick_segment_orientation` unit_id tie-break |
| `scripts/unit.gd` | Head-on engage snap only |

---

## Open escalations

1. **S3 segment contact desync** — engaged pairs within 1m but `classify_contact` false; adhesion gap metric returns 0; LEFT drain 8.47 vs 50.3 baseline. Requires TD follow-up on segment closure vs edge-classifier alignment.
