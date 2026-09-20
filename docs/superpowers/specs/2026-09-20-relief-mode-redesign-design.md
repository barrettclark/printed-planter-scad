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

**Correction 1b — "union one group's own sub-regions to find its outer
silhouette" is itself broken for most patterns here, because most patterns
have no background at all in their original (unshrunk) geometry.** Checked
directly: `cairo_pentagonal`'s 8 placements, `floret_pentagonal`'s 18,
`islamic_star`'s star+4 crosses, and `tumbling_cubes`/`rhombille`'s hexagon
rosettes all sum to **exactly** the unit tile's own area before any
gap-shrink is applied — these motifs tile the plane edge-to-edge with zero
gap between one motif instance and its neighbours, not just zero gap within
one motif's own sub-regions. So "union one group's original sub-regions" does
find that group's true silhouette *in isolation*, but that silhouette's
boundary against a *neighbouring* motif instance is not a real edge at all —
it is shared, seamlessly, with the touching neighbour, the same way this
project's own hexagon/pentagon motifs already tile without gaps today
(before the deliberate `_TC_GAP`/`_CP_GAP`/etc. shrink is applied for the
*current* raised-mode groove). Unioning ALL groups together, as the text
below originally proposed, then just returns the *entire unit tile* (since
there is no gap anywhere in the unshrunk data) — and that combined
"silhouette"'s only boundary is the tile's own edge, which `_tile_on_edge()`
correctly suppresses. The result: **no primary groove at all**, for almost
every pattern in this file — not a rare edge case, the normal case.

The actually-correct model is **not** "trace the outer boundary of a union" —
it is **edge classification**: build the full planar arrangement of every
original (pre-shrink) sub-region placed in the tile (across every motif
group, not grouped away from each other), where each sub-region carries the
`group_id` it belongs to (the same identity `_tile_alternating_from_islands()`
already needs — see Correction 2/3 below; this is the same tagging
requirement serving two different consumers). For every edge shared between
two touching sub-regions anywhere in that arrangement:

- If the two sides belong to **different** `group_id`s, it is a
  motif-to-motif boundary — groove it at `outer_gap` (the primary tier).
  This is what makes two adjacent Cairo pentagons, or `islamic_star`'s star
  against its neighbouring crosses, actually show a line between them, which
  the union-based approach could never produce for these patterns.
- If the two sides belong to the **same** `group_id`, it is an internal
  facet seam — groove it at `inner_gap` (the secondary tier). This is the
  "kis" family's fan-triangle edges, `tumbling_cubes`'/`rhombille`'s
  per-rhombus edges, etc.
- If the edge lies on the tile's own boundary (`x` or `y` equal to `0` or
  `1`), it is shared with the neighbouring tile repeat — no groove either
  tier, per the existing `_tile_on_edge()` exception (this part of the
  original design was correct and is unchanged).

A group with only one sub-region contributes no same-group edges (nothing
internal to trace) — that degrades gracefully, same as before. This is a
genuinely bigger piece of geometry work than a boundary trace: it requires
building real adjacency information over the whole placed tessellation (which
sub-region touches which, and along which edge), not just a per-group union.
Do not attempt to shortcut this back to a union-based approach — that is
exactly the design this correction is replacing, for the reason explained
above.

