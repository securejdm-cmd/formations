# WO-016 evidence

| Artifact | Command | Exit |
|----------|---------|------|
| `suite_*` | `$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd` | 0 |
| `smoke_stdout.log` | `$GODOT --headless --path . -s res://tests/wo001_smoke_test.gd` | 0 |
| `scene_smoke_stdout.log` | `$GODOT --headless --path . -s res://tests/all_scenes_smoke_test.gd` | 0 |

`GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64`

Baseline: main post-WO-015 `docs/reports/evidence_main_wo015_merge/` suite exit 0.

`suite_stderr.log` may be truncated in the middle (Constants reload / PerfScale overlap noise); PASS/FAIL lives in `suite_stdout.log`.
