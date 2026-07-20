# WO-030 Completion Report — S8 Frontage Allocation + Restage

**Status:** COMPLETE  
**Branch:** `cursor/wo-030-s8-frontage-fd84`  
**Base:** WO-029b tip (`cursor/wo-029b-phase2-close-fd84`)

## Built

### Edge-interval allocation
- `EdgeContact.front_edge_interval_m` + `allocate_front_edge_frontage`: partition the defender FRONT edge among concurrent claimants so Σ occupied meters ≤ defender front width (equal split of overlaps; deterministic by `unit_id`).
- Head-on `combat_tick` path collects pairs, allocates per defender, passes ContactFrontage% into `CombatResolver.resolve_engagement`.
- Front-only segment jobs also receive allocated `attacker_frontage_pct`.

### S8 restage (Option B)
- Attackers spawn **side-by-side** on one FRONT edge (`side_by_side_spacing_m=12`).
- Tracks `max_defender_partners` (peak concurrent contact).

### S8b sequential depth check
- New `scenario_08b`: legacy depth-column layout.
- Asserts `max_defender_partners ≤ 1` and `multi_partner_ticks == 0`.
- Suite check `[WO-030] S8b`; `EXPECTED_GREEN_PASS_COUNT=74`.

## Files changed
- `scripts/edge_contact.gd` — interval + allocate
- `scripts/combat_resolver.gd` — `resolve_engagement(..., frontage_a, frontage_b)`
- `scripts/sim/sim_battle_core.gd` — allocate before head-on / front-segment resolve
- `scripts/scenario_08.gd` — side-by-side restage + partner peak
- `scripts/scenario_08b.gd`, `tests/scenario_08b.tscn` — sequential depth column
- `tests/scenario_wo010_autotest.gd` — S8/S8b checks; pass count 74
- `tests/wo030_s8_sweep.gd`, `tests/wo030_run_s8_sweep.sh`, `tests/wo030_s8b_smoke.gd`
- `docs/reports/evidence_wo030/*`, `docs/reports/WO-030_completion.md`

## Tests

| criterion | result |
|-----------|--------|
| Edge-interval allocation: Σ front meters ≤ defender front | PASS (by construction) |
| S8 restaged side-by-side on one FRONT edge | PASS |
| S8 DIRECTION n=500 ge3=0 (QoD σ=0.045) | PASS — see numbers |
| S8b sequential: max_partners≤1 | PASS (suite + smoke) |
| Full suite Meta PASS=74 FAIL=0 | PASS (branch) |

### S8 n=500 numbers (post-fix)
`ratio n=500 mean=0.877121 sd=0.322595 cv=0.3678 min=0.504600 max=1.633570 ge3=0`

### Suite (branch)
`Meta PASS=74 FAIL=0 exit=0`

## Assumptions made
NONE.

## Known issues
none
