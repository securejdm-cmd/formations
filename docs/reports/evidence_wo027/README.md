# Evidence — WO-027

| Artifact | Notes |
|----------|-------|
| `qod_sweep.md` / `.csv` | Master n=500 table + selection |
| `sweep_sigma_*.log` / `qod_sweep_sigma_*` | Per-σ worker outputs |
| `sweep_baseline.log` / `qod_sweep_baseline.*` | Task 3 0% QoD-off |
| `slot_swap_seed1000.log` | SLOT-SWAP guard |
| `boundary_probe.log` / `boundary_focus.log` / `s3_sigma_grid.log` | Task 4 |
| `suite_stdout.log` | Meta 73/0 exit 0 |

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
# Parallel sweep (example)
$GODOT --headless -s tests/wo027_qod_sweep.gd -- SIGMA=0.045
$GODOT --headless -s tests/wo027_slot_swap.gd -- SEED=1000
WO_SKIP_NESTED_GODOT=1 $GODOT --headless -s tests/scenario_wo010_autotest.gd
# EXIT=0
```
