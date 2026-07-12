# COMPLETION REPORT — WO-008

**Work order:** WO-008 — Edge-Based Contact: Flanks & Corners  
**Branch:** `cursor/wo-008-edge-contact-fd84`  
**Date:** 2026-07-12  
**TD rulings applied:** S3 band re-derive, S4 corner instrumentation, S3 allied overlap release

---

## Assumptions made

**NONE**

---

## S3 band derivation (TD ruling 1)

| Item | Value |
|------|-------|
| TD accepted band | **[0.28, 0.45]** |
| TD baseline ratio (two-attacker harness) | **0.32** |
| Rationale | Two-attacker configuration compounds beyond per-edge multipliers; single-edge mults (2.0 shift / 1.5 casualty) do not bound combined front+flank pacing |

Prior band [0.45, 0.60] superseded.

---

## Regression (Scenarios 1 & 2)

| Check | Result |
|-------|--------|
| S1 winner / combat | **11/11 PASS** (±0.15s) |
| S2 winner / combat / rout | **11/11 PASS** |
| Determinism (seed 12345) | **PASS** |

---

## Scenario 3 — Flank + overlap release (seed 1000)

| Metric | TD baseline | Post-release (no position clamp) |
|--------|-------------|----------------------------------|
| Combat | 22.0s | **54.0s** |
| Ratio (S3/S1) | **0.32** | **0.79** |
| Blue `strength_at_rout` | 78.60% | **67.52%** |
| Blue LEFT drain | 50.3 | **8.43** |

### Allied overlap escalation (TD ruling 3)

Scripted per-tick `_maintain_flank_contact()` and overlap correction **removed** after flank contact is established. Sim collision governs thereafter.

| Item | Value |
|------|-------|
| First overlap tick | **803** |
| Last overlap tick (trace) | **1157** |
| Trace | `tests/traces/scenario_03_1000.csv` |
| Position clamp | **None** (per TD) |

**ESCALATE:** Non-routing `red_a`/`red_b` overlap persists ticks 803–1157 without clamp. Post-release combat ratio and flank drain diverge from TD baseline — allied hard-collision / march-lane separation requires TD follow-up.

---

## Scenario 4 — Three-mode drain (seed 1000, 50 ticks)

### Pre-fix corner instrumentation (harness placement bug)

| Edge | Length |
|------|--------|
| front | 26.255 m |
| left | 15.000 m |
| shift_blend | 1.364 |
| casualty_blend | 1.182 |

Measured corner drain ≈ front (corner/front ≈ 1.00) — **harness placement**, not resolver (head-on path consumed corner pairs).

### Post-fix (corner solver + segment harness + head-on skip)

| Mode | Drain/s | Edge label | Notes |
|------|---------|------------|-------|
| FRONT | **3.155** | front | |
| SIDE | **6.812** | left | side/front **2.16×** |
| CORNER | **5.663** | front+left | **strict-between PASS** |

### Corner instrumentation (post-fix)

| Metric | Value |
|--------|-------|
| front contact | **11.119 m** |
| left contact | **10.373 m** |
| balance_delta | **0.746 m** |
| shift_blend | **1.483** |
| casualty_blend | **1.241** |
| corner/front measured | **1.795** |
| blend expected | **1.345** (within 0.5 tol) |

---

## Resolver fixes

| Fix | File |
|-----|------|
| Head-on loop skips pairs with meaningful flank/rear segment contact | `scenario_01.gd` |
| `has_non_front_segment_contact` checks both orientations | `edge_contact.gd` |
| S4 side/corner use spawn-contact segment harness | `scenario_04.gd` |
| Corner spawn brute-force solver (~50/50 lengths) | `scenario_04.gd` |

---

## Files changed

| File | Change |
|------|--------|
| `scripts/scenario_03.gd` | Release flank position maintenance; single overlap escalation |
| `scripts/scenario_04.gd` | Corner solver, segment harness `_combat_tick`, spawn instrumentation |
| `scripts/scenario_01.gd` | Head-on skip when non-front segment contact |
| `scripts/edge_contact.gd` | Bidirectional non-front segment detection |
| `tests/scenario_wo008_autotest.gd` | S3 band [0.28,0.45], S4 instrumentation + ordering + blend checks |
| `tests/corner_instrument_probe.gd` | Corner diagnostic probe |

---

## Open escalations

1. **S3 allied overlap** ticks 803–1157 without clamp (trace attached).
2. **S3 post-release ratio 0.79** vs TD baseline 0.32 — flank effectiveness without blue-tracking maintenance.
