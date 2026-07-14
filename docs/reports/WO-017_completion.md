# COMPLETION REPORT — WO-017 — Date 2026-07-14 — Commit PENDING_STAMP

**Work order:** WO-017 Bracing for Impact (R16 three-tier brace)  
**Branch:** `cursor/wo-017-three-tier-brace-fd84`  
**Date:** 2026-07-14  
**Commit:** `PENDING_STAMP`  
**Base:** `cursor/wo-016c-directional-charge-shock-fd84`  
**Evidence:** `docs/reports/evidence_wo017/`  

---

## (1) R16 implementation

| Tier | Name | Gate | Effect |
|------|------|------|--------|
| 1 | Instinctive | Front arc ≥ `brace_reaction_s` at gallop SI, unengaged, own speed ≤ 25% top, **front edge** | shock × `instinctive_brace_mult` (0.6) |
| 2 | Set to receive | Pierce + stationary + `brace_time_s` | shock 0 + reflect (supersedes T1) |
| 3 | Unaware | else | full directional shock |

Constants: `brace_reaction_s=1.5`, `brace_max_own_speed_pct=0.25`, `instinctive_brace_mult=0.6`.  
Threat clock uses cheap `faces_threat` + front-axis closing SI (no N² classify). Traces emit `brace_tier` / `brace` / `brace_mult`; gallery shows Tier 1 (cyan) vs Tier 2 (gold).

---

## (2) Spectrum matrix (pre-tune — Task 2)

Start constants already on target; matrix in `evidence_wo017/spectrum_pretune.log`.

| Case | tier | shock | land (arith) | band | stored after |
|------|------|-------|--------------|------|--------------|
| T1 front c100 | 1 | 46.01 | 53.99 | steady | 53.99 |
| T1 front c70 | 1 | 46.01 | 23.99 | wavering | 23.99 |
| T1 front c40 | 1 | 46.01 | −6.01 | rout | **0.00** |
| T3 march c100 | 3 | 76.68 | 23.32 | wavering | 23.32 |
| T3 late c100 | 3 | 76.68 | 23.32 | wavering | 23.32 |
| Flank c100 | 3 | 115.02 | −15.02 | rout | **0.00** |
| Rear c100 | 3 | 153.36 | −53.36 | rout | **0.00** |
| T2 Pierce c100 | 2 | 0.00 | 100 | steady | 100 |

**Cohesion clamp (Task 6):** `apply_cohesion_drain` uses `maxf(cohesion - amount, 0.0)`. Negative values in older tables were display arithmetic only.

---

## (3) Task 5 retune

Start values satisfy all five simultaneous targets — **no coefficient change**:

| Target | Result |
|--------|--------|
| T1 fresh land ≥ 45 | 53.99 ✓ |
| T3 unaware fresh ∈ [15, 30] | 23.32 ✓ |
| T1 shaken 40 routs | stored 0 ✓ |
| Flank fresh routs | ✓ |
| Rear fresh routs | ✓ |

`charge_cohesion_coeff` remains **3.55**; `instinctive_brace_mult` remains **0.6**.

---

## (4) Battle outcomes (S17 / S22 / S23)

Design promise *cavalry wins by impact, fades in grind* — verified on Tier 1 hold:

| Scenario | shock / land | combat | winner | cav_str | inf_str |
|----------|--------------|--------|--------|---------|---------|
| S17 | 46.01 / 53.99 | 52.7s | **blue_inf** | 66.1 | 93.5 |
| S22 | 46.01 / 53.99 | 52.7s | **blue_inf** | 66.1 | 93.5 |
| S23 | 46.01 / 53.99 | 52.7s | **blue_inf** | 66.1 | 93.5 |

---

## (5) New scenarios

| ID | Expectation | Result |
|----|-------------|--------|
| S23 | T1 hold ≥45, cav loses grind | PASS |
| S24 | Engaged → T3, line breaks (not steady) | PASS |
| S25 | Marching → T3, R15 [15,30] | PASS |
| S26 | Late arc → T3, R15 [15,30] | PASS |

---

## (6) Housekeeping

- Cohesion clamp confirmed (see spectrum stored vs arith).
- WO-016b speed-scale root cause documented:  
  `docs/reports/WO-016b_speed_scale_root_cause.md`  
  (Impact 6.4→21.6 = SI closing 13.5 via `charge_speed_si_scale=3.375`; movement meter left at 1.0).

---

## (7) Perf40 before / after

| | avg_tick_ms | p95_tick_ms |
|--|-------------|-------------|
| WO-016c before | 1.208 | 1.436 |
| WO-017 after | 1.279 | 1.496 |

No material regression (budget 50ms).

---

## Suite (exit 0)

Meta **PASS=58 FAIL=0 exit 0**. SceneSmoke PASS (32 scenes with S23–S26).

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# SUITE_EXIT=0
```

---

## Attestation

- Branch: `cursor/wo-017-three-tier-brace-fd84`
- Full SHA: `PENDING_STAMP`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-017-three-tier-brace-fd84/docs/reports/WO-017_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-017-three-tier-brace-fd84/docs/reports/evidence_wo017/suite_stdout.log
