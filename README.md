# Parametric Planter Generator

## What This Is

This is a parametric OpenSCAD model that generates a decorative outer planter body/shell fitted around a plastic insert (pot, container, or vessel) you already have. You provide measurements of your insert and the generator creates a body that holds it securely, with optional decorative patterns. All dimensions are parametric—adjust them to fit any insert size, wall thickness, or decoration style.

## Requirements

- **OpenSCAD 2021.01 or later** — required by the vendored BOSL2 library (which hard-asserts this minimum version), the Customizer feature, and procedural language features used here.
- **BOSL2 library** — vendored in `lib/BOSL2/`, no separate installation needed.
- **Customizer panel recommended** — the easiest way to adjust parameters. Enable it with **View → Show Customizer** in OpenSCAD.

Command-line users can override any parameter without the Customizer by using the `-D` flag, for example:
```bash
openscad -D 'insert_top_d=160' -D 'pattern_type="hex_grid"' -o exports/planter.stl planter.scad
```

An `exports/` directory is included for rendered output (STL, 3MF, PNG, etc.) — `.gitignore` already excludes those file types repo-wide, so anything you save there stays local and won't get committed. (The one carve-out is `docs/images/`, whose PNGs are documentation rather than disposable output — regenerate them with `docs/images/render.sh`.)

## Measuring Your Insert

Before measuring, check whether your insert is close to one of the 3 named sizes in `insert_preset` (see the Insert Dimensions table below) — if so, just pick that preset and skip measuring entirely.

Otherwise, to generate a planter for a different insert, measure these three dimensions:

- **`insert_top_d`** — the widest point of your insert (the rim or top diameter), in millimeters.
- **`insert_bottom_d`** — the bottom diameter of your insert, in millimeters.
- **`insert_height`** — the vertical height of your insert, in millimeters.

With `insert_preset` left at `"custom"`, these three measurements are the **only parameters you need to change** to reprint the planter for a different insert. The generator will automatically adjust the cavity (internal pocket) to fit your insert's tapered shape. All other parameters control fit clearance, wall thickness, decoration, and base options—leave them at their defaults unless you need to customize further.

## Parameter Reference

All parameters below can be adjusted in the Customizer panel or via command-line `-D` overrides.

### Insert Dimensions

| Parameter | Description | Default |
|-----------|-------------|---------|
| `insert_preset` | Named insert size: `"custom"` (use the three fields below) or `"small"`, `"medium"`, `"large"` | `"custom"` |
| `insert_top_d` | Top rim diameter (mm) — used when `insert_preset == "custom"` | 150 |
| `insert_bottom_d` | Bottom diameter (mm) — used when `insert_preset == "custom"` | 110 |
| `insert_height` | Insert height (mm) — used when `insert_preset == "custom"` | 130 |

The 3 named presets:

| `insert_preset` | `insert_top_d` | `insert_bottom_d` | `insert_height` |
|---|---|---|---|
| `"small"` | 100 | 75 | 85 |
| `"medium"` | 130 | 100 | 120 |
| `"large"` | 180 | 125 | 160 |

### Fit

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ledge_engagement_height` | Depth of the rim's tight-fit seat (mm) | 8 |
| `ledge_ramp_height` | Height over which the seat narrows to its tight clearance, instead of as a hard step (mm); `0` reproduces the old hard step | 2 |
| `fit_clearance` | Radial clearance at the rim seat (mm) | 0.3 |
| `body_clearance` | Radial clearance around the tapered insert body (mm) | 3 |
| `bottom_margin` | Air gap below the insert's bottom (mm) | 5 |

### Outer Shape

| Parameter | Description | Default |
|-----------|-------------|---------|
| `outer_mode` | Shape mode: `"follow"` (auto-wrap around insert) or `"custom"` (fixed geometry) | `"follow"` |
| `wall_thickness` | Wall thickness in `"follow"` mode (mm) | 3 |
| `outer_top_d` | Outer top diameter in `"custom"` mode (mm) | 172 |
| `outer_bottom_d` | Outer bottom diameter in `"custom"` mode (mm) | 130 |
| `outer_height` | Planter height in `"custom"` mode (mm) | 145 |

### Decoration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `pattern_type` | Decoration style: `"none"`, `"ridges"`, or a geometric tile pattern — `"diamonds"`, `"hex_grid"`, `"pyramids"`, `"bricks"`, `"checkers"`, `"dots"`, `"cubes"`, `"tri_grid"`, `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"` | `"ridges"` |
| `pattern_orientation` | Direction: `"vertical"` or `"horizontal"` | `"vertical"` |
| `relief_mode` | Relief type: `"raised"` (pattern stands proud of the wall) or `"etched"` (pattern is cut into the wall) | `"raised"` |
| `pattern_depth` | Depth of pattern relief (mm) | 1.5 |
| `pattern_repeat` | Number of pattern tiles around the circumference, and also vertically for tileable patterns | 16 |