**`_tile_outline_from_islands(motif_groups, outer_gap, inner_gap)`** (etched),
with this corrected model: build the tile's flat panel at `z = 1` (with the
usual `_tile_on_edge()`-aware exception for anything that continues past the
tile boundary), then cut the two groove tiers by classifying every internal
shared edge as above. Work out the exact per-segment/adjacency construction,
and the exact shape each pattern's islands-building loop needs to also
expose its pre-shrink motif groups and their `group_id` tags, during
implementation (Task 1's own job, not this
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

**This is not the only place `0` is hardcoded — `_tile_walls(path, z)` bakes
the same assumption into every island's side wall**, not just the ground
face: it builds each wall as `[[a,0],[b,0],[b,z],[a,z]]` (literal `0` for
the lower vertices, `modules/decoration.scad:227`), i.e. every wall always
runs from the tile floor up to its island's own height. Moving only the
ground *face* to `z = 0.5` and leaving `_tile_walls()` untouched breaks
every island's own wall: a "high" island (height `1`) would still get a
wall from literal `z = 0` to `z = 1`, running straight through the new
`z = 0.5` ground instead of starting there; a "low" island (height `0`)
would get `_tile_walls(path, 0)` — a wall from `0` to `0`, i.e. degenerate
(zero height), leaving no actual side wall connecting the low island's own
top face to the surrounding `z = 0.5` ground at all. `_tile_walls()` itself
needs the same `ground_z` parameter as the ground face — its two hardcoded
`0`s become `ground_z`, and each wall runs from `ground_z` to the island's
own height, in both directions (a "low" island's wall then correctly runs
from `ground_z` *down* to its lower height, not up).

**`_tile_alternating_from_islands(islands, high_group)`** (alternating),
corrected: like `_tile_from_islands()` but with (a) every island's height
forced to `1` (high) or `0` (low, genuinely below the `z = 0.5` ground —
i.e. rendered as a real sunk facet, not flattened onto the ground plane
itself) according to group membership, and (b) the ground built at
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
Phase-1 exception for `"alternating"` specifically. Its `"etched"` mode is
**unchanged** by this correction, not migrated to `_tile_outline_from_islands()`
at all: that builder needs a genuine planar arrangement of non-overlapping
pre-shrink sub-regions to classify any edge, but `_intertwine_tile()`'s ring
strands *overlap* at their crossings even before the union that merges them
into one island (`modules/decoration.scad:677-678`) — there is no such
arrangement to build, not even for a single group. `intertwine` already has
only one island (the whole unioned ring set), so the existing generic
`_tile_from_islands()` + `tex_inset` mechanism already grooves around that
island's own outer boundary when etched — the whole-silhouette result this
pattern needs is what it already gets today, because the motif-to-motif
adjacency problem Correction 1 exists to fix (separate islands touching with
zero gap) doesn't apply to a pattern with only one island in the first
place. No `inner_gap` tier applies either, for the same overlap reason.
Task 1 leaves `intertwine`'s `"etched"` code path untouched.

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
| `intertwine` | unchanged | **unchanged** — already a whole-silhouette groove via the existing `_tile_from_islands()`/`tex_inset` mechanism on its one pre-unioned island; not migrated to `_tile_outline_from_islands()`, which needs a non-overlapping sub-region arrangement this pattern's overlapping strands can't provide — see above | **not in Phase 1** — `_intertwine_tile()` unions every ring into one island before there's anything left to tag; see above |
| `teardrop` | unchanged | not in Phase 1 — no islands list exists to feed the shared builder; needs its own hand-rolled outline construction (or explicit exclusion) as a separate, smaller task | not in Phase 1, same reason |

**Phase 1** (this plan) implements the new `_tile_outline_from_islands()`
builder for `"etched"` on 8 patterns (`tumbling_cubes`, `islamic_star`,
`tetrakis_square`, `kisrhombille`, `triakis_triangular`, `rhombille`,
`cairo_pentagonal`, `floret_pentagonal`) and the new
`_tile_alternating_from_islands()` builder for `"alternating"` on those same
8 — plus adding `"alternating"` as a third valid `relief_mode` value
(a separate concept from `PATTERN_TYPES`, which lists pattern *names*, not
relief modes — see "`relief_mode` validation" below) with a clear assertion
for patterns that don't support it. `intertwine` and `teardrop` are both
outside this count for different reasons: `intertwine`'s `"etched"` mode is
already correct and stays on its existing mechanism unchanged (see above),
and gets neither builder; `teardrop` has no islands list at all and gets
neither mode in Phase 1.

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
gets a sibling — a **new, separate** `RELIEF_MODES = ["raised", "etched", "alternating"]`
list (not an addition to `PATTERN_TYPES`, which is the pattern-*name* list;
`_decoration_texture()` looks up a `pattern_type` string in that list to
resolve a texture, and `"alternating"` is not a pattern name, adding it there
would make `pattern_type = "alternating"` look like a valid selection and
fall through to an unresolved texture). `decorated_solid()` asserts
`in_list(relief_mode, RELIEF_MODES)` the same way it already asserts
`pattern_type`, and if `relief_mode == "alternating"`, a second assertion
checks `pattern_type` is one of the 8 patterns that support it (`teardrop`
and `intertwine` both excluded, for different reasons — see "Per-pattern
classification" above) — assert with a clear message naming which
pattern_types currently support `"alternating"`, rather than silently
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
  assert the resolved VNF's Z levels are exactly `{0, 0.5, 1}` (the neutral
  `z = 0.5` ground plus the `0`/`1` high/low facets — not the pattern's own
  raised heights), assert it differs from both the raised and etched VNF,
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

1. **Phase 1 scope**: confirmed — `"alternating"` only works for 8 of the
   islands-based custom patterns at first (`teardrop` and `intertwine` both
   excluded, see above), with a clear error for everything else. Converting `dots`/`cubes`/
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
