# COMPLETION REPORT — WO-034 The Deployment Screen

- **Work order:** WO-034 — The Deployment Screen (Phase 3 UI)
- **Built:** Designer deployment screen over frozen sim. Battle JSON (`data/battles/wo034_pitched_deploy.json`) binds to ORDER_SCHEMA unit records (`position_m`, `facing`, frontage/depth, queues). Drag/place/rotate/width/remove + zone/overlap validation; presets LINE / COLUMN / REFUSED_FLANK; Ready serializes and hands off to `ScenarioFromData` (default `attack_nearest`) on the existing sim-thread seam. Height relief + terrain patches + enemy zones visible (R25 v1).
- **Files changed (high level):**
  - `docs/SIM_COMPLETE_MILESTONE.txt`, `docs/work_orders/WORK_ORDER_034.md`, this report
  - `data/battles/wo034_pitched_deploy.json`
  - `scripts/battle_scenario_data.gd`, `scripts/scenario_from_data.gd`, `scripts/ui/deployment_*.gd`
  - `scenes/deployment_screen.tscn` (project main scene), `tests/scenario_from_data.tscn`
  - `tests/wo034_deploy_roundtrip.gd`, suite `EXPECTED_GREEN_PASS_COUNT=89`
  - `docs/ORDER_SCHEMA.md` — placement fields documented
- **Tests:**
  - UI-deploy == hand-authored serialize + tick-0 core fingerprint → **PASS**
  - Deployment scene smoke load → **PASS**; deploy static (no sim on render thread)
  - Presets shipped: **LINE, COLUMN, REFUSED_FLANK**
  - Sampling/footprint: width holds area (Combat Core 3.7); frontage clamps from battle `formation_bounds` 20–80m
  - Headless suite meta expected **PASS=89**; GAMEPLAY_TICK unchanged path (perf_40 after WO-034 check)
  - frontend-design: `/mnt/skills/public/frontend-design/SKILL.md` **not present in environment**; styling followed project frontend-design user-rule constraints (earth campaign palette, brand-first FORMATIONS hero, map as dominant plane, no purple/cream AI defaults)
- **Assumptions made:** NONE (frontage min/max and snap_m are **battle-authored** in the provided battle JSON, not silent globals)
- **Known issues:** Designer hand-confirm checklist is the real gate (TD cannot see UI). Touch not the gate.
- **How to test (designer):**
  1. Open project; F5 runs `scenes/deployment_screen.tscn`.
  2. Click a roster unit, click inside the blue zone (or use LINE/COLUMN/REFUSED_FLANK).
  3. Select a unit: drag to move, R or right-drag to face, width slider for wide-vs-deep.
  4. Press READY / DEPLOY — battle starts with default attack_nearest on the sim thread.
  5. Confirm ~60 FPS on deploy (static) and during battle on your hardware.

## Designer hand-confirm (unchecked — awaiting designer)

- [ ] Drag-place, rotate, re-space in zone
- [ ] Wider/deeper footprint change
- [ ] Presets editable after apply
- [ ] Ready → real battle
- [ ] Readable at deploy zoom; 60 FPS