### Base

| Parameter | Description | Default |
|-----------|-------------|---------|
| `floor_thickness` | Thickness of the planter's solid floor (mm) | 3 |
| `drainage_holes_enabled` | Enable drainage holes in the floor | `false` |
| `drainage_hole_count` | Number of drainage holes | 6 |
| `drainage_hole_diameter` | Diameter of each drainage hole (mm) | 4 |

In `"custom"` outer mode, the actual floor thickness is `floor_thickness + (outer_height - pot_height)`, not just `floor_thickness` — the cavity is shifted up to sit flush with the custom outer shape's top, so any extra height in `outer_height` beyond the required cavity height becomes additional solid floor.

### Quality

| Parameter | Description | Default |
|-----------|-------------|---------|
| `smoothness` | Mesh resolution for all revolved geometry (OpenSCAD `$fn`) | 60 |

## Reference Settings: This Project's Insert

The planter was designed around this insert. Use these settings to reproduce the exact geometry from this project:

```scad
insert_preset = "custom";
insert_top_d = 150;
insert_bottom_d = 110;
insert_height = 130;
ledge_engagement_height = 8;
ledge_ramp_height = 2;
fit_clearance = 0.3;
body_clearance = 3;
bottom_margin = 5;
outer_mode = "follow";
wall_thickness = 3;
pattern_type = "ridges";
pattern_orientation = "vertical";
relief_mode = "raised";
pattern_depth = 1.5;
pattern_repeat = 16;
floor_thickness = 3;
drainage_holes_enabled = false;
```

## Decoration Examples

**See the [pattern gallery](docs/gallery.md) for a rendered example of every `pattern_type` in both relief modes** (except `"none"`, which has no texture, so it only has one useful mode), plus full-pot renders, the three insert presets and both outer shape modes. The rest of this section covers the behaviour the pictures can't show.

`"etched"` works one of two ways depending on the pattern. `"ridges"`, `"pyramids"` and `"diamonds"` have a flat-topped counterpart shape, so etching them is a true line engrave: the wall keeps its nominal surface as flat panels, and only a thin V-groove is cut along each of the pattern's outlines — the look of a design engraved into wood or stone rather than moulded into it. The groove takes up roughly a tenth of each tile, so the flat panel dominates.

- `"ridges"` — a smooth wall scored with thin vertical (or horizontal) lines.
- `"pyramids"` — flat square panels divided by a thin engraved grid.
- `"diamonds"` — flat diamond panels divided by thin 45° engraved lines.

Most other patterns have no flat-topped counterpart, so `"etched"` instead sinks the same shape below the surface — a recess or dimple rather than an incised outline. `"hex_grid"` and `"tri_grid"` are the exception: like `"diamonds"`, they're already flat panels divided by V-groove borders in `"raised"` mode too, so `"etched"` there shifts that same panel/groove relief inward rather than turning a bump into a dimple — see the [gallery](docs/gallery.md#pattern-comparison) for both.

