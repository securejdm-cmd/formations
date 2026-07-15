# COMPLETION REPORT — WO-023 — 2026-07-15 — Commit 60effa77fb1008c816278b47da3306084b9b5ab0
Tip SHA: 7adcda4efee7d79f69e94d1871906b452cca799c

Project: FORMATIONS — Phase 2 — Gate 2 Blockers
Issued by: Technical Director
Base: WO-022 tip (`5642ef7`)

---

## Assumptions made

NONE. (Escalate instead — per WO-023 acceptance and TD review of WO-022.)

### Escalations (not assumptions)

Carried forward from WO-022 disclosure that TD ruled must escalate, not assume:

1. **Defender posture** in the matchup matrix (standing HOLD; Pierce defenders pre-braced) was not specified by WO-022 — escalated as scenario-design requiring TD ruling; documented as `FRONTAL_VS_STANDING` configuration semantics.
2. **Archer-row inversion** (archer-as-attacker HOLDs while defender marches through fire) was not specified by WO-022 — escalated; documented in matrix semantics.
3. **Phase 5 backlog (TD finding):** “A 1v1 frontal duel matrix cannot evaluate cavalry, whose win condition is the flank, the rear, and the unaware defender. Phase 5's balance harness must be configuration-aware (frontal-braced / frontal-unaware / flank / rear / engaged) or it will balance a game that is not this one.”

---

## Known issues

1. Historical `Perf40 sim_thread` lines in WO-011..WO-022 reports are **non-comparable** to the WO-023 `MAIN_TICK` definition (see Task 1).
2. `engage_radius_m` (4.0) is much smaller than formation depths (~12–15 m), so engagement gravity cannot pull head-on blocks that are at contact range by centers; march destination remains the closer. Surfaced by Task 2 freeze; fixed with dest-exhausted snap, not by widening the radius (would be tuning).
3. Overlap-assert stderr floods remain on dense multi-unit scenarios (S40); harness truncates evidence tails.

---

## Task 1 — perf_40 1.847 → 39.666 (BLOCKING) → **(b) measurement change**

### Classification

**(b)** The ~21× jump is a **change in what the metric measures**, not a real 21× sim regression and not mere cloud variance.

### Like-for-like re-baseline (canonical `MAIN_TICK`)

Definition (now wired into the harness):

> 800 main-thread `advance_one_tick()` on `scenario_40_perf`, `fast_sim_mode=true`, **no** sim_thread.

| Commit bc413dbc0016055203654cb5385f8507345906f6/ tip | MAIN_TICK p95 (ms) | Notes |
|---|---:|---|
| WO-021 tip `6a0dc1f` | **57.2–57.6** (5 runs) | Re-measured this WO |
| WO-023 tip (this branch) | **57.5–57.7** (5 runs tip probe); suite **44.6** | Same order of magnitude; no 21× move |

Cloud variance on MAIN_TICK: **< 1 ms** across 5 repeats — eliminates **(c)** as the explanation of the 21× report delta.

Suite attestation this WO: `Perf40 MAIN_TICK avg=35.493 p95=44.577 ticks=800`.

### Where the *reported* sim_thread number moved (WO-021 → WO-022)

| Stage | Reported `sim_thread` p95 | ticks | What changed |
|---|---:|---:|---|
| WO-021 suite | 1.847 ms | ~766k | Worker raced unboundedly while main sync-blocked on mutex-held `advance_one_tick`; p95 dominated by cheap pre-contact samples; max included multi-minute outliers |
| After WO-022 harness: `delay_usec(1000)` + early S40 stop + sample cap + mutex unlock + stats-before-stop | 39.666 ms | 71 | Short wall-time sample of engaged 40-unit ticks under the delayed harness — different population |

**Bisect conclusion:** the number moves with the **WO-022 harness/thread measurement fixes**, not with S40 content cost. `MAIN_TICK` (actual 40-unit tick cost) was already ~57 ms on WO-021 tip.

### Historical figures now non-comparable

All prior report lines of the form `Perf40 sim_thread … p95_tick_ms=…` in **WO-011 through WO-022** must not be compared to WO-023 `MAIN_TICK` or to each other across the mutex/delay change.

---

## Task 2 — Non-terminating spears→cavalry / spears→skirmisher (BLOCKING) → **defect, fixed**

### Trace (spears→cavalry, seed 1000) — before fix

Evidence: `docs/reports/evidence_wo023/stall_spears_cav.log`, `stall_dense.log`.

| Window | Behavior |
|---|---|
| ~0–1338 | March approach; no contact |
| 1339+ | Engage/prune **every other tick** at sep≈13.5 m (half-depth sum); ~50% contact duty; strength/cohesion drain on contact ticks only |
| Contact breaks | **1121** over 4000 ticks |
| ~3580+ | Gap freezes ≈10.7–10.8 m; drain stops; `battle_over=false` forever (~666 s combat in matrix timeout) |

