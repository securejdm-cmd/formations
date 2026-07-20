# COMPLETION REPORT — WO-032 Concealment & Ambush

- **Work order:** WO-032 — Concealment & Ambush
- **Built:** Sec 10 concealment terrain (FOREST/SHRUB rects), fit-rule starting posture, asymmetric enemy invisibility, detection (base × profile × moving×2, center-to-center), permanent reveal events, forest cav −40% / over-wide drain / missile −25% symmetric, brace clock from reveal, Teutoburg S45 + matrix S46–S48, sticky one-shot `orders_armed` empty-queue skip.
- **Files changed:**
  - `data/combat_constants.json` — detection, profile mults, forest penalties, over-wide 40m / 2.0/s
  - `scripts/concealment.gd` — Sec 10 helpers
  - `scripts/sim/sim_battle_core.gd` — patches, reveal, visibility filters, penalties, orders_armed
  - `scripts/sim/sim_unit_proxy.gd`, `scripts/unit.gd` — concealment fields
  - `scripts/orders/order_executor.gd` — `_is_living_enemy` hides concealed from enemy triggers/seek
  - `scripts/scenario_01.gd` — terrain patch API + darker-green render
  - `scripts/scenario_45.gd` … `48.gd` + `tests/scenario_45.tscn` … `48.tscn`
  - `tests/scenario_wo010_autotest.gd` — S45–S48 chain; `EXPECTED_GREEN_PASS_COUNT=82`
  - `tests/wo032_perf40_runs.gd`, `tests/wo032_probe.gd`
  - `docs/ORDER_SCHEMA.md`, `docs/reports/WO-032_escalation.md`, this report
- **Tests:**
  - Sec 10 radii/profile/move/reveal/fit/penalties → **PASS** (S46–S48)
  - Concealed invisible to enemy auto-behaviors + `enemy_within` / `attack_*` → **PASS** (stated impl; S45)
  - Brace clock from reveal; S45 Tier 3 → **PASS** (11/11)
  - S45 stealth margin vs visible control → **PASS** (avg ≈ 53 cohesion points)
  - S46 center-to-center matrix 12/12 + Massive reject → **PASS**
  - S47 fit + permanence → **PASS**
  - S48 cav 2.4/4.0 (=0.6), over-wide drain, missile 0.75× both ways → **PASS**
  - S1–S44 regression / suite → **PASS** Meta **PASS=82 FAIL=0 exit=0**
  - GAMEPLAY_TICK 5-run (sticky skip): vals `[29.838, 30.023, 29.963, 30.012, 29.929]` min=29.838 max=30.023 mean=29.953 span=0.185
- **Assumptions made:** NONE (1A/2A + six stated impls green-lit)
- **Known issues:** none blocking. Residual GAMEPLAY_TICK vs pre–WO-031 ~26.9 is not empty-executor cost after one-shot skip (report below). R26 still drafted, not appended.

## Stated implementations (as shipped)

1. **Asymmetric visibility:** `enemies_for` + volley/dead-zone filters + `OrderExecutor._is_living_enemy` omit concealed enemies. Own-side triggers still see living enemies.
2. **Brace clock from reveal:** concealed chargers absent from defender `enemies` → `_threat_front_sec` starts only after reveal.
3. **Moving:** `current_speed_m_s > brace_stationary_speed`.
4. **Detection:** center-to-center via `ChargeCombat.distance_m`; S46 asserts the same reference (got == expected on 0.5m steps).
5. **Cavalry forest slow:** `profile == High` → `forest_cavalry_speed_mult` (0.6) folded into `slope_speed_mult`.
6. **Empty queues:** one-shot `orders_scan_done` + sticky `orders_armed`; no per-tick unit walk when unarmed.

## Perf carry (WO-031 → WO-032)

- Root cause of 26.887→31.834: every tick called `activate_if_needed()` which scanned all units even with zero queues.
- Fix: army-wide one-shot scan; thereafter empty path is a bool check only.
- 5-run variance after fix: span **0.185 ms**; mean p95 **~29.95**. Autotest GAMEPLAY_TICK_p95 on suite run ≈ **32.6** (PASS ≤50). Remaining ~3–6 ms vs historical 26.9 is not the empty-executor path (held; not trivial further).

## Green-light constants

- `forest_overwide_frontage_m = 40.0`
- `forest_overwide_cohesion_drain_per_sec = 2.0`
