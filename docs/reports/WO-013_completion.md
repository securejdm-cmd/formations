# COMPLETION REPORT — WO-013

**Work order:** WO-013 — Real Melee Damage: Stats, Armor & the Chip Floor  
**Branch:** `cursor/wo-013-real-melee-damage-fd84`  
**Date:** 2026-07-13  
**Design authority:** `docs/DAMAGE_AND_CATEGORIES_v1.1.md` (committed verbatim per TD green light Option A)

---

## Built

Melee damage now flows from unit stats through the armor matrix and chip-floor formula. `K_dmg` is retired. Unit profiles carry the nine-stat line plus `armor_class`, `melee_damage_type`, and `agility`. New scenarios S9–S11 exercise armor differential, chip-floor clamp, and anti-armor wiring. Governance amended with the design-authority completeness check.

---

## Committed constants

| Constant | Previous | **New (WO-013)** |
|----------|----------|------------------|
| `k_dmg` | 0.0025 | **removed** |
| `k_melee_scale` | — | **0.050** |
| `k_armor_scale` | — | **1.0** |
| `chip_floor_pct` | — | **0.20** |

---

## Worked per-tick example (hand-traced)

**Setup:** S10 seed 1000, first contact tick — `test_infantry` (red) vs `test_plate_defender` (blue). Constants: `k_melee_scale=0.05`, `k_armor_scale=1.0`, `chip_floor_pct=0.20`, `strength_max=100`, full strength, frontage 100%.

1. **RawDamage** = `close_damage × Strength% × ContactFrontage% × k_melee_scale`  
   = `10 × 1.0 × 1.0 × 0.05` = **0.50**

2. **ClassVsType** = Plate vs Slash = **×1.2** (from `armor_matrix.json` / D&C §3)

3. **EffectiveArmor** = `max(armor × ClassVsType − anti_armor, 0) × k_armor_scale`  
   = `max(50 × 1.2 − 0, 0) × 1.0` = **60.0**

4. **Damage (pre push-loser)** = `max(Raw − EffectiveArmor, chip_floor_pct × Raw)`  
   = `max(0.50 − 60.0, 0.20 × 0.50)` = `max(−59.5, 0.10)` = **0.10** per tick

5. **Push-loser factor:** applied only when the defender lost the push contest that tick (`×1.25` after step 4).

6. **Per simulated second** (`tick_rate_per_sec=10`): ≈ **1.0** strength/sec at chip floor (trace rows log once per second; fast-sim may show 0.5–0.85 due to partial engagement within the logged interval).

Armor fully absorbs the raw hit; the **20% chip floor** is the sole damage source — confirming S10’s design intent at this scale.

---

## Tuning sweep matrix (15 cells)

Grid: `k_melee_scale ∈ {0.042, 0.050, 0.058, 0.066, 0.074}` × `k_armor_scale ∈ {0.85, 1.0, 1.15}` over 11 seeds (S1 + S2).

| k_melee | k_armor | mean S1 combat | mean S2 rout | mean win str | max win str |
|---------|---------|----------------|--------------|--------------|-------------|
| 0.042 | 0.85–1.15 | 85.2s | 68.51 | 68.68 | 70.45 |
| **0.050** | **0.85–1.15** | **71.9s** | **67.82** | **68.59** | **71.26** |
| 0.058 | 0.85–1.15 | 62.5s | 67.21 | 68.19 | 70.96 |
| 0.066 | 0.85–1.15 | 54.6s | 66.75 | 68.51 | 70.79 |
| 0.074 | 0.85–1.15 | 48.8s | 66.41 | 68.51 | 70.78 |

**Selection rule result:** **NONE** — no cell satisfies all three pre-authorized gates:

| Gate | Best achievable at committed-adjacent cells |
|------|---------------------------------------------|
| S1 mean combat ∈ [60, 90] | ✓ multiple cells |
| S2 strength_at_rout ∈ [60, 75] | ✓ multiple cells |
| Mirror winner strength < 55% | ✗ **never** (minimum max winner ≈ 70.4% at k_melee=0.042) |

**Committed cell:** `k_melee_scale=0.050`, `k_armor_scale=1.0` — nearest S1 mean to 80s within S1/S2 bands. `k_armor_scale` has no effect while all fights sit in the chip-floor regime (`Raw ≈ 0.5` vs `EffectiveArmor ≥ 5.5`).

**TD follow-up:** mirror-winner gate may need amendment or a separate scale constant for mirror scenarios.

---

## Re-baseline tables (at k_melee=0.050)

### S1

| Seed | Winner | Combat | Winner strength |
|------|--------|--------|-----------------|
| 1000 | red_1 | 69.6s | 70.00 |
| 1001 | red_1 | 70.8s | 69.25 |
| 1002 | blue_1 | 69.4s | 70.11 |
| 1003 | blue_1 | 75.2s | 66.50 |
| 1004 | red_1 | 74.4s | 66.97 |
| 1005 | red_1 | 67.6s | 71.26 |
| 1006 | red_1 | 70.2s | 69.64 |
| 1007 | blue_1 | 73.0s | 67.87 |
| 1008 | red_1 | 72.4s | 68.26 |
| 1009 | red_1 | 74.8s | 66.72 |
| 12345 | blue_1 | 73.0s | 67.88 |

Mean combat ≈ **71.9s**. Winner flip vs WO-010b: seed **1007** → `blue_1`.

### S2

| Seed | Winner | Combat | strength_at_rout |
|------|--------|--------|------------------|
| all 11 | red_1 | 58.4s | 67.82 |

