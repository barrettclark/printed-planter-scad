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

An `exports/` directory is included for rendered output (STL, 3MF, PNG, etc.) — `.gitignore` already excludes those file types repo-wide, so anything you save there stays local and won't get committed.

## Measuring Your Insert

To generate a planter for a different insert, measure these three dimensions:

- **`insert_top_d`** — the widest point of your insert (the rim or top diameter), in millimeters.
- **`insert_bottom_d`** — the bottom diameter of your insert, in millimeters.
- **`insert_height`** — the vertical height of your insert, in millimeters.

These three measurements are the **only parameters you need to change** to reprint the planter for a different insert. The generator will automatically adjust the cavity (internal pocket) to fit your insert's tapered shape. All other parameters control fit clearance, wall thickness, decoration, and base options—leave them at their defaults unless you need to customize further.

## Parameter Reference

All parameters below can be adjusted in the Customizer panel or via command-line `-D` overrides.

### Insert Dimensions

| Parameter | Description | Default |
|-----------|-------------|---------|
| `insert_top_d` | Top rim diameter (mm) | 150 |
| `insert_bottom_d` | Bottom diameter (mm) | 110 |
| `insert_height` | Insert height (mm) | 130 |

### Fit

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ledge_engagement_height` | Depth of the rim's tight-fit seat (mm) | 8 |
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
| `pattern_type` | Decoration style: `"none"`, `"ridges"`, or a geometric tile pattern — `"diamonds"`, `"hex_grid"`, `"pyramids"`, `"bricks"`, `"checkers"`, `"dots"`, `"cubes"`, `"tri_grid"`, `"teardrop"` | `"ridges"` |
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
| `smoothness` | Mesh resolution for all revolved geometry (OpenSCAD `$fn`) | 80 |

## Preset: This Project's Insert

The planter was designed around this insert. Use these settings to reproduce the exact geometry from this project:

```scad
insert_top_d = 150;
insert_bottom_d = 110;
insert_height = 130;
ledge_engagement_height = 8;
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

The `pattern_type` and `relief_mode` parameters combine to create different visual effects.

`"etched"` works one of two ways depending on the pattern. `"ridges"`, `"pyramids"` and `"diamonds"` have a flat-topped counterpart shape, so etching them is a true line engrave: the wall keeps its nominal surface as flat panels, and only a thin V-groove is cut along each of the pattern's outlines — the look of a design engraved into wood or stone rather than moulded into it. The groove takes up roughly a tenth of each tile, so the flat panel dominates.

- `"ridges"` — a smooth wall scored with thin vertical (or horizontal) lines.
- `"pyramids"` — flat square panels divided by a thin engraved grid.
- `"diamonds"` — flat diamond panels divided by thin 45° engraved lines.

Every other pattern has no flat-topped counterpart, so `"etched"` instead sinks the same shape below the surface — a recess or dimple rather than an incised outline.

| `pattern_type` | `relief_mode` | Result |
|---|---|---|
| `"none"` | — | Plain smooth walls with no decoration. |
| `"ridges"` | `"raised"` | Vertical (or horizontal) ridge lines that protrude outward. |
| `"ridges"` | `"etched"` | Smooth wall with thin vertical (or horizontal) V-grooves engraved into it. |
| `"diamonds"` | `"raised"` | Repeating lattice of pointed diamond bumps. |
| `"diamonds"` | `"etched"` | Flat diamond panels separated by thin 45° V-groove lines engraved into the wall. |
| `"hex_grid"` | `"raised"` / `"etched"` | Honeycomb hexagon grid, projecting or recessed. |
| `"pyramids"` | `"raised"` | Repeating four-sided pyramids projecting outward. |
| `"pyramids"` | `"etched"` | Flat square panels separated by a thin engraved grid of V-grooves. |
| `"bricks"` | `"raised"` / `"etched"` | Offset brick/masonry courses, projecting or recessed. |
| `"checkers"` | `"raised"` / `"etched"` | Checkerboard squares, projecting or recessed. |
| `"dots"` | `"raised"` / `"etched"` | Repeating round dots (bumps or dimples). |
| `"cubes"` | `"raised"` / `"etched"` | Repeating cube facets, projecting or recessed. |
| `"tri_grid"` | `"raised"` / `"etched"` | Triangular grid pattern, projecting or recessed. |
| `"teardrop"` | `"raised"` / `"etched"` | Interlocking teardrops: two columns of drops half a period out of phase, so each point nests between the bellies of its neighbours. |

Note on `"teardrop"`: its tile is a hand-built VNF whose drops cross the tile's top and bottom edges (that overlap is what makes them interlock), so a decorated body ends up with scalloped rather than circular end caps. The planter itself renders fine, but OpenSCAD 2021.01 aborts with a CGAL assertion if you `union()` a teardrop-decorated solid with another *textured* solid. Render teardrop pots on their own, or combine them with plain (untextured) geometry.

Adjust `pattern_orientation` to switch between vertical and horizontal layouts, and `pattern_repeat` to change how many tiles wrap around the circumference — the same value also sets the vertical repeat count for tileable patterns, so raising it makes tiles both more numerous around the pot and shorter top-to-bottom.

Note: enabling decoration changes the pot's outer silhouette slightly. BOSL2's textured `cyl()` only supports a straight r1/r2 cone, so the decorated body is approximated as a straight cone through the cavity's peak radius rather than following the cavity's exact ledge/shoulder profile — at defaults this means the rim wall goes from ~3mm (plain `wall_thickness`) to ~7mm. This is a deliberate, documented tradeoff, not a bug.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file included in this repository.
