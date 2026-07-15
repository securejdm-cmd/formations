# FORMATIONS — Deferred Backlog

Items explicitly deferred by TD ruling. Do not implement until the listed phase unless re-authorized.

## Gate 2 — Regression Guards

| ID | Item | Notes |
|----|------|-------|
| G2-S35 | **S35 Agility-isolate disengage** — two identical profiles differing ONLY in Agility (e.g. A30 vs A80, same armor/class/damage), both ordered out of melee | Logged WO-020b TD review. Isolates the Agility-duration link and the clean ~1.71 exposure ratio that S30 cannot show (R20). Regression guard, not a tuning target. |

## Phase 5 — Real Unit Profiles

| ID | Item | Notes |
|----|------|-------|
| P5-GAIT-001 | **Infantry charge gait** — `test_infantry_charge` `charge_gait_mult` 2.0 → ~3.0 sim-m/s (~running man ≈4.5 m/s under real profiles) | Logged WO-019 TD review. Revisit with real unit profiles in Phase 5; do not retune test profiles now. |

## Phase 6 — Presentation Pass

| ID | Item | Notes |
|----|------|-------|
| P6-TEXTURE-001 | **Crack band texture** — replace flat darkening with tileable cracked-earth texture asset (preferred) or voronoi shader | Reference: `docs/reference/crack_band_earth_reference.svg`. Mechanic (growth, anchoring, layering) approved; texture fidelity deferred from visual amendment series. |
