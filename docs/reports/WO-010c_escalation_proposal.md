# WO-010c Escalation Proposal — 40-Unit Tick Target

**Date:** 2026-07-12  
**Current:** 21.0 ms avg tick @ 40 units (gameplay path, cloud)  
**Target:** ≤ 12 ms  
**Gap:** ~9 ms (43% over target)  
**Regression:** Byte-identical PASS after WO-010c

Per TD directive WO-010c item (6), optimization stops here. This document proposes architectural options for TD/designer review.

---

## What WO-010c proved

| Fix | 40-unit impact | Notes |
|-----|----------------|-------|
| Overlap assert → test-only | **−8 ms** | Correct separation of verification from gameplay |
| MARCHING grid radius query | **−1 ms movement, −245 classifier calls/tick** | Helps approach phase; negligible in massed combat |
| Allied dirty-flag skip | **~0 ms** | Massed combat = nearly all pairs move every tick |

The gameplay tick is now dominated by **allied separation + movement contact work** in O(n²) grid-pair loops when 40 units collapse into 1–2 spatial cells. No further safe micro-opts remain without risking another WO-010b-class trace drift incident.

---

## Option A — Sim-thread separation (recommended for review)

**Concept:** Decouple simulation from presentation.

```
Main thread (render):     read-only unit poses → draw visuals, UI, camera
Sim thread (10 Hz fixed): advance_one_tick() → writes pose/state buffer
```

**Expected gain:** 40-unit headless tick is already ~21 ms; visual frame budget is separate. For realtime play, main thread no longer blocks on classifier/OBB work → perceived 60 fps even when sim uses 21 ms.

**Tradeoffs:**
- Double-buffered unit state with one-tick latency (acceptable at 10 Hz sim)
- Careful Godot threading rules (no Node mutation off main thread — use plain data structs)
- Autotest path unchanged (headless fast-mode stays single-threaded for determinism)

**Risk:** Medium engineering effort; determinism preserved if sim thread is authoritative and trace emitted from sim buffer.

---

## Option B — Contact-bounded pair generation (gameplay only)

**Concept:** Replace full `_grid_sorted_pair_candidates()` for allied separation with:
- Allied pairs: same-team spatial neighbors only
- Skip pairs beyond `bounds_may_overlap`
- Skip pairs where neither unit moved (already done)
- **New:** skip pairs with center distance > combined half-extents + epsilon (no OBB possible)

**Expected gain:** 2–5 ms in massed combat if pair count drops from ~780 to ~120.

**Tradeoffs:** Must prove no overlap escapes detection without test-mode assert during gameplay. Could allow rare visual interpenetration corrected next tick by combat adhesion.

**Risk:** Medium correctness risk — needs new invariant tests beyond overlap assert.

---

## Option C — Incremental broad-phase pair cache

**Concept:** Maintain sorted pair list across ticks; invalidate only pairs touching a moved unit's grid cells.

**Expected gain:** 3–6 ms when few units move per tick (routing epilogue); limited in dense combat.

**Tradeoffs:** Memory + invalidation complexity; must preserve deterministic pair ordering.

**Risk:** High implementation complexity for variable gain.

---

## Option D — Native hot-path (GDExtension / Rust)

**Concept:** Move `classify_contact`, OBB overlap, and grid pair iteration to compiled extension.

**Expected gain:** 2–4× on classifier/overlap (~5–10 ms saved).

**Tradeoffs:** Build pipeline complexity; debugging harder; must match GDScript float behavior exactly for determinism.

**Risk:** Trace drift if floating-point order differs — WO-010b hash incident applies.

---

## Recommendation

1. **Accept 21 ms** for Gate 1 cloud agent if 10 Hz sim is the contract (21 ms < 100 ms tick budget).
2. If **12 ms hard gate** remains, pursue **Option A (sim-thread)** for player-facing perf and **Option B (contact-bounded pairs)** for headless/cloud sim — in that order.
3. Do **not** pursue further classifier micro-caching without pose-exactness review (WO-010b standing example).

---

## Reproduction

```bash
# Gameplay-path wall-clock
/tmp/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . -s res://tests/scenario_wo010b_wallclock.gd

# Full regression (overlap assert ON in fast-mode)
/tmp/godot/Godot_v4.3-stable_linux.x86_64 --headless --path . -s res://tests/scenario_wo010_autotest.gd
```