The last four `pattern_type` values — `"teardrop"`, `"tumbling_cubes"`, `"intertwine"` and `"islamic_star"` — are *interlocking* patterns: their motifs deliberately cross the tile boundary so that adjacent repeats join into one continuous design rather than sitting in visible boxes. The [gallery](docs/gallery.md#pattern-comparison) shows what each one looks like; the notes below cover their rendering quirks.

Note on `"teardrop"` and `"intertwine"`: both tiles cross the tile boundary in a way that leaves a decorated body with scalloped rather than circular end caps. The planter itself renders fine, but OpenSCAD 2021.01 aborts with a CGAL assertion if you `union()` such a solid with another *textured* solid. Render these pots on their own, or combine them with plain (untextured) geometry — keep a `"teardrop"` or `"intertwine"` solid as the only textured solid per render when forcing CGAL evaluation. `"tumbling_cubes"` and `"islamic_star"` cross their tile edges too but union cleanly with another textured solid in the same test.

Note on the interlocking patterns and CGAL: `"tumbling_cubes"`, `"intertwine"` and `"islamic_star"` build their motifs from a few large flat plateaus, and BOSL2 lays a single *flat* facet across each one. When a plateau spans a wide arc, that flat facet is a chord that cuts back inside the wall. OpenSCAD 2021.01's CGAL then aborts the cavity subtraction with an assertion or reports an unclosed mesh.

Which parameter values trip this depends on `pattern_repeat` **and** `smoothness` *jointly*, and is not predictable from either one alone — and it moves whenever the underlying tile geometry changes: deriving the vertical tile count from real geometry instead of reusing `pattern_repeat` for both axes (so tiles come out roughly square) shifted every fragile threshold below. It is not a low-`pattern_repeat` problem and not a simple threshold in either parameter: measured on the default pot at `smoothness=24`, `"tumbling_cubes"` aborts at every `pattern_repeat` from 3 through 8 and again at 11, but is clean at 9, 10 and 12; `"islamic_star"` aborts at 3, 4, 5, 7, 11 and 12 but is clean at 6, 8, 9 and 10 in at least one relief mode (8 is the smallest value clean in both); `"intertwine"` aborts at 4 and 6 but is clean at 3, 5, 7 and 8. Held at the shipped `pattern_repeat=16` instead, `"tumbling_cubes"` is clean at `smoothness` 24, 40 and 60 but aborts at 80 and 100 in both relief modes — this is what pushed the shipped `smoothness` default down from 80 to 60. `"islamic_star"` at `pattern_repeat=16`, by contrast, is now clean across every `smoothness` value tested (24, 40, 60, 80, 100) in both relief modes — the joint dependency is real, but it doesn't hit every pattern at every `pattern_repeat`. The shipped defaults (`pattern_repeat=16`, `smoothness=60`) are clean for all three in both relief modes, so the out-of-the-box experience is fine. CI pins this for `"islamic_star"` and `"tumbling_cubes"`; `"intertwine"` at the defaults is verified manually rather than in CI, since it takes roughly 2-3 minutes per relief mode there (see below) — re-verify it by hand if its tile construction ever changes.

**Watch the console.** When this happens OpenSCAD still exits 0 and still writes an STL — a large, plausible-looking file from a subtraction that aborted part-way. The only signal is `CGAL error: assertion violation!` in the console log, with no error dialog in the GUI. If you see it, or if you get a broken/exploded render, nudge either `pattern_repeat` or `smoothness` by a small amount and render again.

`"intertwine"` is by far the most expensive of the three to render: roughly 2-3 minutes and a ~25MB STL at the shipped defaults on a modern laptop, versus well under a minute for `"tumbling_cubes"`/`"islamic_star"`. A silent console for a couple of minutes on `"intertwine"` is normal — it is not a hang, and it is not the CGAL failure above (which happens quickly, not after a minute or more).

Adjust `pattern_orientation` to switch between vertical and horizontal layouts, and `pattern_repeat` to change how many tiles wrap around the circumference — the same value also sets the vertical repeat count for tileable patterns, so raising it makes tiles both more numerous around the pot and shorter top-to-bottom.

Note: tiles come out **roughly 2.8–3.75× wider than tall** on the pot, and it's not a fixed number: `tex_reps` is set to `[pattern_repeat, pattern_repeat]`, asking for the same repeat count around the circumference as up the height regardless of the pot's proportions, and because the decorated wall is a cone (BOSL2 scales each texture strip to the local radius, per `lib/BOSL2/skin.scad`'s `_textured_revolution()`), the tiles themselves are trapezoidal, not uniform rectangles — narrower at the bottom (radius ~61mm) than the top (radius ~82.3mm, `planter.scad`'s own peak-aware cone calculation). At defaults that's roughly 24mm wide at the bottom rising to roughly 32mm at the top, against an 8.6mm tile height (138mm wall / 16 tiles). `"ridges"` and `"bricks"` are unaffected in practice; large-motif patterns like `"islamic_star"` are squashed enough to lose the motif. Raising `pattern_repeat` shortens the tiles vertically (and multiplies them horizontally). See [the gallery's full-pot section](docs/gallery.md#full-pot-examples) for side-by-side evidence.

Note: enabling decoration changes the pot's outer silhouette slightly. BOSL2's textured `cyl()` only supports a straight r1/r2 cone, so the decorated body is approximated as a straight cone through the cavity's peak radius rather than following the cavity's exact ledge/shoulder profile — at defaults this means the rim wall goes from ~3mm (plain `wall_thickness`) to ~7mm. This is a deliberate, documented tradeoff, not a bug.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file included in this repository.
