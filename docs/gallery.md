# Pattern Gallery

Every `pattern_type` this generator offers, in both `relief_mode` values, plus
the insert presets and outer shape modes. All images are real OpenSCAD renders
produced by [`images/render.sh`](images/render.sh) — nothing here is drawn by
hand or touched up.

See [README.md](../README.md) for what each parameter means.

## Table of Contents

- [Pattern Comparison](#pattern-comparison)
  - [none](#none)
  - [ridges](#ridges)
  - [diamonds](#diamonds)
  - [hex_grid](#hex_grid)
  - [pyramids](#pyramids)
  - [bricks](#bricks)
  - [checkers](#checkers)
  - [dots](#dots)
  - [cubes](#cubes)
  - [tri_grid](#tri_grid)
  - [teardrop](#teardrop)
  - [tumbling_cubes](#tumbling_cubes)
  - [intertwine](#intertwine)
  - [islamic_star](#islamic_star)
- [Full-Pot Examples](#full-pot-examples)
- [Insert Presets](#insert-presets)
- [Outer Shape Modes](#outer-shape-modes)
- [Regenerating These Images](#regenerating-these-images)

## Pattern Comparison

**These are flat tile close-ups, not pictures of a pot.** Each one is a
`decorated_solid()` cylinder whose height equals its own circumference, so
`tex_reps = [n, n]` lays down **square** tiles and every pattern is shown at its
designed proportions. On the actual planter the same tiles come out roughly
**3.2× wider than tall** — see [Full-Pot Examples](#full-pot-examples) below for
what that does to them, and why these close-ups lead the page instead.

Settings shared by every image in this section: `r1 = r2 = 90mm`,
`height = 565.5mm` (= 2πr), `pattern_repeat = 32` (so tiles are ~17.7mm square),
`pattern_depth = 1.5` and `smoothness = 80` (both the shipped defaults),
`pattern_orientation = "vertical"`. Uniform across all of them, so the images
are comparable with each other.

Two rendering caveats worth knowing before you read the pictures:

- **The camera is ~25° off-axis** in both azimuth and elevation, not dead-on.
  OpenSCAD's light is mounted on the camera, so a straight-on shot hits every
  flat plateau at the same angle and the patterns built from flat islands
  (`tumbling_cubes`, `intertwine`, `islamic_star`) wash out to almost nothing.
  25° rakes the light across the relief. It compresses both axes by about the
  same `cos(25°) = 0.91`, so tile aspect is essentially preserved.
- **The relief reads slightly deeper here than it will on a printed pot.** The
  depth is the real default (1.5mm), but these tiles are 17.7mm across where
  the default pot's are ~27.9mm, so the depth-to-width ratio is 8.5% here
  versus 5.4% on the pot.

### none

No texture at all — a plain wall. `relief_mode` has nothing to act on, so
there is only one image.

| Plain |
|---|
| ![none](images/pattern-none-raised.png) |

The faint vertical banding is the `smoothness = 80` facets of the cylinder
itself, not a pattern.

### ridges

| Raised | Etched |
|---|---|
| ![ridges, raised](images/pattern-ridges-raised.png) | ![ridges, etched](images/pattern-ridges-etched.png) |

One of the three patterns with a true flat-topped counterpart: etched is a thin
V-groove incised into an otherwise flat wall, not an inverted bump.

### diamonds

| Raised | Etched |
|---|---|
| ![diamonds, raised](images/pattern-diamonds-raised.png) | ![diamonds, etched](images/pattern-diamonds-etched.png) |

Also a true line engrave when etched: flat diamond panels divided by thin 45°
grooves.

### hex_grid

| Raised | Etched |
|---|---|
| ![hex_grid, raised](images/pattern-hex_grid-raised.png) | ![hex_grid, etched](images/pattern-hex_grid-etched.png) |

### pyramids

| Raised | Etched |
|---|---|
| ![pyramids, raised](images/pattern-pyramids-raised.png) | ![pyramids, etched](images/pattern-pyramids-etched.png) |

The third true line engrave: etched gives flat square panels separated by an
engraved grid, not flattened pyramids.

### bricks

| Raised | Etched |
|---|---|
| ![bricks, raised](images/pattern-bricks-raised.png) | ![bricks, etched](images/pattern-bricks-etched.png) |

The speckle on each brick face is BOSL2's per-facet randomised roughness. It is
also why `bricks` is one of the slower patterns to render.

### checkers

| Raised |
|---|
| ![checkers, raised](images/pattern-checkers-raised.png) |

**No etched image:** a checkerboard is its own inverse. Recessing the motif
produces the identical tiling shifted half a tile, so an etched render is
indistinguishable from this one. Rendered and compared side by side before
deciding to omit it.

### dots

| Raised | Etched |
|---|---|
| ![dots, raised](images/pattern-dots-raised.png) | ![dots, etched](images/pattern-dots-etched.png) |

The clearest raised/etched pair on the page: genuine bumps versus genuine
dimples. `dots` is the one pattern that needs a negative `tex_depth` rather
than a plain inset to invert properly — without it the etched version would be
the same bump pushed below the surface.

### cubes

| Raised |
|---|
| ![cubes, raised](images/pattern-cubes-raised.png) |

**No etched image**, for the same reason as `checkers`: the isometric cube
tiling is its own inverse, so etching it yields the same tiling half a tile
over.

### tri_grid

| Raised | Etched |
|---|---|
| ![tri_grid, raised](images/pattern-tri_grid-raised.png) | ![tri_grid, etched](images/pattern-tri_grid-etched.png) |

### teardrop

| Raised | Etched |
|---|---|
| ![teardrop, raised](images/pattern-teardrop-raised.png) | ![teardrop, etched](images/pattern-teardrop-etched.png) |

Interlocking. The two columns are half a period out of phase, so each drop's
point nests into the belly of its neighbour and the motif carries straight
across the tile seams — there are no visible tile boxes.

### tumbling_cubes

| Raised | Etched |
|---|---|
| ![tumbling_cubes, raised](images/pattern-tumbling_cubes-raised.png) | ![tumbling_cubes, etched](images/pattern-tumbling_cubes-etched.png) |

Interlocking. The rhombille tiling's three rhombi per hexagon sit at three
different heights, which is what sells the stacked-cube illusion; equal heights
would just read as a honeycomb.

### intertwine

| Raised | Etched |
|---|---|
| ![intertwine, raised](images/pattern-intertwine-raised.png) | ![intertwine, etched](images/pattern-intertwine-etched.png) |

Interlocking, and genuinely woven: look at any crossing and one strand is
broken so the other reads as passing over it, alternating all the way round
each ring. Also by far the most expensive pattern to render — roughly two
minutes per image here, the largest single chunk of the script's runtime.

### islamic_star

| Raised | Etched |
|---|---|
| ![islamic_star, raised](images/pattern-islamic_star-raised.png) | ![islamic_star, etched](images/pattern-islamic_star-etched.png) |

Interlocking. Eight-point stars with a four-point cross filling each gap; the
two shapes tile the plane exactly and share whole edges, so the groove between
them is a uniform incised line.

## Full-Pot Examples

The real assembled planter, rendered from `planter.scad` at its shipped
defaults (`pattern_repeat = 16`, `smoothness = 80`) with only `pattern_type`
and `relief_mode` overridden.

| `hex_grid`, raised | `hex_grid`, etched |
|---|---|
| ![pot, hex_grid raised](images/pot-hex_grid-raised.png) | ![pot, hex_grid etched](images/pot-hex_grid-etched.png) |

| `islamic_star`, raised |
|---|
| ![pot, islamic_star raised](images/pot-islamic_star-raised.png) |

**Known limitation — tiles are stretched ~3.2× wider than tall.**
`decorated_solid()` passes `tex_reps = [pattern_repeat, pattern_repeat]`, which
asks for the same number of repeats around the circumference as up the height
without accounting for the pot not being square. On the default planter that
puts 16 tiles around a ~446mm circumference and 16 tiles up a 138mm wall:
**27.9mm wide by 8.6mm tall, an aspect ratio of 3.23**.

This is visible, not theoretical. Compare the `hex_grid` pot above with
[its close-up](#hex_grid) — the hexagons have flattened into wide ribbons. The
`islamic_star` pot shows the worst case: the eight-point stars are smeared into
horizontal bands and the motif is no longer recognisable at all. That is
exactly why this page leads with the flat tile close-ups rather than full-pot
renders.

How much it matters depends on the pattern. `ridges` is immune — vertical
ribs have no vertical period to stretch. `bricks` barely notices, since bricks
are meant to be wider than tall anyway. `hex_grid` above is clearly distorted
but still legible as a hex grid. The large-motif interlocking patterns
(`islamic_star`, `intertwine`, `teardrop`) are the ones that stop working.

The only lever today is `pattern_repeat`: raising it shortens the tiles
vertically, though it also multiplies them around the circumference, since one
parameter drives both axes.

This is pre-existing behaviour, not something this gallery changed, and it is
not fixed: a proper fix means deriving the vertical repeat count from the pot's
actual height-to-circumference ratio instead of reusing `pattern_repeat`. The
repository does not use GitHub issues, so there is no issue link to point at —
this section is the tracking record.

## Insert Presets

`insert_preset` resolves `insert_top_d` / `insert_bottom_d` / `insert_height`
to a named size. All three renders use the same fixed camera (no `--viewall`),
so the sizes are directly comparable rather than each normalised to fill the
frame. Everything else is at defaults, including `pattern_type = "ridges"`.

| `"small"` (100 / 75 / 85) | `"medium"` (130 / 100 / 120) | `"large"` (180 / 125 / 160) |
|---|---|---|
| ![small preset](images/preset-small.png) | ![medium preset](images/preset-medium.png) | ![large preset](images/preset-large.png) |

## Outer Shape Modes

| `"follow"` | `"custom"` |
|---|---|
| ![outer_mode follow](images/outer-follow.png) | ![outer_mode custom](images/outer-custom.png) |

`"follow"` wraps the outer body around the insert's own taper at a constant
`wall_thickness`. `"custom"` ignores the taper and builds whatever
`outer_top_d` / `outer_bottom_d` / `outer_height` describe, subject to the
containment asserts in `planter.scad`.

The custom render here uses `outer_top_d = 180`, `outer_bottom_d = 180`,
`outer_height = 175` — a straight-sided, taller shell — rather than
`planter.scad`'s stock custom values (172 / 130 / 145). Those stock values are
tuned to sit just outside the default insert, so a render of them is almost
indistinguishable from `"follow"` and the pair would show nothing.

## Regenerating These Images

```bash
./docs/images/render.sh              # everything, ~13 minutes
./docs/images/render.sh outer- pot-  # only names with these prefixes
```

The script hard-fails if any render's console output contains `CGAL error`.
That check is load-bearing: `tumbling_cubes`, `intertwine` and `islamic_star`
abort CGAL at some `pattern_repeat`/`smoothness` combinations, and when they do
OpenSCAD still exits 0 and still writes a plausible-looking PNG. See README.md,
"Note on the interlocking patterns and CGAL". The `WARNING:` line those three
print on every render is a proactive notice, not a failure.
