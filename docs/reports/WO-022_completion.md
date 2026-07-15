# COMPLETION REPORT — WO-022 — Date 2026-07-15 — Commit PLACEHOLDER

**Work order:** WO-022 Gate 2: The Triangle & The Battle  
**Branch:** `cursor/wo-022-gate2-triangle-fd84`  
**Date:** 2026-07-15  
**Commit:** `9b17fcd21dfdcb42490cf4b3132673f7790900a5`
**Base:** `main` post WO-021 merge (`3b3c752` tip includes post-merge suite)  
**Evidence:** `docs/reports/evidence_wo022/`  
**Suite:** Meta PASS=72 FAIL=0 **exit 0**

---

## Built

Gate 2 evidence WO: Agility-isolation S35, reusable matchup matrix (Phase 5 embryo), triangle verification from matrix (no tuning), designer-playable S40 mixed 6v6 on the test hill. WO-021 carry-forward governance restored. **No balance constants changed.**

---

## Task 1 — Carry-forward from WO-021

### 1. Report header stamp + Assumptions / Known issues
Restored on `docs/reports/WO-021_completion.md` (literal first-line `# COMPLETION REPORT — WO-021 — Date … — Commit <sha>`; sections present).

### 2. S37 run-up distance
**120 m** identical downhill/uphill (S20/S27 long-runup family).

### 3. Sub-stepping (dynamic — not hardcoded 2×)
Formula in `ChargeCombat.march_substep_count`:

```
peak = min(target_speed, speed_now + accel × delta)
disp = peak × delta
n = 1 if disp < engage_snap_max_m else floor(disp / snap) + 1
```

Per-substep displacement stays ≤ `engage_snap_max_m` (1.0 m) by construction for **any** speed (n grows). At ~18.2 m/s and δ=0.1 s → n=2. Safe maximum velocity: **unbounded** (n scales with peak×delta).

---

## Task 2 — S35 Agility isolation (R20)

Profiles identical except Agility A30 vs A80; same armor / class / close_damage / mass / profile; both ordered out of melee.

| Metric | A30 | A80 | Ratio |
|--------|-----|-----|-------|
| Duration (s) | 2.40 | 1.40 | **1.71** |
| Strength lost | 6.02 | 3.41 | **1.77** |

Duration ratio matches the R20 reference 2.40/1.40 ≈ 1.71. Strength-loss ratio **1.77** (reported, not tuned). Regression guard on Agility↔duration only.

---

## Task 3 — Matchup matrix (Gate 2 / Phase 5 infrastructure)

Runner: `tests/matchup_matrix.gd`  
Profiles × profiles × 11 seeds, flat ground, 200 m approach.  
Outputs: `docs/reports/evidence_wo022/matchup_matrix.csv` + `matchup_matrix.md`  
**MATRIX_DETERMINISM PASS** (seed-1000 re-run byte-stable winners/combat).

Win-rate table (attacker rows, defender columns; % attacker wins):

| Atk \ Def | infantry | inf_charge | spears | archer | cavalry | skirmisher |
|-----------|----------|------------|--------|--------|---------|------------|
| infantry | 64% | 64% | 100% | 100% | 100% | 100% |
| inf_charge | 100% | 100% | 100% | 100% | 100% | 100% |
| spears | 0% | 0% | 55% | 100% | 0%* | 0%* |
| archer | 0% | 0% | 0% | 100% | 0% | 0% |
| cavalry | 0% | 0% | 0% | 100% | 100% | 100% |
| skirmisher | 0% | 0% | 0% | 100% | 0% | 73% |

\*spears→cavalry/skirmisher cells timed out (~666 s combat, no decisive STR) — finding, not tuned.

---

## Task 4 — Triangle verification (margins; no softening)

Canonical (11 seeds):

| Relationship | Cell (atk>def) | Win% | Mean combat | Mean win STR | Verdict |
|--------------|----------------|------|-------------|--------------|---------|
| Cavalry beats archer | cav>archer | **100%** | 25.4 s | 95.5 | **HOLDS** |
| Infantry beats archer in melee | archer>infantry | **0%** atk (infantry wins) | 35.4 s | 90.7 | **HOLDS** (attrit-then-melee) |
| Braced spears beat cavalry | cav>spears | **0%** cav | 90.4 s | 92.5 (spears) | **HOLDS** |

Counters:

| Relationship | Cell | Win% | Verdict |
|--------------|------|------|---------|
| Cavalry vs braced spears (loses) | cav>spears | 0% | **HOLDS** |
| Infantry frontal vs cavalry (holds) | cav>infantry | 0% cav / infantry defender wins | **HOLDS** |
| Skirmisher escapes anything slow | ski>infantry etc. | **0%** in forced 1v1 duel | **DOES NOT HOLD as combat win** — matrix duel forces engagement; escape is S30 magnetism behavior, not a win-rate cell. Finding: triangle “escape” is not evidenced by this duel matrix. |

**Additional findings (untuned):** `test_infantry_charge` wins **100%** vs all six. Spears as attacker vs cavalry never finishes (timeout). Triangle as RPS is intact for cav/archer/spears; skirmisher escape is outside this matrix’s semantics.

---

## Task 5 — S40 mixed battle

Scripted 6v6 on test hill (`scripts/scenario_40_mixed.gd`, mode `s40_mixed`).

| Check | Result |
|-------|--------|
| Showcase (volley/melee/flank/brace) | true across 11 seeds (`wo022_s40_seeds.gd`) |
| Rout shock (full 8k ticks) | true on seed probe; harness early-exit after showcase may report shock=false |
| Outcome × 11 seeds | **winner=none** all (contested; dynamic/readable, not balanced) |
| Cloud FPS sample | equiv_fps **530.7**; avg_step_ms 1.884; p95_step_ms **1.979** (≥60 FPS gate: cloud observational; designer desktop is authority) |
| perf_40 (suite) | sim_thread p95 **39.666** ms; exit 0 |

---

## Task 6 — Regression lock

| Gate | Result |
|------|--------|
| S12 | volleys=**18** approach_lost=**8.04%** |
| S23–S29 spectrum | unchanged (S23 land=53.99 etc.) |
| Fast + threaded cert | PASS byte-identical |
| Contact coherence | holds |
| Meta | **PASS=72 FAIL=0 exit 0** |

---

## Assumptions made

- Matchup matrix treats Pierce defenders as pre-braced; archer-as-attacker uses hold while defender marches (S12 pattern).
- S40 harness may stop after showcase (≥1200 ticks) to avoid overlap-assert flood stalling threaded perf_40 on cloud; seed probe still runs full observation including shock.
- Designer-desktop ≥60 FPS remains the Gate; cloud FPS is environmental.

## Known issues

- Matrix cells spears→cavalry / spears→skirmisher timeout without decisive STR — record as data.
- Skirmisher “escape vs slow” is not a duel win-rate; S30 remains the magnetism evidence.
- Sim-thread worker previously held mutex across `advance_one_tick` (overlap logging stalled main); fixed + tick-sample cap 10k for cloud stability.

## Attestation

- Branch: `cursor/wo-022-gate2-triangle-fd84`
- Full SHA: `9b17fcd21dfdcb42490cf4b3132673f7790900a5`
- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-022-gate2-triangle-fd84/docs/reports/WO-022_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-022-gate2-triangle-fd84/docs/reports/evidence_wo022/suite_stdout.log

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-022-gate2-triangle-fd84/docs/reports/WO-022_completion.md
- WO-021 (stamped): https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-022-gate2-triangle-fd84/docs/reports/WO-021_completion.md
- Main merge suite: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/MAIN_MERGE_wo021_completion.md