### Hypotheses

| Hyp | Result |
|---|---|
| (i) Spears (push 55) shove cavalry (40) migrating the line | **Confirmed as a contributor** — defender displacement grows ~30 m; attacker eventually reaches march destination |
| (ii) Contact make/break churn (adhesion) | **Confirmed** — strict every-other-tick oscillation at gap≈0.02 m |
| (iii) Damage asymptote via Strength% | **Not the freeze cause** — drain was progressing until destination-exhausted near-miss; after freeze strength/cohesion flatline because contact never resumes |

### Root cause (simulation defect)

Head-on pairs use a center-gap band (`|gap|≤eps` historically; penetration excluded). After push, gap≈+0.02 so contact clears. **S1 recovers** because both units still have residual march past destination and re-close. **spears→cavalry freezes** when the attacker reaches its march destination while still ≈0.02 m gap from the pushed defender — `engage_radius_m=4` cannot gravity-pull across ~13 m center separations, so neither side re-enters the band and the battle never ends.

### Fix (no constant tuning)

1. Penetration (`gap < -eps`) counts as front contact; head-on `units_have_any_contact` uses the gap band.
2. `try_begin_engagement`: if head-on and `eps < gap ≤ engage_snap_max` **and** march destination remaining ≤ `engage_snap_max` (or HOLD), snap and engage.

S1 combat **81.6 s preserved**. After fix: spears→cavalry / spears→skirmisher **0/11 timeouts** (`term_check.log`).

---

## Task 3 — `test_infantry_charge` dominance (report only, NO TUNING)

Diagnostic: `inf_charge` vs `inf_charge`, 11 seeds. Ephemeral constant overrides only.

| Condition | amp_peak | impact_scale | Attacker win rate | Mean combat_s |
|---|---:|---:|---:|---:|
| FULL | 2.5 | 1.006 | **100%** | 52.9 |
| NO_AMP | 1.0 | 1.006 | **100%** | 61.9 |
| NO_SHOCK | 2.5 | 0.0 | **100%** | 58.8 |
| NO_BOTH | 1.0 | 0.0 | **63.6%** | 80.0 |

### Conclusion

- Either **charge damage/push amplification** (~3 s window) **or** **charge cohesion shock** alone is sufficient to lock **100%** attacker wins in the frontal mirror.
- With both disabled, win rate returns to the plain infantry mirror (**63.6%**, combat ~80 s) — S1-like.
- **Hypothesis confirmed:** the ~3 s push/damage advantage at contact compounds through the push/cohesion death spiral into a decided battle. **Charge amplification is among the strongest single levers in the game; Phase 5 must treat it accordingly.** Shock is independently sufficient in this mirror; together they shorten fights further.

No constants or profiles were tuned.

---

## Task 4 — Matrix semantics + configuration column

- `tests/matchup_matrix.gd` header documents `FRONTAL_VS_STANDING`, archer inversion, Pierce brace, and mirror-cell caveat.
- CSV schema now: `configuration,attacker,defender,win_rate_pct,n,mean_combat_sec,mean_winner_str,mean_loser_str_at_rout` with `FRONTAL_VS_STANDING`.
- `docs/reports/evidence_wo023/matchup_matrix.md` carries the same semantics prominently.
- TD finding for Phase 5 backlog recorded above under Escalations.

Determinism: `MATRIX_DETERMINISM PASS` (396 rows).

---

## Task 5 — Regression lock

| Gate | Result |
|---|---|
| Smoke | exit 0 |
| Compass | exit 0 |
| Full suite | **exit 0** |
| Meta | **PASS=72 FAIL=0 expected_green_pass=72** |
| Fast cert | PASS (byte-identical) |
| Threaded cert | PASS (byte-identical) |
| S1 seed 12345 | combat **81.6 s** |
| S12 | unchanged (18 / 8.04% — see suite log) |
| S23–S29 spectrum | unchanged |
| perf_40 | MAIN_TICK p95 **44.577 ms** (canonical) |

Evidence: `docs/reports/evidence_wo023/`.

---

## Attestation

```
SHA: 7adcda4efee7d79f69e94d1871906b452cca799c
Suite: exit 0 ; Meta PASS=72 FAIL=0
Smoke: 0 ; Compass: 0 ; Matrix: 0 + DETERMINISM PASS
Task1: (b) measurement change; MAIN_TICK like-for-like WO-021≈57.5 / WO-023 suite 44.6
Task2: defect fixed (dest-exhausted head-on snap); 0/11 timeouts both cells
Task3: FULL/NO_AMP/NO_SHOCK=100%; NO_BOTH=63.6% — no tuning
Task4: FRONTAL_VS_STANDING documented + configuration column; Phase 5 TD finding recorded
Assumptions made: NONE
```
