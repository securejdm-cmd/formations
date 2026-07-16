# Evidence — WO-026

| Artifact | Notes |
|----------|-------|
| `compare_disable.log` | Task 1 micro-profile baseline + Task 2 disable-commit probe |
| `profile_after_fix.log` | Post-fix PROFILE breakdown |
| `gameplay_tick_after.log` | GAMEPLAY_TICK ×5 variance after fix |
| `suite_stdout.log` / `suite_stderr.log` / `suite_exit.txt` | Meta 72/0 exit 0 |
| `key_lines.log` | Certs, S1, S29, GATE, Meta |

```bash
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/wo026_movement_probe.gd -- COMPARE_DISABLE
$GODOT --headless --path . -s res://tests/wo026_movement_probe.gd -- PROFILE
$GODOT --headless --path . -s res://tests/wo026_movement_probe.gd -- REPEAT_GAMEPLAY
$GODOT --headless --path . -s res://tests/scenario_wo010_autotest.gd
# EXIT=0
```
