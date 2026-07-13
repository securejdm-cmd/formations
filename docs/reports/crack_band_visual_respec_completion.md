# Completion Report — Crack Band Visual Respec (TD Directive)

**Status:** COMPLETE  
**Branch:** `cursor/crack-band-visual-respec-fd84`  
**Scope:** Render-only; supersedes polyline crack fissures and WO-005 front-face recession offset.

## Summary

Replaced polyline crack fissures and rear-anchored front recession with a **strength%-driven crack band** (voronoi/noise shader) anchored at the engaged front edge. Rendered footprint now uses **centered shrink** matching sim collision. Visual gallery respec includes crack progression exhibit at 100/90/70/50/30% strength.

## Built

1. **Crack band** — `shaders/crack_band.gdshader`: procedural dried-earth fractures; `band_depth = (1 − Strength%) × rendered_depth × crack_band_gain` (gain = 1.0); irregular rear boundary via noise; deterministic `render_seed = hash(unit_id)`; static (no shimmer).
2. **Layering** — Body → [future unit symbols below crack — code comment] → CrackBand → GrindBand → Border.
3. **Centered render** — Removed `thinning_visual_gain` and front-face recession offset; `_body` centered on sim footprint.
4. **Gallery** — Neutral gray backdrop; 60 m frontage (~120 px at 2 px/m); crack row at 100/90/70/50/30%; grind pair + state row; captions below exhibits.
5. **Constants** — Added `crack_band_gain`, `crack_band_edge_wobble`; removed obsolete fissure/thinning keys.

## Files changed

| File | Change |
|------|--------|
| `shaders/crack_band.gdshader` | New procedural crack band shader |
| `scripts/unit.gd` | Crack band ColorRect; centered render; remove polyline/recession |
| `scripts/visual_gallery.gd` | Crack progression + layout respec |
| `tests/visual_gallery.tscn` | Neutral backdrop color |
| `data/combat_constants.json` | crack_band_gain / edge_wobble |
| `scripts/sim/sim_unit_proxy.gd` | No-op crack intensity sync |
| `tests/wo001_smoke_test.gd` | Updated required constant keys |

## Tests

| Criterion | Result |
|-----------|--------|
| Universal scene smoke (14 `.tscn`, incl. gallery) | **PASS** |
| Fast vs threaded trace byte-identical (`wo011_trace_diff`) | **PASS** (627 lines) |
| Sim regression impact | **None** (render-only) |

## Assumptions made

NONE.

## Known issues

None.

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/cursor/crack-band-visual-respec-fd84/docs/reports/crack_band_visual_respec_completion.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/WO-012_completion_report.md
