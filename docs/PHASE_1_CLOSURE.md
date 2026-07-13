# PHASE 1 CLOSURE — TD Declaration

**Status:** COMPLETE  
**Gate:** GATE 1 — **PASSED**  
**Tag:** `v0.1-phase1`  
**Commit:** `733bf40` (`main`)  
**Date:** 2026-07-13  
**Authority:** Technical Director

---

## Declaration

Phase 1 — **Core Simulation ("Two Blocks Fighting")** — is **COMPLETE**.

Designer Gate 1 review has concluded with approval. All Phase 1 engineering work orders are closed. No further Phase 1 work is authorized.

Phase 2 work orders begin with **WO-013** (Unit Categories & Ranged Combat). The workshop stands by for issuance.

---

## Gate 1 criteria (DEVELOPMENT_PLAN §Phase 1)

| Criterion | Result | Evidence |
|-----------|--------|----------|
| All four test scenarios pass; numbers reviewed | **PASS** | S1–S8 autotest suite (`scenario_wo010_autotest.gd`); WO-007b k-dmg sweep; mirror audit (WO-006) |
| Scenarios look like K&G battle moments | **PASS** | Designer Gate 1 review; visual gallery (`tests/visual_gallery.tscn`); crack band visual amendment approved |
| 60 FPS with 40 blocks on mid-range phone | **PASS** (engineering) | WO-011 sim-thread separation; WO-012 `SimBattleCore` consolidation; measured 40-unit p95 sim-thread tick **28.163 ms** (≤ 50 ms gate) |

---

## Phase 1 work orders — closed

| WO | Title | Status |
|----|-------|--------|
| WO-001 | Project skeleton | MERGED |
| WO-002 | Scenario 01 | MERGED |
| WO-003 | Scenario revision | MERGED |
| WO-004 | Battle readability | MERGED |
| WO-005 | Shrink/drain fix | MERGED |
| WO-006 | Scenario 02 mirror audit | MERGED |
| WO-007 | Direction independence | MERGED |
| WO-007b | k-dmg sweep | MERGED |
| WO-008 | Edge contact | MERGED |
| WO-009 | Routs & rally | MERGED |
| WO-010 | Gate 1 remediation | MERGED |
| WO-010b | Perf profile | MERGED |
| WO-010c | Testmode perf | MERGED |
| WO-011 | Sim-thread separation | MERGED |
| WO-012 | Sim core consolidation | MERGED |
| — | Visual amendment series (gallery parse, scene smoke, crack band) | MERGED |

---

## Phase 1 deliverables (engineering)

### Simulation core
- Unit entity: position, facing, speed, formation footprint, cohesion, strength
- Movement with collision (allied non-overlap; routing formless exemption)
- Edge-contact melee resolution: damage, push contest, per-channel flank/rear multipliers
- Morale: shock drains, wavering, rout, rally, neighbor shock cascade
- Casualty visualization: centered shrink, crack band, grind band
- Deterministic seeded RNG; byte-identical fast vs threaded certification

### Architecture (end state)
- `SimBattleCore` — single authoritative combat tick implementation
- `SimThreadController` — worker thread with double-buffer snapshots
- Canonical combat libraries (`CombatResolver`, `EdgeContact`, `FormationGeometry`, `ContactCache`) — Variant-typed, shared by core and scenarios
- Spatial grid partitioning for O(n) neighbor queries at scale

### Test harness
- Scenarios S1–S8 (head-on, armor, flank, push, mirror, overlap, rally, shock, blob)
- Universal scene smoke gate (all `.tscn` load + instantiate + one frame)
- Trace certification (`wo011_trace_diff.gd`, 627 lines byte-identical)
- Compass test (32/32 edge-contact orientations)

### Design authority locked
- `docs/COMBAT_CORE_v1.1.md`
- `docs/DESIGN_RULINGS_v1.2.md`
- `data/combat_constants.json`

---

## Deferred to later phases

| ID | Item | Phase |
|----|------|-------|
| P6-TEXTURE-001 | Crack band texture — tileable cracked-earth asset or enhanced voronoi shader | Phase 6 |
| R4, R5 | Momentum charge model; mass & inertia via profile | Phase 2 |
| R3 | No auto-envelopment (player orders) | Phase 3 |
| R6 | Full elevation grid | Phase 3 |

See `docs/BACKLOG.md`.

---

## Certification snapshot (at closure)

```
[WO-010] Fast-mode certification PASS (seed 12345 trace byte-identical)
[WO-011] Threaded certification PASS (seed 12345 trace byte-identical)
[SceneSmoke] PASS 14 scenes
tests/wo011_trace_diff.gd → TRACE MATCH (627 lines)
WO-011 Perf40 p95_tick_ms = 28.163 (≤ 50 ms gate)
```

---

## Phase 2 authorization

**GREEN LIGHT:** Phase 2 engineering authorized. First work order: **WO-013**.

Phase 2 scope (per DEVELOPMENT_PLAN): unit categories (Foot / Archer / Mounted), ranged combat, anti-armor activation, terrain v1.

---

## Links

- This document: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/PHASE_1_CLOSURE.md
- Development plan: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/DEVELOPMENT_PLAN.md
- WO-012 report: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/WO-012_completion_report.md
- Crack band closure: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/crack_band_visual_respec_completion.md
