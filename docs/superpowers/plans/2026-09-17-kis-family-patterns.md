# Kis-Family Tessellation Patterns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three new `pattern_type` values from `TODO.md`'s tessellation backlog: `"tetrakis_square"`, `"kisrhombille"`, and `"triakis_triangular"` (batch 1 of 3 — see `TODO.md` for the full 8-pattern list and batching order). All three are Conway's "kis" operation (fan a polygon into one triangle per edge, from its centroid) applied to different base grids, per Wikipedia's own description of each tiling.

**Architecture:** All three reuse the existing `_tile_from_islands()` machinery (`modules/decoration.scad`) that already backs `tumbling_cubes`/`intertwine`/`islamic_star` — no new geometry engine needed. A new shared helper, `_kis_shrunk_fan(poly, gap, heights)`, fans a convex polygon from its centroid into one shrunk (gapped) triangle per edge, returning an islands list directly consumable by `_tile_from_islands()`. `"tetrakis_square"` kis-fans the whole unit tile (4 triangles from its center to its 4 corners, per Wikipedia's own "from the center point" description). `"kisrhombille"` kis-fans each of the *existing* `tumbling_cubes` rhombi (`_TC_V`/`_tc_rhombus()`/`_TC_CENTERS`, already unit-square-normalized) into 4 triangles each — reusing that geometry directly rather than re-deriving a hexagon/rhombille tiling from scratch, per Wikipedia's own equivalent description ("hexagon divided into 12 triangles from the center point" = 3 rhombi × 4 triangles each). `"triakis_triangular"` splits the unit square into 2 right triangles (a simple, already-unit-square-tiling triangulation — like `kisrhombille`, deliberately normalized rather than perfectly equilateral, matching the existing `_UNIT_TILE` convention's own precedent of prioritizing exact tiling over geometric perfection) and kis-fans each into 3 sub-triangles, per Wikipedia's "divided into three ... triangles from the center point."

Per the project owner's direction: **raised** mode gives each fan's triangles distinct alternating heights (a pinwheel/faceted look, matching how `tumbling_cubes`/`islamic_star` already use height contrast rather than flat islands); **etched** mode gives every triangle in a fan the *same* flat height, so the etched look is a true flat-panel-with-engraved-groove (matching how `"ridges"`/`"pyramids"`/`"diamonds"` already work), not merely an inverted copy of the raised relief. This is a deliberate difference from the existing 4 custom patterns (`teardrop`/`tumbling_cubes`/`intertwine`/`islamic_star`), which reuse one VNF for both relief modes via BOSL2's `tex_inset` — the new patterns' tile-building functions take `relief_mode` directly and build a different VNF for each, still passing through `decorated_solid()`'s existing `tex_inset = is_etched` line (which still does useful work: it insets the new flat-etched VNF's flat top to the nominal wall and cuts the groove below it, identical to how insetting works for the `trunc_*` flat-topped BOSL2 textures already).

None of the three need a `sqrt(3)` (or other) aspect correction in `_square_tile_vertical_reps()`: like the existing 4 custom patterns, all three are deliberately normalized to tile exactly on the unit square (accepting minor deviation from perfect geometric regularity, same precedent `tumbling_cubes`/`_UNIT_TILE` already establish), so they fall through to the plain square-tile formula unchanged.

Kis-fan triangles are structurally similar to the flat plateaus that make `tumbling_cubes`/`intertwine`/`islamic_star` CGAL-fragile at low `pattern_repeat`/`smoothness` (a single flat facet spanning a wide arc can chord back inside the wall). Treat all three new patterns with the same suspicion: add the same defensive warning `echo()`, and measure real CGAL safety at both the shipped defaults and a reduced CI-check value — do not assume they're safe because the mechanism is "just" triangles.

**Tech Stack:** OpenSCAD, BOSL2.

**Spec:** This plan's own Architecture section is the spec, derived from `TODO.md`'s tessellation backlog entry and confirmed against the Wikipedia articles for each tiling (fetched during brainstorming — see conversation for the exact quoted constructions) and the existing `modules/decoration.scad` conventions (`_tile_from_islands()`, `_UNIT_TILE`, `_tc_rhombus()`/`_TC_V`/`_TC_CENTERS`).

## Global Constraints

- Exactly 3 new `pattern_type` values this batch: `"tetrakis_square"`, `"kisrhombille"`, `"triakis_triangular"`. The remaining 5 tessellation-backlog patterns (`"rhombille"`, `"cairo_pentagonal"`, `"prismatic_pentagonal"`, `"floret_pentagonal"`, `"deltoidal_trihexagonal"`) are explicitly OUT of scope for this plan — separate plans, per the project owner's batching direction.
- Raised mode: alternating heights per fan (distinct values, matching `tumbling_cubes`' own reasoning that "equal heights just look like a honeycomb"). Etched mode: uniform flat height per fan (all triangles in a fan at height 1.0) — a deliberate, real VNF difference from raised, not merely `tex_inset` on the same shape. Do not reuse one VNF for both modes for these 3 patterns.
- No new Customizer field beyond the 3 new `pattern_type` string values (added to `PATTERN_TYPES`). No new aspect-correction category — these 3 patterns fall through to the existing plain square-tile formula.
- Reuse `tumbling_cubes`' existing `_TC_V`/`_tc_rhombus()`/`_TC_CENTERS` for `"kisrhombille"` rather than re-deriving hexagon/rhombille geometry from scratch.
- Add the same CGAL-fragility warning `echo()` (in `decorated_solid()`) that `tumbling_cubes`/`intertwine`/`islamic_star` already get, extended to cover these 3 new patterns, and measure (don't assume) real CGAL safety for each at both the shipped defaults (`pattern_repeat=16`, `smoothness=60`) and a reduced CI-check value, in both relief modes, exactly as rigorously as the existing 3 fragile patterns were measured (see `README.md`'s "Note on the interlocking patterns and CGAL" section for the established methodology and its own hard-won lesson about platform-dependent CGAL fragility — verify any reduced-check value survives with real margin, not just the smallest value that happens to pass once locally).
- All local-only CGAL-safety measurements must be re-verified against the actual GitHub Actions CI run (not just a local OpenSCAD build) before considering any CI-pinned value trustworthy — the immediately preceding PR in this repo's history found a local-clean value that CGAL-aborted on GitHub's Ubuntu OpenSCAD build despite an identical reported version number on a local macOS build. Push and watch real CI for any newly-added CGAL-fragile-pattern check; do not merge on local verification alone.
- Update `README.md`'s `pattern_type` list, `docs/gallery.md`'s pattern comparison section, and regenerate the 6 new gallery images (2 relief modes × 3 patterns) via `docs/images/render.sh`, matching how the prior 4-custom-pattern addition (`docs/superpowers/plans/2026-09-13-todo-decoration-and-presets.md`) handled its own gallery task — do not defer this to a later batch.
- Work happens in an isolated git worktree per this repo's established convention; branch name should describe the batch (e.g. `kis-family-patterns`).

## Shared Geometry Reference (for implementers — not Customizer-facing)

```openscad
// Conway's "kis" operation: fan a convex polygon into one triangle per
// edge, from its centroid, each triangle independently shrunk inward by
// gap/2 (matching tumbling_cubes' own per-facet offset() idiom) so a
// narrow engraved groove separates every fan triangle from its neighbours
// -- including at the tile's own boundary, where the shrink is what lets
// the groove continue seamlessly into the next tile's matching shrink.
// heights: a single value (every triangle in this fan the same height) or
// one value per edge/triangle, in the same edge order as `poly`.
//
// Returns an "islands" list ([region, height] pairs) directly consumable
// by _tile_from_islands() -- callers concat/flatten multiple calls together
// for tilings with more than one cell per unit tile (see kisrhombille).
function _kis_centroid(poly) =
    [for (i = [0:1]) sum([for (p = poly) p[i]]) / len(poly)];

function _kis_shrunk_fan(poly, gap, heights) =
    let (c = _kis_centroid(poly), n = len(poly))
    [for (i = [0:n-1])
        let (tri = [c, poly[i], poly[(i+1) % n]],
             r = offset(tri, delta = -gap/2, closed = true))
        if (len(r) >= 3) [[r], is_list(heights) ? heights[i] : heights]];

_KIS_GAP = 0.05; // engraved groove width, in tile fractions -- same scale as _TC_GAP/_IS_GAP
```

Place this block in `modules/decoration.scad` right after the existing "Shared plateau-tile builder" section (after `_tile_from_islands()`, before the "Tumbling blocks (rhombille)" section) — it is infrastructure at the same level as `_tile_from_islands()` itself, used by multiple patterns, not owned by any one of them.

---

### Task 1: `"tetrakis_square"` — the simplest case (whole tile, one kis-fan)

**Files:**
- Modify: `modules/decoration.scad` (add `_kis_centroid()`/`_kis_shrunk_fan()`/`_KIS_GAP` per the Shared Geometry Reference above; add `_tetrakis_square_tile(relief_mode)`; add `"tetrakis_square"` to `PATTERN_TYPES`; wire it into `_decoration_texture()` and the CGAL-fragility warning list in `decorated_solid()`)
- Test: `tests/test_decoration_tetrakis_square.scad` (new file)

**Interfaces:**
- Produces: `_kis_centroid(poly)`, `_kis_shrunk_fan(poly, gap, heights)`, `_KIS_GAP` — shared infrastructure Tasks 2 and 3 both consume. `_tetrakis_square_tile(relief_mode)` — a function returning a VNF, taking `relief_mode` directly (not going through the `_decoration_etched_texture()` lookup the way `"ridges"`/`"pyramids"`/`"diamonds"` do).
- Consumes: nothing new from other tasks (this is the first task).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_decoration_tetrakis_square.scad`:

```openscad
// tests/test_decoration_tetrakis_square.scad
//
// "tetrakis_square" is a custom VNF tile (a unit square kis-fanned into 4
// triangles from its center), not a BOSL2 texture name, so it needs a
// real-render check the same way tumbling_cubes/intertwine/islamic_star do
// -- a tile whose edges don't line up across the tile boundary only fails
// when the geometry is actually evaluated.
include <../modules/decoration.scad>

assert(in_list("tetrakis_square", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"tetrakis_square\"");

// Raised and etched are genuinely different VNFs for this pattern (unlike
// the 4 pre-existing custom patterns, which reuse one VNF via tex_inset) --
// confirm both build and are real VNFs.
for (relief = ["raised", "etched"]) {
    _tex = _decoration_texture("tetrakis_square", relief);
    assert(is_list(_tex) && len(_tex) == 2,
        str("_decoration_texture(\"tetrakis_square\", \"", relief, "\") must be a VNF, not a texture name"));
    assert(is_vnf(_tex),
        str("_decoration_texture(\"tetrakis_square\", \"", relief, "\") must be a valid VNF"));

    _bounds = pointlist_bounds(_tex[0]);
    assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
        str("tetrakis_square (", relief, ") tile must fit in the unit cube, got bounds ", _bounds));

    assert(_decoration_style("tetrakis_square", relief) == undef,
        str("tetrakis_square is a VNF tile and must not carry a style override (", relief, ")"));
}

// Etched must be flat: every triangle in the fan at the same height. Raised
// must NOT be flat: at least two distinct heights, or the pinwheel reads as
// a flat honeycomb (same reasoning tumbling_cubes' own test applies to _TC_Z).
_etched_tex = _decoration_texture("tetrakis_square", "etched");
_etched_zs = unique([for (p = _etched_tex[0]) p[2]]);
// z=0 (the ground/border) is always present in a _tile_from_islands() VNF;
// the fan's own top height is whatever else appears.
assert(len(_etched_zs) <= 2,
    str("tetrakis_square etched must be flat (one fan height plus the z=0 ground), got heights ", _etched_zs));

_raised_tex = _decoration_texture("tetrakis_square", "raised");
_raised_zs = unique([for (p = _raised_tex[0]) p[2]]);
assert(len(_raised_zs) >= 3,
    str("tetrakis_square raised must have at least two distinct fan heights plus the ground, got ", _raised_zs));

// The invariant the whole tile design rests on: every vertex the tile leaves
// on one edge needs a twin at the same position on the opposite edge, or
// repeats don't stitch (same check as tests/test_decoration_tumbling_cubes.scad).
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (relief = ["raised", "etched"]) {
    _tex = _decoration_texture("tetrakis_square", relief);
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(_tex, axis, 0);
        hi = _tile_edge_profile(_tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        assert(len(lo) > 2,
            str("tetrakis_square (", relief, ") tile has only ", len(lo), " vertices on its ", name,
                "=0 edge -- the fan doesn't reach the seam"));
        assert(len(lo) == len(hi),
            str("tetrakis_square (", relief, ") tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("tetrakis_square (", relief, ") tile ", name, " edge vertices don't line up: ", mismatched));
    }
}

difference() {
    decorated_solid("tetrakis_square", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `openscad -o /tmp/test.csg tests/test_decoration_tetrakis_square.scad`
Expected: FAIL — `"tetrakis_square"` is not yet in `PATTERN_TYPES` (ERROR: Assertion failed at the `in_list` check).

- [ ] **Step 3: Implement the shared helpers and `_tetrakis_square_tile()`**

In `modules/decoration.scad`, add the Shared Geometry Reference block (above) right after `_tile_from_islands()`'s definition, before the "Tumbling blocks (rhombille)" section comment.

Then add a new section (place it anywhere after the shared block, e.g. right before "Tumbling blocks"):

```openscad
// --- Tetrakis square (kis of the square tiling) -----------------------------
//
// Wikipedia: "a square tiling with each square divided into four isosceles
// right triangles from the center point." The whole unit tile IS the one
// square cell here -- kis-fan it directly, no separate base-tiling geometry
// needed (unlike kisrhombille/triakis_triangular below, which kis multiple
// cells per unit tile).
//
// Raised heights alternate around the fan for a pinwheel look (0 and 2 are
// opposite triangles, as are 1 and 3, so this alternates rather than mirrors).
// Etched is one flat height -- see the relief_mode note in this plan's
// Architecture section for why these two modes are genuinely different VNFs
// for this pattern, not one shape read two ways via tex_inset.
function _tetrakis_square_tile(relief_mode) =
    _tile_from_islands(_kis_shrunk_fan(_UNIT_TILE, _KIS_GAP,
        relief_mode == "etched" ? 1.0 : [1.0, 0.45, 1.0, 0.45]));
```

Add `"tetrakis_square"` to `PATTERN_TYPES` (append it after `"islamic_star"`, matching the file's existing append-at-the-end convention for new patterns).

In `_decoration_texture(pattern_type, relief_mode)`, add a branch calling the new function *with* `relief_mode` (unlike the 4 pre-existing custom patterns, which don't take it):

```openscad
    pattern_type == "tetrakis_square" ? _tetrakis_square_tile(relief_mode) :
```

Add `"tetrakis_square"` to the CGAL-fragility warning list in `decorated_solid()` (the `in_list(pattern_type, ["tumbling_cubes", "intertwine", "islamic_star"])` check — add it to that array).

- [ ] **Step 4: Run test to verify it passes**

Run: `openscad -o /tmp/test.csg tests/test_decoration_tetrakis_square.scad`
Expected: PASS (exit 0, no ERROR in output).

- [ ] **Step 5: Measure real CGAL safety**

Probe the shipped defaults directly:
```bash
openscad -D 'pattern_type="tetrakis_square"' -D 'relief_mode="raised"' -D 'pattern_repeat=16' -D 'smoothness=60' -o /tmp/probe.stl tests/test_planter_integration.scad 2>&1 | grep -i "CGAL error"
openscad -D 'pattern_type="tetrakis_square"' -D 'relief_mode="etched"' -D 'pattern_repeat=16' -D 'smoothness=60' -o /tmp/probe.stl tests/test_planter_integration.scad 2>&1 | grep -i "CGAL error"
```
If either aborts, this is a real, load-bearing problem for this task — do not proceed to Step 6 until you've found a resolution (following the same "vary pattern_repeat and smoothness jointly" methodology `README.md` documents for the other 3 fragile patterns) or escalated to the controller with what you found. If both are clean, also probe a candidate reduced CI-check value (start with `pattern_repeat=4`, `smoothness=24`, matching the other non-fragile patterns' CI value) in both relief modes, and if either aborts, search nearby values the same way.

- [ ] **Step 6: Commit**

```bash
git add modules/decoration.scad tests/test_decoration_tetrakis_square.scad
git commit -m "Add tetrakis_square pattern_type: kis-fan the unit tile into 4 triangles from its center"
```

---

### Task 2: `"kisrhombille"` — reuses `tumbling_cubes`' hexagon/rhombus geometry

**Files:**
- Modify: `modules/decoration.scad` (add `_kisrhombille_tile(relief_mode)`; add `"kisrhombille"` to `PATTERN_TYPES`; wire into `_decoration_texture()` and the CGAL warning list)
- Test: `tests/test_decoration_kisrhombille.scad` (new file)

**Interfaces:**
- Consumes: Task 1's `_kis_shrunk_fan()`/`_KIS_GAP` (shared infrastructure), and the pre-existing `_TC_V`/`_tc_rhombus()`/`_TC_CENTERS` (already in `modules/decoration.scad`, backing `tumbling_cubes`).
- Produces: `_kisrhombille_tile(relief_mode)`, following the same signature convention as Task 1's `_tetrakis_square_tile()`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_decoration_kisrhombille.scad`, following `tests/test_decoration_tetrakis_square.scad`'s exact structure from Task 1 (PATTERN_TYPES membership, VNF checks for both relief modes, flat-vs-multi-height check, twin-vertex edge-matching check for both relief modes, a real difference() render at the end) with `"tetrakis_square"` replaced by `"kisrhombille"` throughout. One addition specific to this pattern: after clipping to the unit tile, more than 2 vertices should appear on each edge (since multiple rhombi, not just one shape, cross each seam — a weaker version of the check would be vacuous here, same reasoning as `tumbling_cubes`' own edge-count-of-more-than-4 check), so use `len(lo) > 4` for BOTH axes, not `> 2`.

- [ ] **Step 2: Run test to verify it fails**

Run: `openscad -o /tmp/test.csg tests/test_decoration_kisrhombille.scad`
Expected: FAIL — `"kisrhombille"` not yet in `PATTERN_TYPES`.

- [ ] **Step 3: Implement `_kisrhombille_tile()`**

```openscad
// --- Kisrhombille (kis of the rhombille tiling) ------------------------------
//
// Wikipedia: kis applied to the rhombille tiling's rhombi ("each rhombus
// divided into" triangles from its own center), equivalently described as
// "an equilateral hexagonal tiling with each hexagon divided into 12
// triangles from the center point" (3 rhombi x 4 triangles each = 12).
// Reuses tumbling_cubes' own hexagon/rhombus geometry directly (_TC_V,
// _tc_rhombus(), _TC_CENTERS) rather than re-deriving it -- same tiling,
// just kis-fanned instead of raised as three flat plateaus.
//
// Each rhombus's own 4-triangle fan alternates heights the same way
// tetrakis_square's does. Flattened with `each` since _kis_shrunk_fan()
// already returns a list of [region, height] islands per rhombus, and we
// need all of them (5 centers x 3 rhombi x up to 4 triangles) concatenated
// into one islands list before clipping to the unit tile.
function _kisrhombille_tile(relief_mode) =
    _tile_from_islands([
        for (c = _TC_CENTERS) for (k = [0:2])
            each _kis_shrunk_fan(_tc_rhombus(c, k), _KIS_GAP,
                relief_mode == "etched" ? 1.0 : [1.0, 0.4, 1.0, 0.4])
    ]);
```

Add `"kisrhombille"` to `PATTERN_TYPES`, wire into `_decoration_texture()`:
```openscad
    pattern_type == "kisrhombille" ? _kisrhombille_tile(relief_mode) :
```
and add `"kisrhombille"` to the CGAL-fragility warning list.

- [ ] **Step 4: Run test to verify it passes**

Run: `openscad -o /tmp/test.csg tests/test_decoration_kisrhombille.scad`
Expected: PASS.

- [ ] **Step 5: Measure real CGAL safety**

Same procedure as Task 1 Step 5, substituting `pattern_type="kisrhombille"`. This pattern has 5x as many facets per tile as `tetrakis_square` (5 hexagon centers × 3 rhombi × 4 triangles, before clipping), so budget more time and watch specifically for the "flat facet spans too wide an arc" failure mode at low `pattern_repeat` — it is the most structurally similar of the three new patterns to `tumbling_cubes`.

- [ ] **Step 6: Commit**

```bash
git add modules/decoration.scad tests/test_decoration_kisrhombille.scad
git commit -m "Add kisrhombille pattern_type: kis-fan tumbling_cubes' existing rhombille rhombi"
```

---

### Task 3: `"triakis_triangular"` — a simple 2-triangle base tiling, each kis-fanned

**Files:**
- Modify: `modules/decoration.scad` (add `_triakis_triangular_tile(relief_mode)`; add `"triakis_triangular"` to `PATTERN_TYPES`; wire into `_decoration_texture()` and the CGAL warning list)
- Test: `tests/test_decoration_triakis_triangular.scad` (new file)

**Interfaces:**
- Consumes: Task 1's `_kis_shrunk_fan()`/`_KIS_GAP`.
- Produces: `_triakis_triangular_tile(relief_mode)`, same signature convention.

- [ ] **Step 1: Write the failing test**

Create `tests/test_decoration_triakis_triangular.scad`, following the same structure as Tasks 1/2's test files, with `"triakis_triangular"` substituted throughout. Since the base tiling is 2 triangles crossing the *whole* unit square (not clipped fragments like kisrhombille), use `len(lo) > 2` for the edge-vertex-count sanity check (each edge is crossed by exactly one base triangle's kis-fan, contributing a handful of vertices — enough to prove a real crossing, matching Task 1's threshold, not Task 2's).

- [ ] **Step 2: Run test to verify it fails**

Run: `openscad -o /tmp/test.csg tests/test_decoration_triakis_triangular.scad`
Expected: FAIL — `"triakis_triangular"` not yet in `PATTERN_TYPES`.

- [ ] **Step 3: Implement `_triakis_triangular_tile()`**

```openscad
// --- Triakis triangular (kis of the triangular tiling) ----------------------
//
// Wikipedia: "an equilateral triangular tiling with each triangle divided
// into three ... triangles from the center point." The simplest triangular
// tiling that fits the unit tile exactly is the unit square split by one
// diagonal into two right triangles -- like kisrhombille's reuse of
// tumbling_cubes' already-unit-square-normalized hexagons, this trades
// perfect equilateral regularity for an exact, simple unit-square tiling
// (the same precedent _UNIT_TILE's own convention already sets). Each half
// is then kis-fanned into 3 sub-triangles.
//
// Three distinct heights per fan (not just two, unlike tetrakis_square's
// 4-triangle alternation) -- matching tumbling_cubes' own reasoning that
// three DIFFERENT heights read better than any two repeated.
_TT_A = [[0, 0], [1, 0], [1, 1]];
_TT_B = [[0, 0], [1, 1], [0, 1]];

function _triakis_triangular_tile(relief_mode) =
    _tile_from_islands(concat(
        _kis_shrunk_fan(_TT_A, _KIS_GAP, relief_mode == "etched" ? 1.0 : [1.0, 0.4, 0.7]),
        _kis_shrunk_fan(_TT_B, _KIS_GAP, relief_mode == "etched" ? 1.0 : [1.0, 0.4, 0.7])
    ));
```

Add `"triakis_triangular"` to `PATTERN_TYPES`, wire into `_decoration_texture()`:
```openscad
    pattern_type == "triakis_triangular" ? _triakis_triangular_tile(relief_mode) :
```
and add `"triakis_triangular"` to the CGAL-fragility warning list.

- [ ] **Step 4: Run test to verify it passes**

Run: `openscad -o /tmp/test.csg tests/test_decoration_triakis_triangular.scad`
Expected: PASS.

- [ ] **Step 5: Measure real CGAL safety**

Same procedure as Tasks 1/2 Step 5, substituting `pattern_type="triakis_triangular"`.

- [ ] **Step 6: Commit**

```bash
git add modules/decoration.scad tests/test_decoration_triakis_triangular.scad
git commit -m "Add triakis_triangular pattern_type: kis-fan a 2-triangle unit-square tiling"
```

---

### Task 4: CI wiring, gallery, README, and CGAL safety re-verification against real CI

**Files:**
- Modify: `.github/workflows/test.yml` (add the 3 new patterns to every relevant loop: the single-pattern texture-build loop, the full-assembly reduced-value loop, and — if any of the 3 turned out CGAL-fragile per Tasks 1-3's Step 5 measurements — the default-settings pin loop and/or the union-check loop, following the exact structure already used for `tumbling_cubes`/`intertwine`/`islamic_star`)
- Modify: `README.md` (add the 3 new `pattern_type` values to the parameter table's value list; if any turned out CGAL-fragile, extend the "Note on the interlocking patterns and CGAL" section's pattern list and measured-value tables)
- Modify: `docs/gallery.md` (add a close-up comparison entry — both relief modes — for each of the 3 new patterns, following the existing per-pattern subsection format)
- Regenerate: `docs/images/*.png` (6 new close-up images; run `./docs/images/render.sh`)

**Interfaces:**
- Consumes: Tasks 1-3's final `PATTERN_TYPES` state and each task's Step 5 CGAL-safety measurements (which values are safe, which needed care) — carry those measurements into this task's CI-wiring decisions rather than re-measuring from scratch.

- [ ] **Step 1: Add the 3 new patterns to every relevant CI loop**

In `.github/workflows/test.yml`:
- The single-pattern texture-build loop (`for pt in none ridges diamonds ... islamic_star`): append `tetrakis_square kisrhombille triakis_triangular`.
- The full-assembly reduced-value loop (the `for combo in "ridges 4" ...` line): append `"tetrakis_square 4" "kisrhombille 4" "triakis_triangular 4"` if Tasks 1-3's Step 5 found `pattern_repeat=4` safe for each; otherwise use whatever reduced value each task's own measurement found safe, following the exact reasoning-and-comment style already used for the other three fragile patterns (explain *why* that specific value, not just what it is).
- If any of the 3 new patterns turned out CGAL-fragile at the shipped defaults (unlikely given they're built from small triangles rather than large plateaus, but verify, don't assume): add a default-settings pin the same way `islamic_star`/`tumbling_cubes` have one.

- [ ] **Step 2: Run the full local CI-equivalent suite**

```bash
python3 -c "
import yaml
with open('.github/workflows/test.yml') as f:
    d = yaml.safe_load(f)
script = d['jobs']['scad-tests']['steps'][-1]['run']
with open('/tmp/run_ci.sh', 'w') as f:
    f.write('#!/usr/bin/env bash\n')
    f.write(script)
"
bash /tmp/run_ci.sh > /tmp/ci_local.log 2>&1; echo "EXIT:$?"
grep -c FAIL /tmp/ci_local.log
```
Fix and re-run until 0 FAIL lines.

- [ ] **Step 3: Update README.md and docs/gallery.md**

Add the 3 new `pattern_type` values to README's parameter table (the `pattern_type` row's value list). Add a subsection for each new pattern to `docs/gallery.md`'s pattern-comparison section, following the existing format (a short description of the motif, a note on the raised/etched relief difference specific to these 3 patterns — flat panels with an engraved groove when etched, not an inverted copy of the raised relief, unlike the other custom patterns — and placeholders for the close-up images Step 4 will generate).

- [ ] **Step 4: Regenerate the gallery**

```bash
./docs/images/render.sh
```
Confirm it completes with "All renders complete and CGAL-clean" and that `git status` shows the 6 new close-up images (2 relief modes × 3 patterns) plus your doc edits — no unexpected changes to unrelated images.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/test.yml README.md docs/gallery.md docs/images
git commit -m "Wire tetrakis_square/kisrhombille/triakis_triangular into CI, README, and the gallery"
```

- [ ] **Step 6: Push and verify against real CI**

Push the branch, open a PR (or push to the existing branch if a PR is already open), and watch the actual GitHub Actions run for every newly-added check involving these 3 patterns. Per this plan's Global Constraints, do not trust local-only CGAL safety measurements — if anything fails on GitHub's runner that passed locally, re-measure with a wider safety margin (not just the next-smallest untested value) the same way the immediately preceding PR in this repo's history had to for `intertwine`.

## Self-Review Notes

- Spec coverage: Task 1 establishes shared infrastructure + the simplest pattern; Tasks 2-3 each add one more pattern reusing that infrastructure; Task 4 covers CI/docs/gallery integration and the mandatory real-CI verification. No gaps against the Architecture section.
- No placeholders: all three tile-building functions are complete, exact code, derived from the Wikipedia constructions fetched during brainstorming and the existing `tumbling_cubes`/`_tile_from_islands()` conventions. Task 4's CGAL-safety wiring is necessarily conditional on Tasks 1-3's real measurements (which don't exist yet when this plan was written) — that's an honest dependency, not a placeholder, and the step gives the exact fallback methodology (README's own documented approach) rather than a vague "figure it out."
- Type consistency: all three new tile functions share the exact signature shape `_foo_tile(relief_mode)`, matching how `_decoration_texture()` calls them, and all reuse `_kis_shrunk_fan()`'s exact return shape (an islands list) so `_tile_from_islands()` consumes all three identically.
