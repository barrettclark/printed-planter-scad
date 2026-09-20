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
2. `"etched"` — reworked so every pattern reads as a true engrave: flat wall,
   a groove around each motif's *outer* silhouette, plus — where a motif has
   real internal sub-facet structure (the "kis" family's fan triangles,
   `floret_pentagonal`'s rosette blades, `tumbling_cubes`'/`rhombille`'s
   multi-rhombus hexagons, `cairo_pentagonal`'s multi-pentagon placements) —
   a second, visually secondary groove tracing those internal boundaries
   too, thinner and/or shallower than the outer-silhouette groove so the two
   read as a clear hierarchy (motif outline first, internal detail second),
   not a wash of equally-weighted lines. No whole-shape inversion, ever.
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

9 of this project's 10 custom VNF tiles (`tumbling_cubes`, `intertwine`,
`islamic_star`, `tetrakis_square`, `kisrhombille`, `triakis_triangular`,
`rhombille`, `cairo_pentagonal`, `floret_pentagonal`) are already built as a
list of `[region, height]` islands, fed to `_tile_from_islands()`. But that
*already-built* islands list is **not** directly reusable as input to either
new builder — see the two corrections below, both confirmed against the real
code and both real enough to change the shape of this section:

**Correction 1 — the outline builder needs pre-shrink geometry, not the
already-gapped islands list.** Every existing island-building loop shrinks
its own region away from its neighbours *before* handing it to
`_tile_from_islands()` (`offset(delta = -gap/2, ...)` — e.g.
`_TC_GAP`/`_KIS_GAP` at `modules/decoration.scad:310-320`/`265-270`). That
shrink is what creates today's raised-mode groove between adjacent facets.
It also means the shrunk islands never actually touch each other — three
originally-adjacent rhombi in one `tumbling_cubes` hexagon become three
separate, disconnected shapes with a real gap between all of them.
`union([for (il = islands) il[0]])` over these already-disconnected pieces
does **not** merge them back into one motif silhouette; it just returns the
same scattered pieces, and every edge of every piece looks equally "outer" —
there is no way to recover which edges were the motif's true outer boundary
versus internal facet seams from the shrunk data alone. The outline builder
therefore needs the **original, unshrunk** region data grouped by motif —
concretely, each pattern's islands-building loop needs to also produce (or
the outline path needs to be built from) a list of *motif groups*, each
group being the original (pre-`offset()`) sub-regions that make up one
motif instance (e.g. one hexagon's 3 original rhombi, one kis-fan's N
original triangles; a pattern with one flat shape per motif is simply a
group of size 1). Within one group, unioning the *original* (still-touching)
sub-regions gives the true outer silhouette; the internal boundaries between
a group's own sub-regions (recoverable because they still share exact edges
before any shrink) give the secondary groove. This is a real, non-trivial
change to how several patterns build their islands, not just a new consumer
of existing data — call it out as its own step in Task 1, per-pattern, not a
one-line addition.

**`_tile_outline_from_islands(motif_groups, outer_gap, inner_gap)`** (etched),
with the corrected input above: for each group, union its own original
sub-regions into the group's outer silhouette; union all groups' silhouettes
together for the tile-wide "raised region" (used only to compute the
ground/panel split, at `z = 1` everywhere inside it, `z = 1` minus a primary
groove along the *outer* boundary of that combined silhouette); trace each
group's own internal sub-region boundaries as the secondary groove. Two
groove tiers, both edge-aware the same way:

1. Primary groove (width `outer_gap`) along the combined outer silhouette —
   **not** along any portion of that boundary that coincides with the
   tile's own edge (`x` or `y` equal to `0` or `1`). `_tile_walls()` already
   solves exactly this problem for vertical walls (an island that straddles
   a tile edge continues into the neighbouring tile there, so there is no
   wall — see `_tile_on_edge()`), and the outline groove needs the identical
   exception: a naive whole-boundary offset would carve a groove along
   every tile-repeat seam for any interlocking motif, which is wrong — one
   continuous silhouette would look like a visible grid instead. Build the
   thin band *per boundary segment* (the way `_tile_walls()` iterates
   `path[i]`/`path[i+1]` pairs), omitting the groove on any segment
   `_tile_on_edge()` already recognizes as shared with a neighbour.
2. Secondary groove (width `inner_gap`, and/or a shallower depth than the
   primary groove — an implementation-time call on which reads better,
   width, depth, or both) along each group's own internal sub-region
   boundaries — the edges that existed in the group's *original*,
   pre-shrink geometry and are shared between two of that group's own
   sub-regions. This is what keeps, for example, the "kis" family's
   individual fan-triangle edges or `tumbling_cubes`'/`rhombille`'s
   per-rhombus edges visible as a lighter secondary line, rather than
   discarding them into one undifferentiated hexagon/rosette outline.
   Groups with only one sub-region (nothing internal to trace) simply
   produce an empty secondary-groove contribution — this degrades
   gracefully, not as a special case to code around.

