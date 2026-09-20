# Relief Mode Redesign: True Outline Etching + New "Alternating" Mode

## Problem

`relief_mode` currently has two values, `"raised"` and `"etched"`, but `"etched"`
does not do what was originally wanted for most patterns. The original intent
(TODO.md): etched should read as a design *engraved into stone or glass* — the
wall stays flat, and only a thin incised line traces each motif's outline.

That is only true today for `"ridges"`, `"pyramids"`, `"diamonds"` (and
`"hex_grid"`/`"tri_grid"`, which shift the same panel/groove relief inward).
Every other pattern's `"etched"` instead sinks the *whole* motif as a recessed
copy of the raised relief:

- `"rhombille"`, `"cairo_pentagonal"`, `"tumbling_cubes"`, `"islamic_star"`,
  `"teardrop"`, `"intertwine"`: a true inverted copy of the entire raised
  motif (or, for `"teardrop"`/`"intertwine"`, no separate etched geometry at
  all beyond `tex_inset`).
- The "kis" family (`"tetrakis_square"`, `"kisrhombille"`, `"triakis_triangular"`)
  and `"floret_pentagonal"`: a separate flat-panel VNF with a thin groove
  *between* sub-facets — closer to the outline idea, but the groove traces
  internal facet boundaries, not the motif's outer silhouette.
- `"dots"`, `"cubes"`, `"checkers"`, `"bricks"` (BOSL2-native heightfields):
  sink into a dimple, same as the first group.

Separately, Barrett wants a genuinely new visual option: a relief where the
pattern alternates between raised (proud of the wall) and sunk (recessed into
the wall) in a single render, rather than uniformly one or the other. This is
being added as a **third `relief_mode` value**, not folded into `"raised"` —
`"raised"`'s existing look must not change for anyone with a saved design.

## Goals

1. `"raised"` — **unchanged**. No pattern's raised geometry changes.
2. `"etched"` — reworked so every pattern reads as a true outline engrave:
   flat wall, thin V-groove around each motif's *outer* silhouette only, no
   internal sub-facet grooves and no whole-shape inversion.
3. `"alternating"` (new) — bas-relief: within one tile, some copies of the
   motif sit above the nominal wall surface and others sit below it, in a
   single render (not achieved by unioning separate raised/etched passes).
4. Every existing pattern keeps working; patterns that cannot support a mode
   cleanly say so via an assertion, not silently wrong geometry.

## Background: what BOSL2 actually allows

Two facts, confirmed against the real BOSL2 source (`lib/BOSL2/skin.scad`),
that shape every choice below:

- **BOSL2 always stamps the same tile content at every repeat position.**
  `_textured_point_array()`'s repeat loop closes over one `vnf`/`texture`
  value and transforms it identically at every `(x, y)` grid cell — there is
  no way to make BOSL2 alternate between two different tiles across repeats.
  Any alternation has to be baked into the *content of one tile*, the same
  trick BOSL2's own `"checkers"` catalog texture already uses (one `[0,1]`
  tile contains a 2x2 mini-checkerboard, not two tiles swapped at the grid
  level). This project's own custom tiles already do the analogous thing for
  other reasons — `_tumbling_cubes_tile()`/`_rhombille_tile()` pack 5 hexagon
  copies into one unit tile via `_TC_CENTERS`, `_cairo_pentagonal_tile()`
  packs 8 pentagon placements, etc.
- **`tex_inset` is a real scalar reference point, not just a boolean**, and
  the height formula is linear per vertex around it:
  `_tex_height(scale, inset, z) = (z - inset) * scale` (for `scale >= 0`).
  BOSL2 does not clamp a tile's Z to `[0,1]` anywhere (`_validate_texture`
  only checks X/Y) — that range is this project's own convention. Since the
  formula is linear and independent per vertex, a tile whose Z values
  straddle `inset` (e.g. `inset = 0.5`, some vertices at `z = 1`, others at
  `z = 0`) renders **both** raised bumps (`z > inset`) **and** sunk dimples
  (`z < inset`) in one `cyl(texture = ...)` call. No boolean union/difference
  workaround is needed for `"alternating"`.

These two facts are why both new modes are implementable as *pure tile
construction* changes: `decorated_solid()`'s single `cyl(texture = ...)` call
stays the architecture: only what a pattern's tile function returns, and what
`tex_inset` is set to, differ per mode.

## Design

### Shared infrastructure: two new tile builders alongside `_tile_from_islands()`

Every one of this project's 10 custom VNF tiles (`teardrop`, `tumbling_cubes`,
`intertwine`, `islamic_star`, `tetrakis_square`, `kisrhombille`,
`triakis_triangular`, `rhombille`, `cairo_pentagonal`, `floret_pentagonal`) is
already built as a list of `[region, height]` islands, fed to
`_tile_from_islands()`. That islands list is the natural shared input for both
new modes — no per-pattern outline-tracing or alternation logic needs
writing 10 times.

