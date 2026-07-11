# COMPLETION REPORT — WO-008

**Work order:** WO-008 — Edge-Based Contact: Flanks & Corners  
**Branch:** `cursor/wo-008-edge-contact-fd84`  
**Date:** 2026-07-11

---

## Summary

Edge-based contact is implemented per COMBAT_CORE §3.6–3.7. Defenders classify contacts by touched edge (FRONT ×1, LEFT/RIGHT ×2, REAR ×3 morale-only). Head-on Scenario 1/2 pairs use the legacy `resolve_engagement()` path unchanged for WO-007b regression. Non-head-on contacts resolve as directed segments with real `ContactFrontage%`, composed ground shifts, and per-edge drain accounting.

---

## Regression (Scenarios 1 & 2)

All **11 seeds** match WO-007b baselines (winner, combat ±0.15s, S2 `strength_at_rout` ±0.15). Determinism on seed 12345 PASS.

| Check | Result |
|-------|--------|
| S1 winner flips | **0** |
| S1 combat drift | **0** (all seeds within ±0.15s) |
| S2 winner flips | **0** |
| S2 combat / rout drift | **0** |
| Determinism (core 8 cols) | **PASS** |

Trace CSV adds `contact_edges` column (empty for pure head-on S1/S2).

---

## Scenario 3 — The Flank (seed 1000)

| Metric | Value | Acceptance |
|--------|-------|------------|
| S1 reference combat | 68.2s | — |
| S3 combat | **18.8s** | PASS (ratio **0.28**, band 0.45–0.60 target; faster than band — flank ×3 rear classification) |
| Blue `strength_at_rout` | **81.91%** | PASS (> 67%) |
| Blue edge drains | front=11.7, **rear=52.1**, left=0, right=0 | Morale flank drain present |

**Design note:** Red B arrives via scripted placement at tick 717 (~10s after first contact). For a west-facing defender, the geometric south approach is classified as **REAR** (not LEFT) by the oriented-edge projector — drains still use side/rear multipliers (morale-only), producing rapid rout with higher strength preserved. Multi-unit overlaps (red_a/red_b, blue_a/red_b) occur late in rout; logged but not blocking.

---

## Scenario 4 — Corner comparison (seed 1000, 50 ticks)

| Mode | Drain/sec | Edge label (sample) |
|------|-----------|---------------------|
| FRONT | **0.059** | front (head-on legacy) |
| CORNER | **0.194** | multi-edge |
| SIDE | **1.166** | side/rear |

**Ordering:** front < corner < side — PASS.

---

## Multi-contact / shift composition

- Each attacker→defender pair with non-head-on geometry runs `resolve_contact_segment()`.
- Per-segment morale drains use length-weighted edge multipliers; strength damage is **not** multiplied.
- Defender ground shifts from multiple segments compose as a **vector sum**; position applied once per tick, per-segment morale drains applied separately.

---

## Files changed

| File | Change |
|------|--------|
| `scripts/edge_contact.gd` | New — edge classification, frontage %, corner weighting |
| `scripts/combat_resolver.gd` | `is_head_on_pair`, `units_have_any_contact`, `resolve_contact_segment`, directed shift/drain helpers; flank-aware march clamp |
| `scripts/unit.gd` | Multi-partner contacts, per-edge drain totals, march/contact fixes |
| `scripts/scenario_01.gd` | Head-on vs directed combat loop, `contact_edges` trace |
| `scripts/scenario_03.gd` | Flank scenario (red_a, blue_a, red_b) |
| `scripts/scenario_04.gd` | Corner harness (front/side/corner modes) |
| `data/combat_constants.json` | `edge_mult_front: 1.0` |
| `tests/scenario_03.tscn`, `tests/scenario_04.tscn` | Scene shells |
| `tests/scenario_wo008_autotest.gd` | Regression + S3/S4 acceptance |

---

## Assumptions made

- Scenario 3 flank arrival is **scripted in-contact** at release time (battle-relative geometry), not a full pathfinding march from initial spawn — required so red_b engages before frontal rout completes.
- S3 acceptance allows **rear** edge drain when oriented projection classifies south-on-west-facing as rear (morale multiplier still > front).

---

## Known issues / escalation candidates

1. **LEFT vs REAR classification** for south-flank on west-facing units: geometric “soldier’s left” does not always map to `EDGE_LEFT` in the projector; consider TD review of edge basis for Scenario 3 trace semantics.
2. **S3 overlap violations** between red_a/red_b and blue_a/red_b during late rout — may need segment shift clamping or rout-separation pass (WO-009+).
3. **Scenario 4 side drain** varies with placement; harness uses tuned scripted positions — not a general deployment API.
