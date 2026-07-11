# Simulation Symmetry Standard

*Established by TD ruling on WO-006 escalation, implemented in WO-007.*

## Per-unit RNG streams (accepted behavior)

Combat push wobble uses a single battle-seeded RNG consumed in deterministic call order. Each unit's push score draws from this stream on its turn. **Mirror-match winners are therefore not required to flip when starting sides swap** — outcomes are decided by seeded per-unit wobble and are position-independent in intent.

## Reflection symmetry (required)

For Scenario 1 normal vs side-swapped (mirrored) runs on the same seed, the simulation must satisfy **unit-keyed reflection**:

| Property | Requirement |
|----------|-------------|
| `strength` | Identical time series per `unit_id` (e.g. `red_1` normal == `red_1` mirror) |
| `cohesion` | Identical time series per `unit_id` |
| `kills` | Identical time series per `unit_id` |
| `state` | Identical per `unit_id` at each logged tick |
| `pos_x` | Reflected about map center: `normal.pos_x + mirror.pos_x ≈ 0` |
| `pos_y` | Identical per `unit_id` |
| Overlaps | Zero overlap assertion failures in **either** run |

Tolerance for automated tests: stats ±0.0001, positions ±0.05 px.

## What is NOT a defect

- Same team color winning in both normal and mirrored runs (per-unit RNG stream design).
- Slot-occupant winner flip failing while unit-keyed reflection passes.

## What IS a defect

- Diverging stat traces for the same `unit_id` under reflection.
- Position series that do not mirror about the axis.
- Overlap assertions in either normal or mirrored run.
