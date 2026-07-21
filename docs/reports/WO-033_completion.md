# COMPLETION REPORT — WO-033 Full Elevation & Feigned Retreat

- **Work order:** WO-033 — Full Elevation & Feigned Retreat: Closing the Sim Layer
- **Built:** General multi-feature height field (bilinear 20m cells); Sec 7 effects verified emergent; S49–S51; hardened `feign_retreat` with fighting-withdrawal + deception window; S52–S54; Task 0 order-path micro-profile (report-only).
- **Files changed (high level):**
  - `docs/work_orders/WORK_ORDER_033.md`, this report
  - `scripts/height_field.gd` — `make_from_features` / ridge / valley / cross_slope / gaussian
  - `data/combat_constants.json` — `feign_deception_window_s: 2.0`
  - `scripts/orders/order_executor.gd` — feign harden + Task 0 counters
  - `scripts/sim/sim_unit_proxy.gd` — `get_enemy_visible_state()`, feign flags
  - `scripts/sim/sim_battle_core.gd` — profiled `orders` section
  - `scripts/scenario_49.gd` … `54.gd` + tscn; suite + probes
  - `docs/ORDER_SCHEMA.md` — feign deception note
- **Tests:** Meta **PASS=88 FAIL=0 exit=0**
  - Task 0: orders path ≈ **0.0009 ms/tick**; trigger/step/emit/alloc counts **all 0** on pitched no-order; residual in `movement` (~9.4ms) + `allied_separation` (~10.3ms) — **held** (non-trivial)
  - Sampling: **bilinear** (smooth along-axis grades; nearest would stair-step Sec 7 at cell edges)
  - Charge-slope grep: only shared `slope_speed_mult` in `target_speed_m_s` / accel — **no charge-specific slope code**
  - S51 calibration @ 10%: speed **1.35** / push **1.10** / range **1.15**
  - S49 ridge wins **7/11**; S50 valley beat_v/i **11/11** (mean Δv≈2.21, Δi≈3.56); S51 edge+slope compose; S52 feint sprung **11/11**; S53 routs **11/11**; S54 deception window tick-by-tick PASS
  - GAMEPLAY_TICK p95 ≈ **31.6–32.0** (gate PASS)
- **Assumptions made:** NONE
- **Known issues:** none blocking
- **Proposed tag (for TD confirmation):** `v0.3-sim-complete`

## Deception representation (stated)

- True sim: `feign_active` + ordered state (never ROUTING unless cohesion breaks).
- Enemy-visible: `get_enemy_visible_state()` returns `ROUTING` while `feign_deception_remaining_s > 0`.
- `unit_routs` checks `get_state() == ROUTING` only → **never fires on a feint**.
- After the window: enemy-visible matches true ordered state (“still ordered”).

## WO-032 merge SHA (prerequisite)

`df2d96eb4814ebd2c15c5d8c34e0ff43379cd30b`
