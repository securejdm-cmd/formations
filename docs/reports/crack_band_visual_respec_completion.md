# Completion Report — Crack Band Visual Respec (TD Directive)

**Status:** COMPLETE — visual amendment series closed  
**Branch:** `cursor/crack-band-visual-respec-fd84`  
**Scope:** Render-only; supersedes polyline crack fissures and WO-005 front-face recession offset.

## TD ruling (closing)

| Aspect | Verdict |
|--------|---------|
| Crack band **mechanic** (growth, anchoring, layering) | **APPROVED** |
| Texture fidelity | **DEFERRED** → Phase 6 (`docs/BACKLOG.md` P6-TEXTURE-001) |
| Front-face recession offset | **REMOVED** — confirmed (see below) |
| Gallery captions | **FIXED** — world-space anchor per exhibit |

## Summary

Replaced polyline crack fissures and rear-anchored front recession with a **strength%-driven crack band** (voronoi/noise shader) anchored at the engaged front edge. Rendered footprint uses **centered shrink** matching sim collision. Visual gallery includes crack progression exhibit at 100/90/70/50/30% strength.

## Front-face recession — confirmed removed

Render body placement in `scripts/unit.gd` `_update_dimensions()`:

```gdscript
# Centered shrink: rendered footprint matches sim footprint (no front-face recession).
_body.size = Vector2(depth_px, frontage_px)
_body.position = Vector2(-depth_px * 0.5, -frontage_px * 0.5)
```

- No `front_face_x`, no `full_depth_px` rear-anchor, no `thinning_visual_gain`.
- Collision shape uses `effective_depth_m()` centered on unit origin (unchanged sim footprint).

## Built

1. **Crack band** — `shaders/crack_band.gdshader`: procedural dried-earth fractures; `band_depth = (1 − Strength%) × rendered_depth × crack_band_gain` (gain = 1.0); irregular rear boundary; deterministic `render_seed = hash(unit_id)`.
2. **Layering** — Body → [future unit symbols below crack] → CrackBand → GrindBand → Border.
3. **Gallery** — Neutral backdrop; 60 m frontage (~120 px); crack row 100/90/70/50/30%; per-exhibit captions in world space below each unit.
4. **Backlog** — `docs/BACKLOG.md` P6-TEXTURE-001; reference sketch `docs/reference/crack_band_earth_reference.svg`.
5. **Scene smoke** — `tests/all_scenes_smoke_test.gd` (14 `.tscn`, permanent gate).

## Files changed

| File | Change |
|------|--------|
| `shaders/crack_band.gdshader` | Procedural crack band shader |
| `scripts/unit.gd` | Crack band; centered render |
| `scripts/visual_gallery.gd` | Crack row; world-space captions |
| `tests/visual_gallery.tscn` | Neutral backdrop |
| `tests/all_scenes_smoke_test.gd` | Universal scene smoke |
| `tests/scenario_wo010_autotest.gd` | Scene smoke wired first |
| `.cursor/rules/governance.mdc` | Scene smoke gate |
| `data/combat_constants.json` | crack_band_gain / edge_wobble |
| `docs/BACKLOG.md` | P6-TEXTURE-001 deferred item |
| `docs/reference/crack_band_earth_reference.svg` | Designer reference sketch |

## Tests

| Criterion | Result |
|-----------|--------|
| Universal scene smoke (14 `.tscn`, incl. gallery) | **PASS** |
| Fast vs threaded trace byte-identical (`wo011_trace_diff`) | **PASS** (627 lines) |
| Sim regression impact | **None** (render-only) |

## Assumptions made

NONE.

## Known issues

Texture fidelity deferred to Phase 6 per TD ruling (mechanic approved as-is).

## Links

- This report: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/crack_band_visual_respec_completion.md
- Previous report: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reports/WO-012_completion_report.md
- Reference sketch: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/reference/crack_band_earth_reference.svg
- Backlog item: https://raw.githubusercontent.com/securejdm-cmd/formations/main/docs/BACKLOG.md
