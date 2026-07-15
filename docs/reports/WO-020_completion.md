# COMPLETION REPORT — WO-020 — Date 2026-07-15 — Commit 11fc23ee740991bdf17d42bd5218722e456bcd43

**Work order:** WO-020 Full Magnetism — Gravity, Rotation & Disengage (R19)  
**Branch:** `cursor/wo-020-full-magnetism-fd84`  
**Date:** 2026-07-15  
**Commit:** `11fc23ee740991bdf17d42bd5218722e456bcd43`  
**Base:** `main` (post WO-016..019 merge)  
**Evidence:** `docs/reports/evidence_wo020/`  

---

## Built

Full magnetism over R9 adhesion:

1. **Engagement gravity** (`engage_radius_m=4.0`): unengaged units auto-rotate + close on a front-arc enemy inside the radius.
2. **R19 Pinning:** already-engaged units never auto-rotate toward new contacts (flank×2 persists).
3. **Agility live:** turn rate `rad/s = base_turn_rate_rad × (Agility/50) / mass` (R5). Deg/s = that × 180/π.
4. **Rotation-under-contact drain:** `2.0/sec × (1 − Agility/150)` for the full wheel even if classifier contact drifts while turning.
5. **Disengage:** duration `3.0 × (1 − Agility/150)`; free melee + ordered-retreat cohesion from every partner; cannot strike back; `auto_engage_locked` break-off so cavalry can leave and re-charge.
6. **Profile:** `data/units/test_skirmisher.json` (Agility 80, Low, weak melee) for S30.

---

## Constants

| Key | Value | Notes |
|-----|-------|-------|
| `engage_radius_m` | **4.0** | deliberately tiny; not raised for tests |
| `disengage_base_s` | **3.0** | × (1 − Agility/150) |
| `rotate_under_contact_drain` | **2.0** | /sec × (1 − Agility/150) |
| turn formula | `base_turn_rate_rad × (Agility/50) / mass` | Agility live |

---

## Task 1 — Flank-charge timing (verify)

| Quantity | Value |
|----------|-------|
| Gallop ×4m | 13.4 m/s → **0.299s** to cross engage radius |
| Infantry 90° (A50, mass 1) | `π/2 / 2.5` ≈ **0.628s** |
| Conclusion | Defender cannot reface a gallop flanker inside the gravity window. If already engaged, R19 also pins. |

Gravity front-arc / brace-threat clock: no conflict observed (gravity only while unengaged; brace threat clock unchanged).

---

## Scenarios S30–S34 (actuals)

| ID | Result | Actuals |
|----|--------|---------|
| S30 | PASS | sk withdraw **1.40s** lost_str=**2.43** coh=**7.81**; spears **2.40s** lost_str=**2.57** coh=**8.99** |
| S31 | PASS | spears A30 **1.10s** drain=**1.760**; infantry A50 **0.70s** drain=**0.933** |
| S32 | PASS | str fail/dis/rech=**89.18 / 88.84 / 79.19**; impact2=**19.243** (full gait **13.5** m/s × strength≈88.8%; 100%→≈21.6) |
| S33 | PASS | edges **front/front**; dots **0.980 / 0.980** |
| S34 | PASS | flank persists; no auto-reface; samples=20 |

---

## Regression (Task 5)

| Gate | Result |
|------|--------|
| S1 gravity A/B (radius 4 vs 0) | **byte-identical** (seed 12345; combat 81.6) — no escalation |
| S12 | volleys=**18** approach_lost=**8.04%** |
| S23–S29 | unchanged spectrum (suite) |
| Fast + Threaded certs | **byte-identical** |
| Contact coherence | holds |
| Meta | **PASS=66 FAIL=0 exit 0** |
| Perf40 | main post-019 **1.089/1.217** → WO-020 **1.561/1.775** avg/p95 ms (budget 50ms; cloud env) |

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# SUITE_EXIT=0
```

---

## Files changed

- `scripts/magnetism.gd` — gravity / agility / disengage helpers  
- `scripts/unit.gd`, `scripts/sim/sim_unit_proxy.gd`, `scripts/sim/sim_battle_core.gd` — gravity, pin, wheel drain, free hits, break-off  
- `data/combat_constants.json`, `data/units/test_skirmisher.json`  
- `docs/DESIGN_RULINGS_v1.2.md` — R19  
- `scripts/scenario_30.gd`…`34.gd` + `tests/scenario_30.tscn`…`34.tscn`  
- `tests/scenario_wo010_autotest.gd` — EXPECTED_GREEN_PASS_COUNT=66  
- Evidence: `docs/reports/evidence_wo020/`

---

## Assumptions made
NONE

## Known issues
none

## Attestation

- Branch: `cursor/wo-020-full-magnetism-fd84`
- Full SHA: `11fc23ee740991bdf17d42bd5218722e456bcd43`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020-full-magnetism-fd84/docs/reports/WO-020_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020-full-magnetism-fd84/docs/reports/evidence_wo020/suite_stdout.log

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020-full-magnetism-fd84/docs/reports/WO-020_completion.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/WO-019_completion.md
- Suite log: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020-full-magnetism-fd84/docs/reports/evidence_wo020/suite_stdout.log
- S1 A/B: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-020-full-magnetism-fd84/docs/reports/evidence_wo020/s1_ab.log
