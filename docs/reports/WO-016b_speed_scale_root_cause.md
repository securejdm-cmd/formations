# WO-016b Speed-Scale Root Cause (record for TD)

**Purpose:** TD never received the WO-016b report; this note closes the
scale-bug family for the permanent record.

## Symptom

Charge Impact landed ~6.4 instead of the design ~21.6 for Speed-40 cavalry,
understating gallop by ~3–4×.

## Root cause (not a per-tick mismatch)

Movement and measured `current_speed_m_s` were internally consistent:

```
sim_m_s = speed_stat × speed_stat_meters_per_10s / 10
```

With `speed_stat_meters_per_10s = 1.0`, Speed 40 → **4.0 sim-m/s**. That
constant was calibrated for **infantry walk** (~1.5 m/s at Speed 15). Absolute
SI for cavalry gallop (12–15 m/s) is understated by **~3.375×**.

Same family as other “scale-bug” calibrations: correct internal units, wrong
absolute meter.

## Rejected fix

Raising the **global** movement constant to 3.375 made closing report 13.5 m/s
but shortened approach windows and failed **S12** (volleys 18→6, approach_lost
8%→2.7%).

## Adopted fix (WO-016b)

- Keep movement at `speed_stat_meters_per_10s = 1.0` (approach-timing lock).
- Add `charge_speed_si_scale = 3.375` for Impact, `charge_min_speed` (SI), and
  reported `closing_speed`.
- Events also store `closing_speed_sim`.

| Quantity | Value |
|----------|-------|
| Cavalry top sim | 4.0 m/s |
| Cavalry top SI (`×3.375`) | **13.5 m/s** |
| Impact | mass 1.6 × 13.5 × Strength% 1.0 × scale 1.0 = **21.6** |

Full report: `docs/reports/WO-016b_completion.md` (branch
`cursor/wo-016b-charge-scale-r15-fd84`).
