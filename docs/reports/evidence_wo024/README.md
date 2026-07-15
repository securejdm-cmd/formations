# Evidence — WO-024

| Artifact | Command | Exit |
|----------|---------|------|
| `suite_stdout.log` / `suite_stderr.log` / `suite_exit.txt` | `$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd` | **0** |
| `perf_repeat.log` | `$GODOT … -s res://tests/wo024_gameplay_tick_probe.gd -- REPEAT_BOTH` | 0 |
| `perf_profile.log` | `$GODOT … -s res://tests/wo024_gameplay_tick_probe.gd -- PROFILE` | 0 |
| `gravity_focus.log` | `$GODOT … -s res://tests/wo024_gravity_focus.gd` | 0 |
| `gravity_ab.log` | `$GODOT … -s res://tests/wo024_gravity_ab.gd` | 2 (S3 non-identical — escalated) |
| `s3_grav_diff.log` | `$GODOT … -s res://tests/wo024_s3_diff.gd` | 0 |
| `sensitivity_*.log/csv/md` | `$GODOT … -s res://tests/wo024_sensitivity_curve.gd` | 0 |
| `matrix_*.log` + `matchup_matrix.*` | `$GODOT … -s res://tests/matchup_matrix.gd` (outputs redirected to this dir) | 0 |

`GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64`
