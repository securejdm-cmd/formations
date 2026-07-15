# WO-021 Completion — The Test Hill: Slope & High Ground

**Branch:** `cursor/wo-021-test-hill-fd84`  
**SHA:** see footer / `evidence_wo021/commit_sha.txt`  
**Suite:** Meta PASS=70 FAIL=0 **exit 0**

---

## Task 1 — Height field

| Item | Value |
|------|-------|
| Cell size | **20 m** |
| Grid | 30 × 20 over 600×400 m battlefield |
| Geometry | Constant-grade ramp, west-low → east-high |
| Ramp span | x ∈ [−200, +200] m |
| Peak height | **40 m** |
| Design grade | **0.10** (Sec 7 reference) |
| Mid-ramp measured grade | **0.100** |
| Determinism | Same `HeightField` object sampled in fast/threaded/realtime via `SimBattleCore.refresh_slope_mods()` |

Facing **west = downhill**; facing **east = uphill**.

---

## Task 2 — Slope effects

Calibration ruling (10% grade = Sec 7 published values):

```
factor = 1 + bonus × (grade_along_axis / slope_reference_grade)
```

| Constant | Value | Role |
|----------|-------|------|
| `slope_reference_grade` | 0.10 | Sec 7 anchor |
| `slope_push_bonus` | 0.10 | ±10% push at ref grade |
| `slope_range_bonus` | 0.15 | ±15% missile range at ref grade |
| `slope_speed_bonus` | **0.35** | S37 sweep pick |
| `height_cell_m` | 20.0 | grid |

Movement: `slope_speed_mult` multiplies **top speed and accel/decel** in `ChargeCombat` (R6 emergent movement — **no charge-specific slope code**).

### S37 `slope_speed_bonus` sweep

| bonus | down_v | down_i | up_v | up_i | ratio |
|------:|-------:|-------:|-----:|-----:|------:|
| 0.15 | 12.144 | 19.547 | 10.404 | 16.746 | 1.167 |
| 0.20 | 12.384 | 19.933 | 10.128 | 16.302 | 1.223 |
| 0.25 | 12.675 | 20.402 | 9.810 | 15.790 | 1.292 |
| 0.30 | 12.870 | 20.716 | 9.450 | 15.211 | 1.362 |
| **0.35** | **13.122** | **21.121** | **8.775** | **14.124** | **1.495** |
| 0.40 | 13.356 | 21.498 | 8.100 | 13.038 | 1.649 |
| 0.45 | 13.659 | 21.986 | 7.425 | 11.951 | 1.840 |
| 0.50 | 13.860 | 22.309 | 6.750 | 10.865 | 2.053 |
| 0.55 | 14.043 | 22.604 | 6.075 | 9.778 | 2.312 |
| 0.60 | 14.304 | 23.024 | 5.400 | 8.692 | 2.649 |

**Committed:** lowest bonus meeting Impact(down)/Impact(up) ≥ 1.4 → **0.35**.

Charge-specific slope grep: **empty** (only shared movement `slope_speed_mult`).

---

## Task 3 — Rendering

- Shaded relief from height gradient (NW light; no lighting model / textures)
- Gallery exhibit: cropped relief + unit on slope (`visual_gallery.gd`)
- Render-only; traces unaffected (flat A/B proves)

---

## Task 4 — Scenarios (fast, seed 1000)

| ID | Expectation | Actual |
|----|-------------|--------|
| **S36** | Downhill wins push | displace **12.13 m** west; combat **50.0 s** (flat S1 ~81.6 s); routed blue_uphill |
| **S37** | Ratio ≥ 1.4 emerge from movement | down 13.122 / 21.121; up 8.775 / 14.124; **ratio 1.495** |
| **S38** | ±15% range at ref grade | down first **172.5 m**; up first **127.3 m** |
| **S39** | Defender holds from geometry | winner **blue_hold**; combat **64.0 s**; climb routed @ **67.25** |

---

## Task 5 — Regression

| Check | Result |
|-------|--------|
| Flat A/B absent vs present-flat | **byte-identical** (combat 81.6, ticks 2961) |
| S1–S34 | clean (S12 18/8.04%; S23–S29 unchanged) |
| Fast + Threaded certs | byte-identical |
| Contact coherence | holds |
| Perf40 p95 | **1.847 ms** (budget 50 ms); pre-merge main was 1.813 ms |

---

## Acceptance

- [x] Height grid; geometry + grade stated
- [x] Sec 7 calibration + scaling stated; constants in JSON
- [x] `slope_speed_bonus` via S37 sweep table
- [x] S36–S39 pass; S37 no charge-specific slope code
- [x] Shaded relief + gallery; traces unaffected
- [x] Flat A/B byte-identical; S1–S34 clean
- [x] Full suite exit 0, meta 70, evidence attached
- [x] Atomic code+report commit

---

## Attestation links

- Report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-021-test-hill-fd84/docs/reports/WO-021_completion.md
- Suite: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-021-test-hill-fd84/docs/reports/evidence_wo021/suite_stdout.log
- Sweep: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-021-test-hill-fd84/docs/reports/evidence_wo021/speed_sweep.log
- A/B: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/wo-021-test-hill-fd84/docs/reports/evidence_wo021/s1_height_ab.log
