# COMPLETION REPORT — WO-008

**Work order:** WO-008 — Edge-Based Contact: Flanks & Corners  
**Branch:** `cursor/wo-008-edge-contact-fd84`  
**Date:** 2026-07-11  
**TD review:** Corrections applied per NOT APPROVED memo (six items)

---

## Assumptions made

**NONE**

---

## Governance

Results outside a stated acceptance band are **not PASS**. S4 side/front decomposition outside ~3× is **ESCALATE**, not relabeled. No acceptance semantics are modified via assumptions.

---

## 1. Edge basis fix

Canonical basis implemented in `edge_contact.gd` / `formation_geometry.gd`:

| Edge | Definition |
|------|------------|
| FRONT | Defender facing vector |
| LEFT | Facing rotated +90° CCW (soldier's left; Godot Y-down) |
| RIGHT | −90° from facing |
| REAR | −facing |

**Compass test:** `tests/edge_contact_compass_test.gd` — **32/32 PASS** (8 approach directions × 4 defender facings). Example: west-facing defender, south approach → **LEFT** (`W|S`).

Head-on pairs defer oriented-edge `has_contact` until `units_have_front_contact` is true, preserving S1/S2 legacy combat.

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
| S3 combat | **35.5s** | PASS |
| Combat ratio (S3/S1) | **0.52** | **0.45–0.60 PASS** |
| Blue `strength_at_rout` | **79.82%** | PASS (> 67%) |
| Blue edge drains | front=15.3, **left=30.2**, rear=17.8 | PASS (×2 left drain present) |
| Allied/enemy non-routing overlap | **0 failures** | PASS |

Flank release at **9.5s** after first contact (scripted local-frame placement, maintained each tick, iterative allied clearance). Trace: `tests/traces/scenario_03_1000.csv`.

---

## 4. Scenario 4 — Drain comparison (seed 1000, 50 ticks)

| Mode | Drain/s | Spawn edge label |
|------|---------|------------------|
| FRONT | **0.059** | front |
| SIDE | **0.641** | left |
| CORNER | **0.060** | front+left |

**Side/front decomposition (seed 1000):**

| Component | Value |
|-----------|-------|
| Observed side/front | **10.91×** |
| Multiplier component (×2 / ×1) | **2.00×** |
| Contact-frontage component (observed ÷ mult) | **5.46×** |

**ESCALATE:** frontage component **> ~3×** after multiplier split. Labels are clean single/multi-edge at spawn; harness holds spawn geometry each tick for measurement.

---

## 5. ROUT collision ruling

Units in **ROUTING** state drop collision entirely (formless fugitives). Documented in `CombatResolver.units_overlap()` and `Scenario01._assert_no_overlaps()`.

No-overlap assertion covers **all non-routing pairs** (allied and enemy). Pursuit contact deferred to future WO (proximity, not collision).

---

## 6. Files changed (TD corrections)

| File | Change |
|------|--------|
| `scripts/formation_geometry.gd` | `left_vector()` / documented `right_vector()` |
| `scripts/edge_contact.gd` | Canonical projector, center-side gating, head-on deferral |
| `scripts/combat_resolver.gd` | ROUTING overlap exemption |
| `scripts/scenario_01.gd` | Non-routing overlap assert; head-on legacy path isolation |
| `scripts/scenario_03.gd` | Local-frame LEFT flank script, maintain + allied correction |
| `scripts/scenario_04.gd` | Spawn-label harness, geometry maintenance |
| `tests/edge_contact_compass_test.gd` | 32-case automated compass |
| `tests/scenario_wo008_autotest.gd` | Bands, ESCALATE gates, compass subprocess |

---

## Escalations (open)

1. **S4 side/front frontage component 5.46×** — exceeds ~3× post-multiplier band; needs TD review of side-contact frontage measurement vs head-on legacy drain baseline.
