# WO-029b Task 1 — S40 frame-rate diagnosis (profile before fix)

## (a) Threading — which thread advances the tick?

| path | `use_sim_thread` | advances tick on |
|------|------------------|------------------|
| **Pre-WO-029b designer realtime** | `false` (old default) | **main / render thread** via `_process` → `advance_one_tick()` |
| **WO-029b designer realtime** | `true` (new default) | **sim worker thread** (WO-011 `SimThreadController`) |
| Suite fast cert | forced `false` + `fast_sim_mode` | main (harness-driven) |

Designer 20–35 FPS matches main-thread GAMEPLAY_TICK ≈27ms (1000/27≈37; plus render ⇒ 20–35).

Evidence: `s40_thread_diag.log`.

## (b) Render vs sim (cloud)

Cloud is headless/Xvfb — not the designer GPU. Breakdown:

| cost | cloud proxy | notes |
|------|------------:|-------|
| SIM on main at grind | p95 ≈ 3.5ms | cloud CPU ≪ designer; designer GAMEPLAY_TICK p95≈27ms |
| SIM on worker at grind | p95 ≈ 2.7ms | overlaps render |
| MAIN frame with worker | p95 ≈ 0.33ms | snapshot apply only |
| Xvfb display frame (thread on) | p95 ≈ 10.5ms ⇒ **~95 FPS** | crack/grind/relief/stat/arcs included in frame |
| Crack-band / grind / relief / cards / arcs | no separate GPU timers in headless | none dominate once sim leaves the main thread |

**Conclusion:** Frame cost was **sim-on-main**, not a single render effect. Fix = route realtime onto the sim thread.

## (c) Distributions (labeled)

### Cloud proxy — SIM (grind window)

- MAIN path: min/avg/p95/max = 2.472 / 2.950 / 3.530 / 4.022 ms (n=200)
- THREAD path: min/avg/p95/max = 1.198 / 2.004 / 2.680 / 3.622 ms (n=1902)

### Cloud proxy — RENDER / main frame

- THREAD main frame: min/avg/p95/max = 0.242 / 0.290 / 0.326 / 0.879 ms
- Xvfb designer path (windowed, `use_sim_thread=true`): frame p95=10.544 ms, fps_from_p95≈94.8

### Designer-class (reported by designer, pre-fix)

- Realtime S40: **20–35 FPS** with sim on main (GAMEPLAY_TICK≈27ms)

### Designer validation build/scene

Open `res://tests/scenario_40_mixed.tscn` (or run that scene) on the designer desktop after pulling this branch. Confirm FPS overlay ≥60 sustained mid-battle. `use_sim_thread` defaults **true**.