Work out the exact per-segment construction for both tiers, and the exact
shape each pattern's islands-building loop needs to also expose its
pre-shrink motif groups, during implementation (Task 1's own job, not this
spec's) — this section is scoped to state the requirement correctly, not to
hand over working code for it.

**Correction 2 — the alternating builder needs its own nominal-wall ground
plane, not `_tile_from_islands()`'s hardcoded one.**
`_tile_from_islands()`'s `ground` (the `_UNIT_TILE` area outside every
island) is always built at `z = 0` with no `transform` applied
(`modules/decoration.scad:233-236`) — it has no relationship to `tex_inset`
at all; it is simply the tile's floor. With `tex_inset = 0.5`, the real
formula `(z - inset) * scale` sends that entire `z = 0` ground to
`(0 - 0.5) * depth`, i.e. it sinks the whole background by half depth along
with every low island, instead of sitting at the neutral wall surface the
alternating design actually needs there. Reusing `_tile_from_islands()`
verbatim with 0/1 island heights therefore does **not** produce a
nominal-wall-plus-mixed-bumps-and-dimples result — it produces a
uniformly-sunk background with islands poking up out of it, which is closer
to ordinary raised-mode with an offset than genuine bas-relief.
`_tile_alternating_from_islands()` needs its own ground construction at
`z = 0.5` (either a small, explicit fork of `_tile_from_islands()`'s
assembly logic with `transform = up(0.5)` on the ground `vnf_from_region()`
call, or a generalization of `_tile_from_islands()` itself to take an
optional `ground_z` parameter defaulting to `0` so every existing caller is
unaffected — the implementer's call which is cleaner once the actual code is
in front of them).

