# Evidence — WO-025

| Artifact | Notes |
|----------|-------|
| `S3_REBASELINE.md` / `s3_metrics_before.log` | Flank metrics confirmed pre-R21 |
| `anomaly_diag.log` / `ANOMALY_0PCT.md` | 0% cell = slot/RNG-order bias |
| `qod_sweep.md` / `.csv` / `_stdout.log` | 33-seed σ sweep → no width |
| `boundary_probe.log` | Maneuver spot-check σ=0.05 |
| `gameplay_tick.log` | GAMEPLAY_TICK with QoD off |
| `suite_stdout.log` | exit 0, Meta 72/0 |

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# EXIT=0
```