**`_tile_outline_from_islands(islands, gap)`** (etched): unions every
island's *region* (ignoring height — outline mode doesn't care which parts
were tall) into one footprint, then returns a flat tile at `z = 1`
everywhere except a thin V-groove (width `gap`, same `offset()` idiom every
existing groove already uses) traced along that union's *outer* boundary
only. Concretely: build the ground as `_UNIT_TILE` minus the union, at
`z = 0`; build the union's own outline as a thin band (`region` minus
`offset(region, delta = -gap)`) also at `z = 0`; leave the union's interior
at `z = 1`. This collapses any internal seams between adjacent/touching
islands (e.g. `tumbling_cubes`' three rhombi per hexagon become one hexagon
outline, not three separate rhombus outlines) — which is exactly the "outer
silhouette only" decision already made.

**`_tile_alternating_from_islands(islands, gap, high_indices)`**
(alternating): like `_tile_from_islands()`, but every island's height is
forced to either `1` or `0` (not the island's own original height) according
to whether its index is in `high_indices`, and the caller uses
`tex_inset = 0.5` rather than `tex_inset = false`/`true` so `decorated_solid()`
renders the `0`-height islands as sunk and the `1`-height islands as raised,
in one pass. `high_indices` is a per-pattern choice (see below) — usually
"alternate by the pattern's own existing lattice parity", reusing whatever
index already distinguishes copies within the tile (e.g. `_TC_CENTERS`'
5 positions, `_CP_PLACEMENTS`'/`_FP_PLACEMENTS`' placement index).

Both builders live in `modules/decoration.scad` next to `_tile_from_islands()`
and reuse its existing `_tile_quantize()`/clipping/winding machinery — they
are new *assemblers* over the same islands data, not a new geometry pipeline.

### Per-pattern classification

| Pattern | Raised (unchanged) | Etched (new) | Alternating (new) |
|---|---|---|---|
| `none` | — | — | not applicable (no texture) |
| `ridges`, `pyramids`, `diamonds`, `hex_grid`, `tri_grid` | BOSL2 heightfield | **unchanged** — already a true outline/panel engrave | not supported yet (see Phase 2) |
| `dots`, `cubes`, `checkers`, `bricks` | BOSL2 heightfield, unchanged | Phase 2 (see below) | Phase 2 |
| `teardrop`, `tumbling_cubes`, `intertwine`, `islamic_star`, `tetrakis_square`, `kisrhombille`, `triakis_triangular`, `rhombille`, `cairo_pentagonal`, `floret_pentagonal` | unchanged | `_tile_outline_from_islands()` on the pattern's existing islands list | `_tile_alternating_from_islands()` on the same islands list |

**Phase 1** (this plan) covers the bottom row — the 10 already-islands-based
custom VNF tiles — plus wiring `"alternating"` into `PATTERN_TYPES` as a
`relief_mode` value (not a `pattern_type`) with a clear assertion for
patterns that don't support it yet.

**Phase 2** (separate, future plan, not detailed here): convert `"dots"`,
`"cubes"`, `"checkers"`, `"bricks"` from BOSL2-native heightfields into
custom islands-based VNF tiles of our own (each is a small, well-understood
shape — a circle, an isometric rhombus pair, a 2x2 checker split, a brick
rectangle), so they can plug into the same two shared builders. `"raised"`
mode for these four is unaffected either way (Phase 1 or 2) — only `"etched"`/
`"alternating"` depend on the conversion. `"ridges"`/`"pyramids"`/
`"diamonds"`/`"hex_grid"`/`"tri_grid"` are not part of Phase 2's scope: their
etched mode already satisfies the goal, and giving them `"alternating"` would
need a similar from-scratch conversion with no clear payoff yet — revisit only
if wanted later.

### `relief_mode` validation

`decorated_solid()`'s existing `assert(in_list(pattern_type, PATTERN_TYPES), ...)`
gets a sibling: `relief_mode` must be one of `["raised", "etched", "alternating"]`,
and if `relief_mode == "alternating"`, `pattern_type` must be one of the
islands-based custom VNF tiles (Phase 1's list) or `"none"` is rejected too
(no texture to alternate) — assert with a clear message naming which
pattern_types currently support `"alternating"`, rather than silently
falling back to `"raised"`.

### Per-pattern `high_indices` choice for `"alternating"`

Each pattern already has a natural index to alternate by — no new geometry,
just a different height assignment against the same existing islands list:

- `tumbling_cubes`/`rhombille`: by hexagon-center index (`_TC_CENTERS` has 5
  positions per tile — alternate e.g. `[0,3]` high, `[1,2,4]` low, or a
  parity rule over the hexagon lattice `(m,n)` if that reads better once
  rendered — confirm visually during implementation, this is a design
  judgment call, not a derived fact).
- `cairo_pentagonal`/`floret_pentagonal`: by placement/orientation index
  (`_CP_PLACEMENTS`'/`_FP_PLACEMENTS`' own `k` — `floret_pentagonal` already
  has a working "even k high, odd k low" rule for its *raised* mode's
  existing alternation; reuse that same parity, just mapped to `1`/`0`
  instead of `1`/`_FP_Z_LO`, with `tex_inset = 0.5`).
- The "kis" family: by fan-triangle index within each centroid fan (already
  alternates 2 or 3 heights in raised mode for the pinwheel look — reuse that
  same index, collapsed to high/low).
- `teardrop`: by column (column A high, column B low, or vice versa).
- `intertwine`: by ring-center index (`_IW_CENTERS`).
- `islamic_star`: star high, all 4 crosses low (or some other split — visual
  judgment call during implementation).

None of this requires deriving new geometry: every island in every list above
already exists for raised mode. `"alternating"` mode only changes which
height (`0` or `1`) each existing island gets, plus `tex_inset = 0.5` instead
of `false`.

### `decorated_solid()` wiring

```
tex = _decoration_texture(pattern_type, relief_mode);
...
tex_inset = (relief_mode == "etched") ? true
          : (relief_mode == "alternating") ? 0.5
          : false;  // "raised"
```

`_decoration_texture()` gains a `relief_mode == "alternating"` branch per
pattern, parallel to its existing `relief_mode == "etched"` branch — most
patterns' tile functions already take `relief_mode` as a parameter (the "kis"
family, `floret_pentagonal`) or will need to start taking one
(`rhombille`/`cairo_pentagonal`, currently mode-independent, need a real
branch now that `"etched"`'s geometry actually differs from `"raised"`'s).

### Test strategy

- Every Phase-1 pattern's existing `test_decoration_<name>.scad` gains an
  `"alternating"` block alongside its existing `"raised"`/`"etched"` checks:
  assert the resolved VNF's Z levels are exactly `{0, 1}` (not the pattern's
  own raised heights), assert it differs from both the raised and etched VNF,
  and render it through the same CGAL-forcing `difference()` every other mode
  already gets.
