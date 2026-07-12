# ESCALATION REPORT — WO-005 ADDENDUM

**Work order:** WO-005 ADDENDUM — Shrink-induced ground-loss drain investigation  
**Date:** 2026-07-11  
**Status:** AWAITING GREEN LIGHT — hypothesis tested and **rejected**; no further simulation changes applied beyond approved crack fissures.

---

## Blocker

The Technical Director hypothesized that WO-004’s halved combat durations (~39s vs WO-003’s ~73–96s) were caused by **ground-loss cohesion drain (`drain_per_meter_lost`) counting shrink-induced contact-line movement as push displacement**.

Investigation shows this is **not** the primary cause. Applying the proposed fix (exclude shrink depth from ground-drain meters) moved combat only **~2 seconds** (seed 12345: 39.0s → 40.9s), far from WO-003’s 78.0s.

---

## Investigation performed

### Code audit

- `drain_per_meter_lost` is applied **only** in `CombatResolver.apply_ground_shift()`, using `shift_m` from the push contest — never from shrink or snap directly.
- Rear-anchored shrink moves the unit center by `delta_depth / 2` via `apply_rear_anchored_depth_from_strength()`.
- Per-tick order (unchanged): push ground shift → strength loss / shrink → `snap_pair_to_contact`.

### Empirical test (proposed fix applied, then reverted)

Implemented: `push_only_drain_m = max(0, shift_m − shrink_depth_delta_m)` on the push loser when both occur same tick.

| Seed | WO-003 combat | WO-004 combat | With drain fix |
|------|---------------|---------------|----------------|
| 12345 | 78.0s | 39.0s | **40.9s** |
| 1000 | 76.2s | 38.1s | **40.1s** |
| 1004 | 96.2s | 48.1s | **50.2s** |

Winner flips: **none** across all tests.

### Trace analysis (seed 12345)

Typical per-tick magnitudes during mid-combat (~100s):

- Push `shift_m` (loser): ~0.03–0.08 m
- Shrink `delta_depth` (damaged unit): ~0.06–0.08 m per tick (comparable to push shift)
- With drain fix: ground-drain meters often clamped to **0** (shrink ≥ shift), yet combat duration barely changes.

**Conclusion:** Reducing ground-drain cohesion does not restore WO-003 pacing. The rout clock is dominated by **Task 3 geometry**: rear-anchored shrink recesses the front face, then `snap_pair_to_contact` advances the winner into vacated ground **every damage tick**, accelerating geometric collapse and push-winner streaks — independent of whether shrink meters are also charged `drain_per_meter_lost`.

### Why WO-003 was slower

WO-003 thinned blocks **symmetrically about center** (no rear-anchor position shift, no post-damage snap). Contact-line geometry changed more slowly; combat lasted ~2× longer with the same `k_dmg` and push rules.

---

## Options

**A) Refine Task 3 geometry (recommended)**  
Adjust rear-anchor / snap so winner advance from shrink does not stack with push shift every tick — e.g. snap only on penetration, winner advance capped per tick, or rear-anchor visual-only with centered collision for Phase 1. Tradeoff: needs TD ruling on how much real geometry vs presentation.

**B) Re-tune `k_dmg` / rout thresholds for new geometry**  
Restore 60–90s band under WO-004 geometry. Tradeoff: WO-004/WO-005 explicitly forbid self-tuning without new TD values.

**C) Revert Task 3 real-geometry shrink**  
Keep WO-004 readability features (stat card, results, bump) but return centered shrink collision from WO-003. Tradeoff: loses K&G front-crack footprint until reimplemented.

---

## Recommendation

**Option A** — the duration regression is a geometry/snap interaction, not a drain double-count. TD should specify how aggressively the winner may close gap after shrink before we change code.

---

## Delivered despite escalation (TD-approved)

**Crack fissures (render-only)** — implemented as requested:

- Small jagged dark lines along engaged front edge
- Flicker open/closed; density scales with damage taken
- Constants: `crack_fissure_max_count`, `crack_fissure_length_m`, `crack_fissure_flicker_s`
- No simulation / trace impact

---

## AWAITING GREEN LIGHT

**Resolved 2026-07-11:** TD issued GREEN LIGHT — Modified Option C. See [`docs/reports/WO-005_completion.md`](WO-005_completion.md).

No further combat-geometry or constant changes pending.