**`_tile_alternating_from_islands(islands, high_group)`** (alternating),
corrected: like `_tile_from_islands()` but with (a) every island's height
forced to `1` (high) or `0` (low, but still above the `z = 0.5` ground —
i.e. rendered as a real, if shallow, sunk facet, not flattened into the
ground plane) according to group membership, and (b) the ground built at
`z = 0.5` per Correction 2 above, with the caller using `tex_inset = 0.5`.
**`high_group` is a per-island group id, not a flat list index into
`islands`** — every pattern here packs more than one raw region per
copy/center/placement before flattening (e.g. `tumbling_cubes` emits 3
rhombus islands per hexagon center, so a flat index like `[0, 3]` does not
mean "centers 0 and 3"; `cairo_pentagonal`/`floret_pentagonal`'s placement
index `k` likewise does not line up with the flattened list position after
clipping drops empty islands). The actual mechanism: each caller's
islands-building loop must tag every island it emits with the copy/center/
placement identity it came from (e.g. `c` for `tumbling_cubes`, `pl[2]` for
`cairo_pentagonal`/`floret_pentagonal`) *before* flattening, and
`_tile_alternating_from_islands()` takes a `high_group` predicate/set tested
against that tag, not the island's position in the flattened list.
Concretely, `islands` for this builder is `[[region, height, group_id], ...]`
(one extra field versus `_tile_from_islands()`'s plain `[region, height]`),
and `high_group` is the set of `group_id` values that render high. This
needs a small signature change to how each pattern's islands-building loop
is written, not just a new consumer — call this out explicitly in Task 1
rather than discovering it mid-implementation.

**`intertwine` cannot support `"alternating"` in Phase 1.**
`_intertwine_tile()` deliberately unions every ring strand into a *single*
island before it ever reaches `_tile_from_islands()`
(`modules/decoration.scad:587-588`) — there is no per-ring identity left to
tag for `high_group`, and splitting the strands back apart to tag them would
reintroduce the exact problem that union was written to avoid (overlapping
strands producing an unclosed/invalid VNF at their crossings — see that
function's own comment). `intertwine` therefore joins `teardrop` as a
Phase-1 exception for `"alternating"` specifically (its outline/etched
support is unaffected by this — the outer-silhouette construction can still
union the original per-ring strand pieces the same way `_intertwine_tile()`
already does, since outline mode only needs the combined outer boundary, not
a live per-ring tag; whether its overlapping strands also need special care
for the *secondary* internal groove is a real open question, flagged for
Task 1 rather than resolved here).

Both builders live in `modules/decoration.scad` next to `_tile_from_islands()`
and reuse its existing `_tile_quantize()`/clipping/winding machinery — they
are new *assemblers* over the same islands data, not a new geometry pipeline.

### Per-pattern classification

| Pattern | Raised (unchanged) | Etched (new) | Alternating (new) |
|---|---|---|---|
| `none` | — | — | not applicable (no texture) |
| `ridges`, `pyramids`, `diamonds`, `hex_grid`, `tri_grid` | BOSL2 heightfield | **unchanged** — already a true outline/panel engrave | not supported yet (see Phase 2) |
| `dots`, `cubes`, `checkers`, `bricks` | BOSL2 heightfield, unchanged | Phase 2 (see below) | Phase 2 |
| `tumbling_cubes`, `islamic_star`, `tetrakis_square`, `kisrhombille`, `triakis_triangular`, `rhombille`, `cairo_pentagonal`, `floret_pentagonal` | unchanged | `_tile_outline_from_islands()` on the pattern's motif groups (edge-aware, see above) | `_tile_alternating_from_islands()` on the same islands, once each island carries its group id (see above) |
| `intertwine` | unchanged | `_tile_outline_from_islands()`, same as the row above (its motif "group" is the whole unioned ring set — see above) | **not in Phase 1** — `_intertwine_tile()` unions every ring into one island before there's anything left to tag; see above |
| `teardrop` | unchanged | not in Phase 1 — no islands list exists to feed the shared builder; needs its own hand-rolled outline construction (or explicit exclusion) as a separate, smaller task | not in Phase 1, same reason |

**Phase 1** (this plan) covers `"etched"` for 9 patterns (everything except
`teardrop`, which has no islands list) and `"alternating"` for 8 of those 9
(everything except `intertwine`, which cannot expose per-ring groups — see
above) — plus wiring `"alternating"` into `PATTERN_TYPES` as a `relief_mode`
value (not a `pattern_type`) with a clear assertion for patterns that don't
support it.

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
and if `relief_mode == "alternating"`, `pattern_type` must be one of the 8
patterns that support it (`teardrop` and `intertwine` both excluded, for
different reasons — see "Per-pattern classification" above) or `"none"` is
rejected too (no texture to alternate) — assert with a clear message naming
which pattern_types currently support `"alternating"`, rather than silently
falling back to `"raised"`.

### Per-pattern `high_group` choice for `"alternating"`

Each pattern already has a natural copy/center/placement identity to
alternate by — no new geometry, just tagging each island with that identity
when it's built (see "Shared infrastructure" above) and then a different
high/low assignment over those tags:

- `tumbling_cubes`/`rhombille`: group by hexagon-center (`_TC_CENTERS` has 5
  positions per tile, each contributing 2-3 islands that must all share one
  group tag — alternate e.g. centers `[0,3]` high, `[1,2,4]` low, or a
  parity rule over the hexagon lattice `(m,n)` if that reads better once
  rendered — confirm visually during implementation, this is a design
  judgment call, not a derived fact).
- `cairo_pentagonal`/`floret_pentagonal`: group by placement/orientation
  (`_CP_PLACEMENTS`'/`_FP_PLACEMENTS`' own `k`, tagged per island before
  flattening — `floret_pentagonal` already has a working "even k high, odd k
  low" rule for its *raised* mode's existing alternation; reuse that same
  parity, just mapped to `1`/`0` instead of `1`/`_FP_Z_LO`, with
  `tex_inset = 0.5`).
- The "kis" family: group by fan-triangle index within each centroid fan (already
  alternates 2 or 3 heights in raised mode for the pinwheel look — reuse that
  same index, collapsed to high/low).
- `islamic_star`: star high, all 4 crosses low (or some other split — visual
  judgment call during implementation).

(`intertwine` is not in this list — see "Per-pattern classification" above
for why it can't support `"alternating"` in Phase 1.)

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

## Decisions (previously open questions)

1. **Phase 1 scope**: confirmed — `"alternating"` only works for the 9
   islands-based custom patterns at first (`teardrop` excluded, see above),
   with a clear error for everything else. Converting `dots`/`cubes`/
   `checkers`/`bricks` (Phase 2) is not a blocker for this work. Barrett
   separately noted a raised/sunk checkerboard-style alternation would be a
   cool future direction but isn't required now if it doesn't fall out
   naturally from Phase 1's mechanism — no action needed here, just recorded
   as a genuine (not required) future idea.
2. **`high_group` visual judgment calls**: confirmed fine to leave as an
   implementation-time call — the implementer renders a few candidates per
   pattern and picks the one that reads best, the same way
   `floret_pentagonal`'s existing raised-mode alternation was chosen.
3. **"kis" family etched behavior**: Barrett wants the internal facet detail
   *kept* in etched mode, not discarded — this superseded the plan's earlier
   "outer silhouette only" simplification and is now reflected throughout
   this spec (see Goals #2 and `_tile_outline_from_islands()`'s two-tier
   groove design above): a primary groove on the outer silhouette, plus a
   secondary, visually lighter (thinner and/or shallower) groove on internal
   facet boundaries, for contrast/hierarchy rather than one undifferentiated
   outline.

## Rollout

Given the scope (a new shared mechanism plus per-pattern wiring across 9
existing tiles), this should go through the same plan → worktree →
subagent-driven-development flow already used for each pattern addition, but
as its own dedicated plan — not folded into the next tessellation-pattern PR.
Suggest splitting into two plans/PRs: (1) the shared
`_tile_outline_from_islands()`/`_tile_alternating_from_islands()` helpers plus
`relief_mode` validation, landed against 2-3 patterns first as a proof of the
mechanism; (2) the remaining patterns, once the mechanism is proven out.