- `test_decoration_pattern_types.scad`/`test_decoration_etched_groove.scad`
  gain the same kind of expected-list update this project already does for
  every new pattern/mode addition.
- A new invalid-`relief_mode` negative test (mirroring
  `test_decoration_invalid_pattern_type.scad`): confirms
  `relief_mode="alternating"` on a non-supporting `pattern_type` (e.g.
  `"ridges"` or `"dots"`, until Phase 2) fails with the documented message,
  and confirms a bogus `relief_mode` string fails too (this project has never
  validated `relief_mode` at all until now — worth confirming that gap is
  real before assuming it, during implementation).
- The etched rework needs the *same* CGAL-fragility sweep discipline every
  new pattern has gotten: outline geometry is a different VNF from both
  today's etched and from raised, so it needs its own
  `pattern_repeat`/`smoothness` sweep in `decorated_solid()`'s warning
  bucket, not an assumption that it inherits raised's or old-etched's
  measured safety.

### Documentation impact

README's whole "etched" discussion (the paragraph structure documented in
"Problem" above) gets rewritten to describe the new, uniform outline-engrave
behavior, replacing the current per-pattern-family explanation of why etched
differs — after this change, etched works the same way for every Phase-1
pattern, so the documentation should get *simpler*, not just updated in
place. Gallery images for every affected pattern's `"etched"` example need
regenerating, and new `"alternating"` example images need adding throughout.
TODO.md's etched-mode item gets checked off once this ships; a new backlog
item is added for Phase 2 (the four BOSL2-native pattern conversions).

## Open questions for Barrett

1. **Phase 1 scope confirmation**: are you fine with `"alternating"` only
   working for the 10 islands-based custom patterns at first (with a clear
   error for the others), rather than blocking this whole redesign on
   converting `dots`/`cubes`/`checkers`/`bricks` too?
2. **`high_indices` visual judgment calls**: the per-pattern alternation
   choices above (which islands go high vs low for `tumbling_cubes`,
   `islamic_star`, etc.) are proposals, not derived facts — expect the
   implementer to render a few candidates and pick the one that reads best,
   the same way `floret_pentagonal`'s existing raised-mode alternation was
   chosen. Fine to leave that as an implementation-time call?
3. **Existing "kis" family etched behavior**: today their etched mode is
   already "flat panel + groove between facets" (closer to what you want
   than most patterns, just tracing internal facets instead of the outer
   silhouette). Under this redesign their etched mode changes too (outer
   silhouette only, internal facet grooves disappear) — confirming that's
   wanted, not just the patterns that were clearly wrong before.

## Rollout

Given the scope (a new shared mechanism plus per-pattern wiring across 10
existing tiles), this should go through the same plan → worktree →
subagent-driven-development flow already used for each pattern addition, but
as its own dedicated plan — not folded into the next tessellation-pattern PR.
Suggest splitting into two plans/PRs: (1) the shared
`_tile_outline_from_islands()`/`_tile_alternating_from_islands()` helpers plus
`relief_mode` validation, landed against 2-3 patterns first as a proof of the
mechanism; (2) the remaining patterns, once the mechanism is proven out.
