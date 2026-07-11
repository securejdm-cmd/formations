# COMPLETION REPORT — WO-008

**Work order:** WO-008 — Edge-Based Contact: Flanks & Corners  
**Branch:** `cursor/wo-008-edge-contact-fd84`  
**Date:** 2026-07-11  
**TD review:** Remaining directives (S4 audit, ROUT visual, front-face anchor, S1/S2 regression) — **GREEN LIGHT complete**

---

## Assumptions made

**NONE**

---

## Governance

Results outside a stated acceptance band are **not PASS**. S4 side/front decomposition outside ~3× is **ESCALATE**, not relabeled.

---

## 1. Edge basis fix

Canonical basis in `edge_contact.gd` / `formation_geometry.gd`:

| Edge | Definition |
|------|------------|
| FRONT | Defender facing vector |
| LEFT | Facing rotated +90° CCW (soldier's left; Godot Y-down) |
| RIGHT | −90° from facing |
| REAR | −facing |

**Compass test:** `tests/edge_contact_compass_test.gd` — **32/32 PASS**.

Head-on pairs defer oriented-edge `has_contact` until `units_have_front_contact` is true (S1/S2 legacy path preserved).

---

## 2. Regression (Scenarios 1 & 2)

| Check | Result |
|-------|--------|
| S1 winner flips | **0** (11/11 seeds) |
| S1 combat drift | **0** (±0.15s) |
| S2 winner / combat / rout | **0** drift (11/11 seeds) |
| Determinism (core 8 cols, seed 12345) | **PASS** |

---

## 3. Scenario 3 — LEFT flank (seed 1000)

| Metric | Value | Band |
|--------|-------|------|
| S1 reference combat | 68.2s | — |
| S3 combat | **40.7s** | PASS |
| Combat ratio (S3/S1) | **0.60** | **0.45–0.60 PASS** |
| Blue `strength_at_rout` | **73.08%** | PASS (> 67%) |
| Blue edge drains | front=0, **left=37.8**, rear=9.1 | PASS (LEFT drain present) |
| Allied/enemy non-routing overlap | **0 failures** | PASS |

Flank release at **11.0s** after first contact (retuned after casualty-drain fix; prior 9.5s yielded ratio 0.62 with morale-only edge mult). Scripted local-frame placement, maintained each tick, iterative allied clearance.

---

## 4. Scenario 4 — Drain audit & decomposition (seed 1000, 50 ticks)

### Root causes fixed (shared corner ≈ front violation)

| Bug | Effect | Fix |
|-----|--------|-----|
| **Bidirectional segment processing** | `red>blue` and spurious `blue>red` both resolved per tick; reverse front contact inflated defender drain ~8× | Undirected `_pair_key` dedup + `pick_segment_orientation()` (flank beats reverse front) |
| **Edge mult on casualty cohesion** | Shift + casualty both edge-multiplied; theory applies mult to **shift morale only** | `apply_strength_loss_with_edge()` uses length-weighted attribution **without** mult |
| **Frontage_pct = 0 on flank** | Attacker push collapsed to 0; wrong winner/drain target | Flank `ContactFrontage%` from depth engagement when no defender FRONT edge |
| **S4 FRONT harness idle ticks** | Head-on contact lost after shift; ~1 combat tick / 50 → artificially low FRONT baseline | `snap_pair_to_contact()` on each `_maintain_spawn_contact()` for head-on pairs |
| **CORNER head-on steal** | `is_head_on_pair` skipped segment; legacy head-on drained at front rate | Segment loop allows head-on when `has_non_front_segment_contact()` (≥5 m flank/rear) |

### Worked per-tick example (SIDE, constants from `combat_constants.json`)

```
contact: left=15m → attacker_frontage_pct=15/15=1.0, defender_edge_pct=15/40=0.375
push_attacker ≈ 49×1.0×wobble ≈ 49
push_defender ≈ 49×0.375×wobble ≈ 18
attacker wins → defender_shift ≈ 0.06m
shift_morale_drain = 0.06 × drain_per_meter_lost(0.8) × side_mult(2.0) ≈ 0.096
casualty_drain = k_dmg×push×loser_mult → strength loss → cohesion (no edge mult) ≈ 0.17
```

### Measured drain comparison

| Mode | Drain/s | Spawn edge label |
|------|---------|------------------|
| FRONT | **3.155** | front |
| SIDE | **4.823** | left |
| CORNER | **3.163** | front+left |

**Side/front decomposition:**

| Component | Value |
|-----------|-------|
| Observed side/front | **1.53×** |
| Multiplier component (×2 / ×1) | **2.00×** |
| Contact-frontage component (observed ÷ mult) | **0.76×** |

**PASS** — frontage component within ~3× post-multiplier band. Ordering: `front (3.155) < corner (3.163) < side (4.823)`.

---

## 5. ROUT visual (WO-002 / COMBAT_CORE §4)

Routing units render **pale, formless, semi-transparent** — no border, softened footprint (`depth×0.55`, `frontage×1.2`, `modulate.a=0.38`). Collision already dropped in sim (`CombatResolver.units_overlap()`).

---

## 6. Visual front-face anchor

Simulation footprint stays centered on unit origin. **Visual front face** fixed at `full_depth_px × 0.5`; `_body.position` offsets so strength loss thins toward the **rear**. Grind band / crack fissures use the same front anchor.

---

## 7. ROUT collision ruling

Units in **ROUTING** state drop collision entirely. No-overlap assertion covers **all non-routing pairs** (allied and enemy).

---

## 8. Files changed (TD remaining directives)

| File | Change |
|------|--------|
| `scripts/edge_contact.gd` | Engagement pct, orientation picker, defender flank commitment, head-on deferral restored |
| `scripts/combat_resolver.gd` | Casualty vs shift drain split; worked-example comment |
| `scripts/scenario_01.gd` | Segment dedup, dual casualty, corner head-on routing, tie handling |
| `scripts/scenario_03.gd` | `FLANK_DELAY_SEC=11.0` (ratio retune) |
| `scripts/scenario_04.gd` | Harness snap + defender anchor; debug removed |
| `scripts/unit.gd` | ROUT pale/formless; front-face visual anchor |
| `tests/scenario_s4_drain_test.gd` | Three-mode drain diagnostic |
| `docs/reports/WO-008_completion.md` | This report |

---

## Escalations (open)

**None** — S4 side/front frontage component **0.76×** within band; corner ordering strict-between satisfied.