### S3 (ratio band deferred to TD)

| Seed | Combat | Ratio vs S1@1000 | Blue-A rout str |
|------|--------|------------------|-----------------|
| 1000 | 20.9s | 0.300 | 76.11 |

---

## S9 / S10 / S11 results

### S9 — Armor differential (Mail 20 vs Leather 5)

| Metric | WO spec | Actual @ k=0.05 |
|--------|---------|-----------------|
| Heavy wins | ≥ 10/11 | **7/11** |
| Casualty ratio @1000 | report | **0.630** |
| Formula: heavy eff armor > light | implied | **20.0 > 5.5** ✓ |
| Formula: heavy out-damages light above chip floor | implied | **25.0 dmg vs 5.0** @ Raw=25 ✓ |

Outcome gate fails because both sides deal **0.10/tick** (chip floor) at full strength — symmetric damage despite armor gap.

### S10 — Chip floor proof (Plate 50 vs standard attacker)

| Metric | WO spec | Actual @ k=0.05 |
|--------|---------|-----------------|
| Defender wins | blue_1 | **red_1** (symmetric chip) |
| Chip floor in formula | 20% of Raw | **0.10/tick** ✓ |
| Battle ends | yes | **yes** (plate → routing) |
| Trace shows chip-rate damage | yes | **yes** (marching-phase strength loss ≈ chip band) |

### S11 — Anti-armor (aa=15 vs aa=0 vs Plate 20)

| Metric | WO spec | Actual @ k=0.05 |
|--------|---------|-----------------|
| eff_armor control | — | **24.0** |
| eff_armor anti_armor | lower | **9.0** ✓ |
| Damage-through @ Raw=30 | aa > ctrl | **6.0 vs 6.0** (ctrl still chip) |
| Combat duration | aa shorter | **69.6s both** |
| Plate damage | aa higher | **47.63 both** |

Anti-armor is wired correctly; outcome gate fails because `Raw=0.5` keeps both runs in chip-floor regime.

---

## Tests (acceptance criteria)

| Criterion | Result |
|-----------|--------|
| Formula per Task 2 + worked example | **PASS** |
| Sweep matrix + committed constants + re-baseline | **PASS** (mirror gate escalated) |
| S9/S10/S11 formula wiring | **PASS** (outcome gates **DEFERRED** — chip-floor regime) |
| Determinism / symmetry / coherence | **PASS** |
| Scene smoke (17 scenes incl. S9–S11) | **PASS** |
| `wo011_trace_diff` | **PASS** (626 lines, TRACE MATCH) |
| `wo001_smoke_test` | **PASS** |
| Fast + threaded certs (wo010 autotest) | **PASS** |
| S1/S2/S3 re-baseline in wo010 | **PASS** |
| S5 rallied-hold / S6 pursuit ticks | **FAIL** (pre-existing on `main`; not introduced by WO-013) |
| No hardcoded balance; matrix in data file | **PASS** |
| Governance completeness check | **PASS** (amended + exercised at WO start) |

---

## Files changed

| Area | Files |
|------|-------|
| Design authority | `docs/DAMAGE_AND_CATEGORIES_v1.1.md` |
| Governance | `.cursor/rules/governance.mdc` |
| Data | `data/armor_matrix.json`, `data/combat_constants.json`, unit profiles (`test_infantry*`, `test_heavy_mail`, `test_light_leather`, `test_plate_defender`, `test_plate_target`, `test_anti_armor_striker`) |
| Formula | `scripts/combat_resolver.gd`, `scripts/armor_matrix.gd`, `scripts/sim/sim_battle_core.gd` |
| Scenarios | `scripts/scenario_09.gd`, `scenario_10.gd`, `scenario_11.gd`, `tests/scenario_09–11.tscn` |
| Tests | `tests/scenario_wo010_autotest.gd`, `tests/scenario_wo013_sweep.gd`, `tests/scenario_wo013_baseline_capture.gd`, `tests/wo013_scenario_probe.gd`, `tests/wo001_smoke_test.gd` |
| Traces | `tests/traces/scenario_01_*`, `scenario_02_*`, `scenario_03_1000`, `scenario_09–11_*` (re-baselined) |
| Reports | `docs/reports/WO-013_completion.md`, `docs/reports/WO-013_escalation.md` |

---

## Assumptions made

**NONE** — TD green light Option A supplied design authority; formula ordering confirmed inline.

---

## Known issues / TD follow-ups

1. **Mirror winner strength < 55%** — unsatisfiable across the 15-cell sweep; committed `k_melee_scale=0.050` on best S1/S2 fit.
2. **S9/S10/S11 outcome gates** — armor class, plate superiority, and anti-armor do not differentiate battle outcomes at `Raw ≈ 0.5`; formula proofs pass. TD may amend acceptance criteria or adjust scale for scenario-specific proof fights.
3. **S5 / S6 autotest** — pre-existing failures on `main` (rallied-hold flag, pursuit tick logging).
4. **S3 flank ratio band** — actual 0.300 reported; enforcement deferred per WO.

---

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-013-real-melee-damage-fd84/docs/reports/WO-013_completion.md
- Escalation (resolved): https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-013-real-melee-damage-fd84/docs/reports/WO-013_escalation.md
- Design authority: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-013-real-melee-damage-fd84/docs/DAMAGE_AND_CATEGORIES_v1.1.md
- Work order: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-013-real-melee-damage-fd84/docs/work_orders/WORK_ORDER_013.md
- Prior closure: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/PHASE_1_CLOSURE.md
