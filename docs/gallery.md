# Pattern Gallery

Every `pattern_type` this generator offers, plus the insert presets and outer
shape modes. Every pattern shows both `relief_mode` values except `"none"`,
which has no texture at all so `relief_mode` cannot change anything. All
images are real OpenSCAD renders produced by
[`images/render.sh`](images/render.sh) — nothing here is drawn by hand or
touched up.

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
  - [tetrakis_square](#tetrakis_square)
  - [kisrhombille](#kisrhombille)
  - [triakis_triangular](#triakis_triangular)
  - [rhombille](#rhombille)
  - [cairo_pentagonal](#cairo_pentagonal)
  - [floret_pentagonal](#floret_pentagonal)
  - [deltoidal_trihexagonal](#deltoidal_trihexagonal)
- [Full-Pot Examples](#full-pot-examples)
- [Insert Presets](#insert-presets)
- [Outer Shape Modes](#outer-shape-modes)
- [Regenerating These Images](#regenerating-these-images)

## Pattern Comparison

**These are square-tile close-ups, not pictures of a pot.** Each one is a
`decorated_solid()` cylinder whose height equals its own circumference, so
the vertical repeat count `_square_tile_vertical_reps()` derives comes out
equal to the horizontal one for 18 of the 21 patterns — the three sqrt(3)-
corrected patterns (`cubes`, `hex_grid`, `tri_grid`) instead render with a
vertical repeat count of 18, not 32, so their tiles are ~17.7mm wide by
~31.4mm tall rather than literally square. Every pattern is still shown at
its own designed proportions: for those three, a true isometric cube /
regular hexagon / equilateral triangle is not square to begin with, so
matching their designed proportions means being non-square on purpose. On
the actual planter, tiles are only *exactly* square at the
wall's mean radius — the wall is a cone, and the vertical repeat count is
fixed for the whole wall while BOSL2 scales each texture strip to the local
radius as it revolves. At shipped defaults this leaves a small residual: tiles
run **roughly 0.87× wide-to-tall at the bottom rim to 1.17× at the top rim**
— see [Full-Pot Examples](#full-pot-examples) below for what that residual
taper looks like, and why these close-ups (free of it) lead the page instead.

Settings shared by every image in this section: `r1 = r2 = 90mm`,
`height = 565.5mm` (= 2πr), `pattern_repeat = 32` (so tiles are ~17.7mm wide,
and square for 18 of the 21 patterns — see above for the three exceptions),
`pattern_depth = 1.5` and `smoothness = 60` (the shipped defaults),
`pattern_orientation = "vertical"`. Uniform across all of them, so the images
are comparable with each other.

Two rendering caveats worth knowing before you read the pictures:

- **The camera is ~25° off-axis** in both azimuth and elevation, not dead-on.
  OpenSCAD's light is mounted on the camera, so a straight-on shot hits every
  flat plateau at the same angle and the patterns built from flat islands
  (`tumbling_cubes`, `intertwine`, `islamic_star`, `rhombille`,
  `cairo_pentagonal`, `floret_pentagonal`, `deltoidal_trihexagonal`) wash out
  to almost nothing.
  25° rakes the light across the relief. It compresses both axes by about the
  same `cos(25°) = 0.91`, so tile aspect is essentially preserved.
- **The relief reads slightly deeper here than it will on a printed pot.** The
  depth is the real default (1.5mm), but these tiles are 17.7mm across where
  the default pot's tiles are ~24–32mm depending on height (the wall tapers,
  see below), so the depth-to-width ratio is 8.5% here versus roughly 4.6–
  6.3% on the pot.

### none

No texture at all — a plain wall. `relief_mode` has nothing to act on, so
there is only one image.

| Plain |
|---|
| ![none](images/pattern-none-raised.png) |

The faint vertical banding is the `smoothness = 60` facets of the cylinder
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

Flat hexagonal panels (raised) divided by V-groove borders (recessed) — a
honeycomb grid, same family as `diamonds` above. BOSL2's docs note the tile
needs a `sqrt(3)` vertical scale for the V-groove width to be uniform on all
six sides of each hexagon; `_square_tile_vertical_reps()` applies it by
folding the `sqrt(3)` factor into the vertical repeat count, so the hexagons
here render regular rather than stretched.

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

A two-level checkerboard. `tex_inset=true` shifts the whole height profile
radially inward by exactly the pattern's depth rather than inverting it in
place, and on this curved wall that comes out visibly different from raised,
not just a relabeling of the same shape — an earlier draft of this page
claimed the two would render identically and was wrong; measured directly
(RMSE ≈ 0.12 between the two renders below) before writing this.

| Raised | Etched |
|---|---|
| ![checkers, raised](images/pattern-checkers-raised.png) | ![checkers, etched](images/pattern-checkers-etched.png) |

### dots

| Raised | Etched |
|---|---|
| ![dots, raised](images/pattern-dots-raised.png) | ![dots, etched](images/pattern-dots-etched.png) |

The clearest raised/etched pair on the page: genuine bumps versus genuine
dimples. `dots` is the one pattern that needs a negative `tex_depth` rather
than a plain inset to invert properly — without it the etched version would be
the same bump pushed below the surface.

### cubes

| Raised | Etched |
|---|---|
| ![cubes, raised](images/pattern-cubes-raised.png) | ![cubes, etched](images/pattern-cubes-etched.png) |

**Aspect note:** BOSL2's own docs for the `"cubes"` texture say it needs an
extra `sqrt(3)` vertical scale to render at its true isometric proportions
(`lib/BOSL2/skin.scad`, the "cubes" texture example). `_square_tile_vertical_reps()`
applies that correction by folding the `sqrt(3)` factor into the vertical
repeat count itself, so both the tile-squaring fix and this per-texture
correction come from the same formula.

### tri_grid

Flat triangular panels (raised) divided by V-groove borders (recessed) — the
same groove-bordered-panel family as `diamonds`/`hex_grid`, just on a
triangular grid instead of hexagonal. Same `sqrt(3)` correction as `hex_grid`
and `cubes` above, applied the same way.

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

### tetrakis_square

| Raised | Etched |
|---|---|
| ![tetrakis_square, raised](images/pattern-tetrakis_square-raised.png) | ![tetrakis_square, etched](images/pattern-tetrakis_square-etched.png) |

Conway's "kis" operation applied to the square tiling: each unit tile is fanned
into four isosceles right triangles from its own center point, like a
pinwheel. Not interlocking in the sense the four patterns above are — the
kis-cell here is the whole unit tile, so the fan never crosses a tile
boundary; adjacent tiles simply repeat, they don't join into one continuous
motif.

Relief works differently here than for any of the fourteen patterns above:
raised gives the four triangles alternating heights (a genuine pinwheel, not a
flat panel), while etched is a single flat height across all four with only a
thin engraved groove marking the fan lines — a flat panel with a scribed
pattern, not an inverted copy of the raised relief. All three "kis"-family
patterns below share this same raised/etched behavior, and so does
`floret_pentagonal` at the end of this section — it is not a kis-operation
tiling, but its 6-pentagon rosette is the same kind of fan around a shared
point, so its two relief modes are genuinely different VNFs too.

### kisrhombille

| Raised | Etched |
|---|---|
| ![kisrhombille, raised](images/pattern-kisrhombille-raised.png) | ![kisrhombille, etched](images/pattern-kisrhombille-etched.png) |

Kis applied to `tumbling_cubes`'s own rhombille tiling: each of its three
rhombi per hexagon is itself fanned into four triangles from its center,
instead of being left as one flat plateau — twelve facets per hexagon in
total. Reuses `tumbling_cubes`'s exact hexagon/rhombus geometry, so the two
patterns' motifs line up cell-for-cell; this one is just fanned rather than
raised as flat plateaus.

Same relief behavior as `tetrakis_square`: raised alternates two heights
across each rhombus's four-triangle fan; etched flattens every triangle to one
height and leaves only the engraved fan lines, rather than inverting the
raised bumps.

### triakis_triangular

| Raised | Etched |
|---|---|
| ![triakis_triangular, raised](images/pattern-triakis_triangular-raised.png) | ![triakis_triangular, etched](images/pattern-triakis_triangular-etched.png) |

Kis applied to a triangular tiling: the unit tile's diagonal splits it into
two triangles, and each of those is fanned into three sub-triangles from its
center. These two base triangles are right triangles from the square split,
not true equilateral ones — a deliberate simplification, the same trade-off
`kisrhombille` makes by reusing `tumbling_cubes`' already-unit-square-normalized
hexagons, prioritizing an exact unit-square tiling over strict equilateral
regularity. Three distinct heights per fan (not two, unlike `tetrakis_square`'s
alternation) — the same reasoning `tumbling_cubes` uses for its three rhombi,
that three different heights read better than two repeated.

Same relief behavior as the other two "kis"-family patterns above: raised
gives three real heights per fan; etched flattens every triangle to one height
with only the engraved fan lines, a flat scribed panel rather than an inverted
raised bump.

### rhombille

| Raised | Etched |
|---|---|
| ![rhombille, raised](images/pattern-rhombille-raised.png) | ![rhombille, etched](images/pattern-rhombille-etched.png) |

Interlocking. The plain rhombille tiling `tumbling_cubes`'s isometric-cube
illusion is built from: the exact same hexagon/rhombus geometry, but every
rhombus raised to the same height instead of three different ones, so it
reads as a clean rhombus-grid relief rather than a set of stacked cubes.
Because the geometry doesn't change between raised and etched, `"etched"`
here is a true inverted copy of the raised relief, not a separate flat-panel
construction like the "kis" family above.

### cairo_pentagonal

| Raised | Etched |
|---|---|
| ![cairo_pentagonal, raised](images/pattern-cairo_pentagonal-raised.png) | ![cairo_pentagonal, etched](images/pattern-cairo_pentagonal-etched.png) |

Interlocking. The Cairo pentagonal tiling (Wikipedia "V3^2.4.3.4", dual of the
snub square tiling): congruent, irregular pentagons — four long edges and one
short edge, two non-adjacent right angles — every pentagon raised to the same
height. Because the geometry doesn't change between raised and etched,
`"etched"` here is a true inverted copy of the raised relief, like
`rhombille`, not a separate flat-panel construction like the "kis" family.

### floret_pentagonal

| Raised | Etched |
|---|---|
| ![floret_pentagonal, raised](images/pattern-floret_pentagonal-raised.png) | ![floret_pentagonal, etched](images/pattern-floret_pentagonal-etched.png) |

Interlocking. The floret pentagonal tiling (Wikipedia "V3^4.6", dual of the
snub trihexagonal tiling): rosettes of 6 congruent, irregular pentagons
pinwheel around a shared hub point (four 120-degree angles and one
60-degree angle per pentagon). Unlike `cairo_pentagonal`/`rhombille`, each
rosette is a multi-facet fan around a shared point, the same shape of
structure the "kis" family's own fans have -- so, like that family,
`"etched"` here is a genuinely different, flat-panel VNF (every pentagon at
the tile's full height, with only a thin engraved groove between them), not
an inverted copy of the raised relief, which instead alternates heights
around the rosette for a pinwheel-blade look.

### deltoidal_trihexagonal

| Raised | Etched |
|---|---|
| ![deltoidal_trihexagonal, raised](images/pattern-deltoidal_trihexagonal-raised.png) | ![deltoidal_trihexagonal, etched](images/pattern-deltoidal_trihexagonal-etched.png) |

Interlocking. The deltoidal trihexagonal tiling (Wikipedia "V3.4.6.4", dual
of the rhombitrihexagonal tiling): congruent kite/deltoid quadrilaterals --
two short edges and two long edges, with a line of symmetry through the
kite's two "pointy" vertices (a hexagon-centroid hub and a triangle-centroid
tip). Every kite belongs to three different, simultaneously-competing fan
types at once (a 6-fan around each hub, a 4-fan around each square-centroid
vertex, and a 3-fan around each tip) -- since no single alternating-height
scheme can respect all three, every kite is raised to the same uniform
height instead, like `cairo_pentagonal`/`rhombille`. Because the geometry
doesn't change between raised and etched, `"etched"` here is a true
inverted copy of the raised relief, not a separate flat-panel construction
like the "kis" family/`floret_pentagonal`.

## Full-Pot Examples

The real assembled planter, rendered from `planter.scad` at its shipped
defaults (`pattern_repeat = 16`, `smoothness = 60`) with only `pattern_type`
and `relief_mode` overridden.

| `hex_grid`, raised | `hex_grid`, etched |
|---|---|
| ![pot, hex_grid raised](images/pot-hex_grid-raised.png) | ![pot, hex_grid etched](images/pot-hex_grid-etched.png) |

| `islamic_star`, raised |
|---|
| ![pot, islamic_star raised](images/pot-islamic_star-raised.png) |

**Fixed: tiles now come out approximately square.** `decorated_solid()` used
to pass `tex_reps = [pattern_repeat, pattern_repeat]`, asking for the same
number of repeats around the circumference as up the height regardless of the
pot's proportions — on the default pot (~440mm circumference, ~138mm height)
that made every tile ~3.2× wider than tall. `_square_tile_vertical_reps()`
(`modules/decoration.scad`) now derives the vertical repeat count from the
pot's real height and circumference instead, so tiles come out square at the
wall's mean radius.

A small residual remains because the decorated wall is a cone, not a
cylinder — `planter.scad`'s own peak-aware calculation puts its radius at
~61mm at the bottom growing to ~82.3mm at the top, and BOSL2 scales each
texture strip to the *local* radius as it revolves
(`lib/BOSL2/skin.scad`'s `_textured_revolution()`), while a single vertical
repeat count is fixed for the whole wall. At shipped defaults (`pattern_repeat
= 16`) that leaves tiles running **roughly 0.87× wide-to-tall at the bottom
rim to 1.17× at the top rim** — a small taper effect, not the ~2.8–3.75×
distortion this page used to document here.

Compare the `hex_grid` pot above with [its close-up](#hex_grid) — the
hexagons are recognizably regular now, not flattened into ribbons. The
`islamic_star` pot likewise shows a clean, legible eight-point-star motif
rather than a smeared band. That's also why this page can lead with the flat
tile close-ups without them misrepresenting the full-pot look anymore — they
were always the "designed proportions" reference, and the full pot is now
close to matching them.

## Insert Presets

`insert_preset` resolves `insert_top_d` / `insert_bottom_d` / `insert_height`
to a named size. All three renders use the same fixed camera (no `--viewall`),
so the sizes are directly comparable rather than each normalised to fill the
frame. Everything else is at defaults, including `pattern_type = "ridges"` --
at pot scale, its 16 tiles are barely distinguishable from the cylinder's own
60-facet smoothness, so these pots read as plain. These
sections are about silhouette and size, not decoration; see
[Pattern Comparison](#pattern-comparison) for what the patterns themselves
look like.

| `"small"` (100 / 75 / 85) | `"medium"` (130 / 100 / 120) | `"large"` (180 / 125 / 160) |
|---|---|---|
| ![small preset](images/preset-small.png) | ![medium preset](images/preset-medium.png) | ![large preset](images/preset-large.png) |

## Outer Shape Modes

Both at default `pattern_type = "ridges"`, which — like the presets above —
reads as plain at pot scale; these renders are about silhouette, not
decoration.

| `"follow"` | `"custom"` |
|---|---|
| ![outer_mode follow](images/outer-follow.png) | ![outer_mode custom](images/outer-custom.png) |

`"follow"` wraps the outer body around the insert's own taper at a constant
`wall_thickness` -- when `pattern_type = "none"`. These renders use the
default `pattern_type = "ridges"` instead, and with a pattern active
`planter.scad` approximates the decorated wall as a straight cone through
the cavity's peak radius rather than exactly following the insert's
ledge/shoulder profile (see "Note: enabling decoration..." in README.md), so
the wall thickness isn't perfectly constant here even in `"follow"` mode.
`"custom"` ignores the taper either way and builds whatever
`outer_top_d` / `outer_bottom_d` / `outer_height` describe, subject to the
containment asserts in `planter.scad`.

The custom render here uses `outer_top_d = 180`, `outer_bottom_d = 180`,
`outer_height = 175` — a straight-sided, taller shell — rather than
`planter.scad`'s stock custom values (172 / 130 / 145). Those stock values are
tuned to sit just outside the default insert, so a render of them is almost
indistinguishable from `"follow"` and the pair would show nothing.

## Regenerating These Images

```bash
./docs/images/render.sh              # everything, ~10-15 minutes (dominated by "intertwine" and "bricks")
./docs/images/render.sh outer- pot-  # only output-file prefixes
./docs/images/render.sh islamic_star # only this pattern's close-ups (raised + etched)
```

The script hard-fails if any render's console output contains `CGAL error`.
That check is load-bearing: `tumbling_cubes`, `intertwine`, `islamic_star`,
`rhombille`, `cairo_pentagonal` and `floret_pentagonal` abort CGAL at some
`pattern_repeat`/`smoothness` combinations, and when they do OpenSCAD still
exits 0 and still writes a plausible-looking PNG. See README.md, "Note on the
interlocking patterns and CGAL". The `WARNING:` line those six print on every
render is a proactive notice, not a failure.
