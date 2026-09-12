# Parametric Decorative Planter Pot — Design Spec

Date: 2026-09-12

## Purpose

Generate decorative outer "cachepot" shells (OpenSCAD, 3D-printable) sized to fit
commercial plastic planter inserts, configured entirely through parameters
instead of manually resizing published models. First target insert: a round,
tapered tray-style insert with drainage holes (150mm top diameter, 110mm bottom
diameter, 130mm tall, with a rim/flange at the top that the pot supports).

Project will be published to GitHub.

## Insert & Fit Model

The insert has a flange/rim at the very top (the widest point, 150mm) and a
tapered body below it that must **not** contact the pot walls — only the rim
should bear load. The cavity is built as a revolved profile with two zones:

1. **Ledge zone** (top): radius = `insert_top_d/2 + fit_clearance`, depth =
   `ledge_engagement_height` (default ~8mm). This is the tight-tolerance step
   the insert's rim rests on.
2. **Clearance zone** (below ledge): radius steps outward by `body_clearance`
   (default ~3mm) beyond the insert's own taper at each height, running from
   the bottom of the ledge zone down to `insert_height - ledge_engagement_height
   + bottom_margin`. This guarantees the tapered insert body hangs free with no
   side contact, regardless of insert taper angle.
3. **Floor**: below the clearance zone, thickness `floor_thickness`. Style is
   configurable (see Base Styles).

The outer body (the visible decorative solid) is either:
- **Follow-insert mode** (default): outer profile mirrors the cavity profile,
  offset outward by `wall_thickness` at every height.
- **Custom mode**: outer profile independently defined by
  `outer_top_d`/`outer_bottom_d`/`outer_height`, decoupled from the insert
  taper. The cavity is still subtracted from this solid, so fit is guaranteed
  either way; `outer_*` dimensions must simply be large enough to contain the
  cavity plus `wall_thickness`, which is asserted at build time.

Outer cross-section is round only for this version (geometric decoration can
still create the visual impression of a faceted outer shape via
surface texture — see Decoration).

## Base Styles

Floor is always solid (thickness `floor_thickness`); drainage holes are a
checkbox on top of it:
- `drainage_holes` (boolean, default `false`) — when enabled, adds a
  configurable pattern of drainage holes (`drainage_hole_count`,
  `drainage_hole_diameter`) to the solid floor, for standalone use without the
  insert. When disabled, the floor has no holes and the pot acts as a plain
  cachepot/catch basin (insert provides all drainage).

## Decoration System

Applied via BOSL2's `texture()` mechanism on the revolved outer body surface,
after the outer profile is built and before the cavity is subtracted (so
decoration relief never eats into the wall thickness reserved for insert fit).

Independent parameters:
- `pattern_type`: `none` / `ridges` / `geometric` — `geometric` draws from
  BOSL2's built-in texture catalog (e.g. diamonds, hex tiles, pyramids) rather
  than hand-authored shapes.
- `pattern_orientation`: `vertical` / `horizontal` — texture tiling direction;
  primarily meaningful for `ridges`, and rotates tile-based `geometric`
  patterns 90°.
- `relief_mode`: `raised` / `etched` — same pattern, embossed outward or
  engraved inward.
- `pattern_depth`: relief height/depth in mm.
- `pattern_repeat`: tile count around the circumference (and vertically, for
  tileable patterns like `ridges`).

Build-time assertion: `pattern_depth < wall_thickness * 0.7` (warns/fails if
decoration would breach into the cavity).

## Dependencies

- **BOSL2**, vendored as a pinned copy under `lib/BOSL2/` and committed to the
  repo (not a live submodule), so the project has no external install step
  beyond cloning the repo. Chosen over hand-rolled geometry because its
  `texture()` system directly covers ridges/geometric-pattern/raised-etched
  requirements with far less custom code and better render quality.

## File Layout

```
printed-planter-scad/
  lib/BOSL2/              # vendored, pinned version, committed
  planter.scad            # main entry point — Customizer parameters + top-level calls
  modules/
    insert.scad           # cavity profile builder (ledge + clearance zone)
    body.scad             # outer body profile builder (follow-insert or custom mode)
    decoration.scad       # texture/pattern application
    base.scad             # floor styles: solid / solid+drainage / open
  README.md               # measuring your insert, BOSL2 note, Customizer usage, presets
  LICENSE
  .gitignore
```

`planter.scad` groups Customizer parameters into labeled sections
(`/* [Insert Dimensions] */`, `/* [Fit] */`, `/* [Outer Shape] */`,
`/* [Decoration] */`, `/* [Base] */`, `/* [Quality] */`) so the model is usable
directly from OpenSCAD's Customizer panel without editing code. Derived values
(radii, heights) are computed once from raw inputs near the top of the file.
Included modules receive all values as explicit arguments — no reliance on
global state — since OpenSCAD's Customizer only reads variables declared in
the top-level file.

## Validation

No unit-test framework exists for OpenSCAD; validation instead means:
- Assertions in `planter.scad`: `insert_bottom_d < insert_top_d`,
  `wall_thickness > 0`, `pattern_depth < wall_thickness * 0.7`, base-style
  parameter consistency.
- Known-good preset parameter sets documented in the README, including the
  real 150/110/130 insert dimensions, as a working reference to diff against.
- Manual render check post-implementation: render the default config and at
  least one decorated variant via the `openscad` CLI (if available on this
  machine) to confirm the model compiles and geometry is sane.

## GitHub

Repo will be initialized locally (`git init`, initial commit) as part of
implementation. Creating the actual GitHub remote and pushing is a separate,
explicit step requiring Barrett's confirmation before it happens (visible/
external action).

## Out of Scope (this iteration)

- Non-round outer cross-sections (square/hex outer body).
- Multiple simultaneous insert profiles/presets beyond documented examples.
- Automated visual regression testing of renders.
