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
| `pattern_type` | Decoration style: `"none"`, `"ridges"`, or a geometric tile pattern — `"diamonds"`, `"hex_grid"`, `"pyramids"`, `"bricks"`, `"checkers"`, `"dots"`, `"cubes"`, `"tri_grid"`, `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`, `"tetrakis_square"`, `"kisrhombille"`, `"triakis_triangular"`, `"rhombille"`, `"cairo_pentagonal"`, `"floret_pentagonal"` | `"ridges"` |
| `pattern_orientation` | Direction: `"vertical"` or `"horizontal"` | `"vertical"` |
| `relief_mode` | Relief type: `"raised"` (pattern stands proud of the wall) or `"etched"` (pattern is cut into the wall) | `"raised"` |
| `pattern_depth` | Depth of pattern relief (mm) | 1.5 |
| `pattern_repeat` | Number of pattern tiles around the circumference; the vertical repeat count is derived automatically from the pot's geometry so tiles come out approximately square (see "Decoration" below) | 16 |

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

Most other patterns have no flat-topped counterpart, so `"etched"` instead sinks the same shape below the surface — a recess or dimple rather than an incised outline. `"hex_grid"` and `"tri_grid"` are the exception: like `"diamonds"`, they're already flat panels divided by V-groove borders in `"raised"` mode too, so `"etched"` there shifts that same panel/groove relief inward rather than turning a bump into a dimple — see the [gallery](docs/gallery.md#pattern-comparison) for both. The "kis" family — `"tetrakis_square"`, `"kisrhombille"` and `"triakis_triangular"` — is a third case: `"etched"` there is a completely separate flat-panel VNF with only a thin engraved groove between the fan triangles, not an inverted copy of the raised relief; see [the gallery](docs/gallery.md#pattern-comparison) for the detail on each. `"floret_pentagonal"` behaves exactly like that family in `"etched"` mode — a separate flat-panel VNF, every pentagon at the tile's full height with only a thin engraved groove between them, rather than an inverted copy of the raised relief — even though it is not a fourth "kis" pattern in the family's own sense (it is not a Conway kis-operation tiling); what it shares is the structure that motivates the split, a fan of facets around a shared point whose heights alternate in `"raised"` mode.

