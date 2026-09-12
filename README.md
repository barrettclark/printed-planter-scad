# Parametric Planter Generator

## What This Is

This is a parametric OpenSCAD model that generates customizable plant pot inserts and matching planter bodies. You provide measurements of your insert (pot, container, or vessel) and the generator creates a planter body fitted to hold it securely with optional decorative patterns. All dimensions are parametric—adjust them to fit any insert size, wall thickness, or decoration style.

## Requirements

- **OpenSCAD 2019.05 or later** — required for the Customizer feature and procedural language features used here.
- **BOSL2 library** — vendored in `lib/BOSL2/`, no separate installation needed.
- **Customizer panel recommended** — the easiest way to adjust parameters. Enable it with **View → Show Customizer** in OpenSCAD.

Command-line users can override any parameter without the Customizer by using the `-D` flag, for example:
```bash
openscad -D 'insert_top_d=160' -D 'pattern_type=geometric' -o planter.stl planter.scad
```

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
| `outer_top_d` | Outer top diameter in `"custom"` mode (mm) | 160 |
| `outer_bottom_d` | Outer bottom diameter in `"custom"` mode (mm) | 120 |
| `outer_height` | Planter height in `"custom"` mode (mm) | 140 |

### Decoration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `pattern_type` | Decoration style: `"none"`, `"ridges"`, or `"geometric"` | `"ridges"` |
| `pattern_orientation` | Direction: `"vertical"` or `"horizontal"` | `"vertical"` |
| `relief_mode` | Relief type: `"raised"` or `"etched"` | `"raised"` |
| `pattern_depth` | Depth of pattern relief (mm) | 1.5 |
| `pattern_repeat` | Number of pattern tiles around the circumference | 16 |

### Base

| Parameter | Description | Default |
|-----------|-------------|---------|
| `floor_thickness` | Thickness of the planter's solid floor (mm) | 3 |
| `drainage_holes_enabled` | Enable drainage holes in the floor | `false` |
| `drainage_hole_count` | Number of drainage holes | 6 |
| `drainage_hole_diameter` | Diameter of each drainage hole (mm) | 4 |

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

The `pattern_type` and `relief_mode` parameters combine to create different visual effects:

| `pattern_type` | `relief_mode` | Result |
|---|---|---|
| `"none"` | — | Plain smooth walls with no decoration. |
| `"ridges"` | `"raised"` | Vertical (or horizontal) ridge lines that protrude outward. |
| `"ridges"` | `"etched"` | Vertical (or horizontal) groove lines sunk into the surface. |
| `"geometric"` | `"raised"` | Repeating geometric tiles that project outward. |
| `"geometric"` | `"etched"` | Repeating geometric tiles carved into the surface. |

Adjust `pattern_orientation` to switch between vertical and horizontal layouts, and `pattern_repeat` to change how many tiles wrap around the circumference.

## License

This project is licensed under the [LICENSE](LICENSE) file included in this repository.