Seven of the `pattern_type` values — `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`, `"rhombille"`, `"cairo_pentagonal"` and `"floret_pentagonal"` — are *interlocking* patterns: their motifs deliberately cross the tile boundary so that adjacent repeats join into one continuous design rather than sitting in visible boxes. The [gallery](docs/gallery.md#pattern-comparison) shows what each one looks like; the notes below cover their rendering quirks.

Note on `"teardrop"` and `"intertwine"`: both tiles cross the tile boundary in a way that leaves a decorated body with scalloped rather than circular end caps. The planter itself renders fine, but OpenSCAD 2021.01 aborts with a CGAL assertion if you `union()` such a solid with another *textured* solid. Render these pots on their own, or combine them with plain (untextured) geometry — keep a `"teardrop"` or `"intertwine"` solid as the only textured solid per render when forcing CGAL evaluation. `"tumbling_cubes"` and `"islamic_star"` cross their tile edges too but union cleanly with another textured solid in the same test. `"rhombille"` (which reuses `"tumbling_cubes"`'s own hexagon/rhombus geometry) was *not* clean in that same union check at `pattern_repeat=16` in `"raised"` mode — one configuration tested, not the full grid the other four got — so until it's characterized further, treat `"rhombille"` like `"teardrop"`/`"intertwine"` here: keep it the only textured solid per render when forcing CGAL evaluation. `"cairo_pentagonal"` behaves the same way: it CGAL-aborted that same union check (union with a `"dots"` solid, differenced against a disjoint cube) at `pattern_repeat=9` in `"raised"` mode locally, so it is *not* in CI's union loop and gets the same advice — one textured solid per render. `"floret_pentagonal"` is the same: that union check CGAL-aborted locally at `pattern_repeat=26` in `"raised"` mode (a value that renders perfectly cleanly on its own at the same geometry), so it is not in CI's union loop either — keep it the only textured solid per render.

Note on the interlocking patterns and CGAL: `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`, `"rhombille"`, `"cairo_pentagonal"` and `"floret_pentagonal"` build their motifs from flat plateaus, and BOSL2 lays a single *flat* facet across each one. When a plateau spans a wide arc, that flat facet is a chord that cuts back inside the wall. OpenSCAD 2021.01's CGAL then aborts the cavity subtraction with an assertion or reports an unclosed mesh.

Which parameter values trip this depends on `pattern_repeat` **and** `smoothness` *jointly*, and is not predictable from either one alone — and it moves whenever the underlying tile geometry changes: deriving the vertical tile count from real geometry instead of reusing `pattern_repeat` for both axes (so tiles come out roughly square) shifted every fragile threshold below. It is not a low-`pattern_repeat` problem and not a simple threshold in either parameter, and — this is the part worth stating explicitly, because it is easy to assume otherwise — "clean" for one relief mode does not imply clean for the other: measured on the default pot at `smoothness=24`, `"tumbling_cubes"` aborts (in `"raised"`, at least) at every `pattern_repeat` from 3 through 8 and again at 11; of the values that are clean in `"raised"` (9, 10, 12), `pattern_repeat=12` aborts in `"etched"`, leaving only 9 and 10 clean in **both** relief modes, so CI uses the smaller of those, 9. `"islamic_star"` aborts in at least one relief mode at 3, 4, 5, 7, 11 and 12; of the remaining values, 6 and 9 are clean only in `"raised"` (both abort in `"etched"`) and 7 is clean only in `"etched"` — 8 and 10 are the only values clean in **both** modes, so CI uses the smaller, 8. `"intertwine"` aborts in both relief modes at 4 and 6; of the remaining values, 7 is clean only in `"raised"` (it aborts in `"etched"`) — 3, 5, 8, 12 and 15 are all clean in **both** modes on a local macOS OpenSCAD build. CI uses 12, not the smallest (3): 3 passed locally but CGAL-aborted on GitHub Actions' Ubuntu build, both reporting the same OpenSCAD 2021.01 — the CGAL floating-point sensitivity behind this whole fragility problem varies by platform too, not just by `pattern_repeat`/`smoothness`. 12 was chosen with a tested margin on both sides (10 aborts in `"etched"`; 15 is also clean in both modes) rather than repeating the mistake of picking the next-smallest untested value. If `"intertwine"`'s CI check ever fails again, re-measure directly against a CI run — a local-only "clean" is necessary but not sufficient for this pattern. Held at the shipped `pattern_repeat=16` instead, `"tumbling_cubes"` is clean at `smoothness` 24, 40 and 60 but aborts at 80 and 100 in both relief modes — this is what pushed the shipped `smoothness` default down from 80 to 60. `"islamic_star"` at `pattern_repeat=16`, by contrast, is now clean across every `smoothness` value tested (24, 40, 60, 80, 100) in both relief modes — the joint dependency is real, but it doesn't hit every pattern at every `pattern_repeat`. The shipped defaults (`pattern_repeat=16`, `smoothness=60`) are clean for all six in both relief modes, so the out-of-the-box experience is fine. CI pins this for `"islamic_star"`, `"tumbling_cubes"`, `"rhombille"`, `"cairo_pentagonal"` and `"floret_pentagonal"`; `"intertwine"` at the defaults is verified manually rather than in CI, since it takes roughly 2-3 minutes per relief mode there (see below) — re-verify it by hand if its tile construction ever changes.

`"rhombille"` reuses `"tumbling_cubes"`'s own hexagon/rhombus geometry directly (the same large flat plateaus, just one uniform height instead of three), and measured the same class of fragility: at `smoothness=24` on the default pot, it aborts in at least one relief mode at `pattern_repeat` 4, 6, 8, 9 (etched only), 11 and 14 (raised only); of the remaining values, 5 is clean only in `"raised"` (it aborts in `"etched"`) — 7, 10, 12, 13 and 15 are all clean in **both** modes locally. CI does **not** use the smallest of those, 7: 7 is an isolated clean value sandwiched directly between two full-abort values (6 and 8) on both sides, exactly the kind of narrow, untested-margin value the `"intertwine"` note above warns against trusting without a real CI run behind it. CI uses 13 instead — clean on both sides among the tested values (12 clean in both modes, 14 only failing in `"raised"`). Unlike `"intertwine"`'s value, this one has been re-verified against GitHub Actions' Ubuntu build, not just measured locally: run [35477972837](https://github.com/barrettclark/printed-planter-scad/actions/runs/35477972837) rendered `pattern_repeat=13`/`smoothness=24` clean (a 2-volume STL, no `CGAL error`) in both relief modes, under the workflow's `CGAL error` check. Held at the shipped `pattern_repeat=16`, `"rhombille"` is clean at `smoothness` 24 and 60 in both relief modes (higher `smoothness` values were not tested) — that combination was also confirmed against the same Ubuntu run; it was also clean locally at `pattern_repeat=32` and `smoothness` 24/60 in both relief modes.

`"cairo_pentagonal"` (the Cairo pentagonal tiling — eight flat pentagon plateaus per unit tile) measured the same class of fragility, so it carries the same known-to-abort warning rather than the "kis" family's precautionary one. At `smoothness=24` on the default pot it aborts in **both** relief modes at `pattern_repeat` 3, 5, 10 and 11, and in `"etched"` only at 4 (4 is clean in `"raised"`); 6, 7, 8, 9, 12, 13, 14, 15 and 16 are all clean in **both** modes, as are 24 and 32. CI uses 8 — deliberately not an isolated clean value: it sits in the middle of a four-wide run (6, 7, 8, 9) measured clean in both relief modes, so it has a tested margin on each side, which is exactly what `"intertwine"`'s 3 and `"rhombille"`'s 7 lacked. The `smoothness` axis was swept too, held at the shipped `pattern_repeat=16`: clean in both relief modes at `smoothness` 24, 40, 60 and 80, and aborting at `smoothness=100` in `"etched"` only (`"raised"` is clean there) — the shipped `smoothness=60` default therefore has two tested-clean steps of headroom above it. Unlike `"rhombille"`'s values, none of this has been re-verified against GitHub Actions' Ubuntu build yet: every measurement above is from a local macOS OpenSCAD 2021.01 build, which the `"intertwine"` note above shows is necessary but not sufficient. If CI's `"cairo_pentagonal 8"` or defaults check ever fails, re-measure against the CI run and pick another value from the 6–9 or 12–16 clean runs rather than the next smallest.

`"floret_pentagonal"` (the floret pentagonal tiling — **eighteen** flat pentagon plateaus per unit tile, the most of any tile in this project) is the most CGAL-fragile pattern here, and carries the same known-to-abort warning. At `smoothness=24` on the default pot it aborts in **both** relief modes at `pattern_repeat` 3, 7, 8 and 12, and in `"etched"` only at 4, 10 and 13; 5, 6, 9, 11, 14, 15 and 16 are clean in **both** modes. CI uses 15 — the only value in that range with a tested-clean neighbour on each side in both modes (14 and 16); 5, 6, 9 and 11 are each adjacent to an abort on at least one side, so picking one of them would repeat the isolated-clean-value mistake `"intertwine"`'s 3 and `"rhombille"`'s 7 made. At `smoothness=60`, the shipped default: `"raised"` aborts at 3, 7, 8 and 12 and is clean at 4, 5, 6, 9, 10, 11, 13, 14, 15 and 16; `"etched"` aborts at 3, 4, 5, 7, 8, 11, 12 and 13 and is clean only at 6, 9, 10, 14, 15 and 16. So **the shipped defaults (`pattern_repeat=16`, `smoothness=60`) do measure clean in both relief modes** — but the margin below them is thinner than for any other pattern (14 and 15 are clean in both modes, 13 already aborts in `"etched"`). Above the shipped default, held at `pattern_repeat=16`: `smoothness=80` and `smoothness=100` are also clean in both relief modes, measured locally (not yet CI-verified) — two tested-clean steps of headroom above the default, one step better than `"cairo_pentagonal"`, which aborts at `smoothness=100` in `"etched"`. CI pins the defaults for it (see `.github/workflows/test.yml`) precisely because the margin below them is narrow. Everything above is from a local macOS OpenSCAD 2021.01 build and has **not** yet been re-verified against GitHub Actions' Ubuntu build — the `"intertwine"` note above is the standing reminder that local-clean is necessary but not sufficient. If CI's `"floret_pentagonal 15"` or its defaults check ever fails, re-measure against that CI run and pick another value from the clean runs rather than the next smallest. On a separate, narrower geometry (a bare `cyl(r1=75, r2=60, h=100, $fn=50)` with `tex_reps=[12,8]`, not the planter assembly) this pattern also aborts at `pattern_repeat` 12, 14, 15, 16, 20, 22 and 23 while 24–27 and 30–33 are clean — which is why `tests/test_decoration_floret_pentagonal.scad` renders at 26 rather than the 12 the other tile tests use.

The "kis" family — `"tetrakis_square"`, `"kisrhombille"` and `"triakis_triangular"` — shares this same precautionary CGAL warning, since they're built from the same general class of small triangular facets, but they are not known to be fragile: every tested `pattern_repeat`/`smoothness`/relief-mode combination for all three, including the shipped defaults and the reduced CI value, has measured CGAL-clean. Treat the warning on those three as a "scan the console anyway, just in case" precaution rather than a known failure mode.

**Watch the console.** When this happens OpenSCAD still exits 0 and still writes an STL — a large, plausible-looking file from a subtraction that aborted part-way. The only signal is `CGAL error: assertion violation!` in the console log, with no error dialog in the GUI. If you see it, or if you get a broken/exploded render, nudge either `pattern_repeat` or `smoothness` by a small amount and render again.

`"intertwine"` is by far the most expensive of the six to render: roughly 2-3 minutes and a ~25MB STL at the shipped defaults on a modern laptop, versus well under a minute for `"tumbling_cubes"`/`"islamic_star"`/`"rhombille"`/`"cairo_pentagonal"`/`"floret_pentagonal"`. A silent console for a couple of minutes on `"intertwine"` is normal — it is not a hang, and it is not the CGAL failure above (which happens quickly, not after a minute or more).

Adjust `pattern_orientation` to switch between vertical and horizontal layouts, and `pattern_repeat` to set how many tiles wrap around the circumference. The vertical repeat count is no longer the same number: `decorated_solid()` derives it automatically (`_square_tile_vertical_reps()` in `modules/decoration.scad`) from the pot's actual height and circumference, so tiles come out approximately square regardless of `pattern_repeat` — raising `pattern_repeat` still multiplies the tiles horizontally, but the vertical count adjusts to match rather than tracking it 1:1.

Note: tiles are only *exactly* square at the pot's mean radius, since the decorated wall is a cone and BOSL2 scales each texture strip to the local radius (`lib/BOSL2/skin.scad`'s `_textured_revolution()`) while the vertical repeat count is fixed for the whole wall. At shipped defaults (`pattern_repeat=16`, bottom radius ~61mm, top radius ~82.3mm, 138mm wall height) this leaves a small residual: tiles run about **0.87× wide-to-tall at the bottom rim to 1.17× at the top rim** — not the ~2.8–3.75× distortion of the old `tex_reps = [pattern_repeat, pattern_repeat]` behavior. See [the gallery's full-pot section](docs/gallery.md#full-pot-examples) for side-by-side evidence.

Note: enabling decoration changes the pot's outer silhouette slightly. BOSL2's textured `cyl()` only supports a straight r1/r2 cone, so the decorated body is approximated as a straight cone through the cavity's peak radius rather than following the cavity's exact ledge/shoulder profile — at defaults this means the rim wall goes from ~3mm (plain `wall_thickness`) to ~7mm. This is a deliberate, documented tradeoff, not a bug.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file included in this repository.
