# Cairo Pentagonal Tiling Pattern Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `"cairo_pentagonal"` as a new `pattern_type` -- the Cairo pentagonal tiling (Wikipedia "V3².4.3.4", dual of the snub square tiling), a tessellation by congruent, irregular, bilaterally-symmetric convex pentagons (four long edges + one short edge, two non-adjacent right angles). Every pentagon sits at the same, uniform height (like `rhombille`), so it reads as a clean pentagon-mosaic relief/etch.

**Architecture:** One new custom VNF tile function, `_cairo_pentagonal_tile()`, built the same way `_rhombille_tile()`/`_tumbling_cubes_tile()` are: a list of `[region, height]` islands (each island a translated copy of one of 4 pre-rotated pentagon shapes, shrunk by half the groove width) fed to the existing `_tile_from_islands()` helper. Unlike the "kis" family, this tile's geometry does not depend on `relief_mode` -- etched-vs-raised is handled entirely by `decorated_solid()`'s existing `tex_inset` logic, matching `rhombille`/`tumbling_cubes`/`intertwine`/`islamic_star`.

The four pentagon orientations and the translation lattice come from a fully computationally-verified construction (see "Geometry Derivation" below) -- **do not re-derive this from scratch**; a prior attempt at hand-deriving the Cairo tiling's translation lattice by pure reasoning got stuck, which is exactly why this plan's geometry was checked with real tooling (Python/shapely for the area-closure/no-gap/no-overlap proof, and a live OpenSCAD/BOSL2 run of the actual `_tile_from_islands()` code path) before being written down here.

**Tech Stack:** OpenSCAD 2021.01, BOSL2 (`lib/BOSL2/std.scad`), this repo's existing `modules/decoration.scad` VNF-tile infrastructure (`_tile_from_islands()`, `_UNIT_TILE`).

**Spec:** No separate spec document -- this plan follows the same shape as `docs/superpowers/plans/2026-09-17-rhombille-pattern.md` and `docs/superpowers/plans/2026-09-17-kis-family-patterns.md`, and `TODO.md`'s tessellation backlog entry for "Cairo pentagonal tiling ... batch 2". The geometry itself is derived and verified in this plan's own "Geometry Derivation" section below (not an external spec doc), using Wikipedia's Cairo pentagonal tiling article's own worked "type 4" pentagon example as the starting point.

## Global Constraints

- New pattern name: `"cairo_pentagonal"`, appended to `PATTERN_TYPES` immediately after `"rhombille"` (the current last entry) -- matches the file's existing append-at-the-end convention and `TODO.md`'s batch-2 ordering (rhombille, then Cairo pentagonal).
- The tile is a VNF (not a BOSL2 texture string), added to `EXPECTED_VNF_PATTERN_TYPES` in `tests/test_decoration_pattern_types.scad`.
- The tile is **not** in `_ASPECT_EXCLUDED_PATTERNS` and **not** in `_ASPECT_SQRT3_PATTERNS` -- it is built on `_UNIT_TILE` with no intrinsic aspect distortion (see Geometry Derivation: the affine map to unit-tile space is a pure rotation + uniform scale, no shear, no stretch), so it uses the plain `_square_tile_vertical_reps()` formula automatically.
- No `style` override: it's a VNF, so `_decoration_style_for()` must return `undef` for it (true automatically, but the task's test must assert this explicitly).
- Every pentagon is raised to the **same** height, `1.0` (the tile's own max), mode-independent -- see "Relief Mode Decision" below for the reasoning. `_cairo_pentagonal_tile()` therefore takes **no** `relief_mode` parameter, matching `_rhombille_tile()`'s signature, not the "kis" family's `_foo_tile(relief_mode)` signature.
- Use gap `0.05` (own named constant `_CP_GAP`, following this repo's convention of never sharing another pattern's groove-width constant even at the same numeric value as `_KIS_GAP`/`_IS_GAP`).
- CGAL-fragility warning: add `"cairo_pentagonal"` to `decorated_solid()`'s CGAL warning `echo()`. This plan's own smoke-test (Geometry Derivation, "OpenSCAD/BOSL2 verification" below) rendered one specific configuration CGAL-clean, but that is one data point, not a sweep -- Task 1's CGAL-sweep step must independently re-measure across a `pattern_repeat`/`smoothness` grid in both relief modes (matching `rhombille`'s Step 6 methodology exactly) before deciding which warning bucket this pattern belongs in. Each tile facet here is a single flat pentagon per island (not a multi-triangle fan like the "kis" family, but also each facet is comparatively small relative to `tumbling_cubes`'/`rhombille`'s rhombi -- there are 8 island pieces per unit tile here vs. 15 for `tumbling_cubes`/`rhombille`), so do not assume either bucket from the mechanism alone; measure it.
- README.md's `pattern_type` parameter table, the "N of the pattern_type values are interlocking" enumeration (currently names `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`, `"rhombille"` explicitly -- this repo was burned once already by a stale *count*-based version of this claim, which is why it now names patterns explicitly), and the CGAL-fragility section must all be updated by name.
- `docs/gallery.md` needs a new subsection (raised + etched example renders) following the exact structure of the `rhombille` subsection.
- `.github/workflows/test.yml`'s several pattern-type loops must include `"cairo_pentagonal"`.
- `planter.scad`'s Customizer dropdown comment for `pattern_type` must be updated too -- a past PR review caught this being forgotten when a new pattern was added; do not repeat that.
- `tests/test_decoration_etched_groove.scad`'s `VNF_PATTERN_TYPES` list (mode-independent VNF tiles, currently `["teardrop", "tumbling_cubes", "intertwine", "islamic_star", "rhombille"]`) must gain `"cairo_pentagonal"` -- it belongs there, not in `KIS_PATTERN_TYPES`, because (per the Relief Mode Decision below) this tile's raised and etched VNFs are identical, exactly like `rhombille`'s.
- `tests/test_decoration_tile_aspect.scad`'s VNF-tile list (the `for (pt = [...])` loop asserting the plain square-tile vertical-reps formula) must gain `"cairo_pentagonal"`.

## Geometry Derivation

This section is the load-bearing evidence for the implementer: exact coordinates, the exact affine transform to `_UNIT_TILE` space, and a description of the two independent verifications run (a Python/shapely closure proof, and a live OpenSCAD/BOSL2 smoke test of the real `_tile_from_islands()` code path) with their results. Task 1 below re-states the final OpenSCAD constants/functions verbatim; this section is where they came from and why they're correct.

### Starting point: Wikipedia's "type 4" pentagon

Wikipedia's Cairo pentagonal tiling article gives this concrete pentagon (already independently verified before this plan was written, per this task's own briefing):

```
V0 = (-2, 0)
V1 = ( 2, 0)
V2 = ( 3, 3)
V3 = ( 0, 4)
V4 = (-3, 3)
```

Wound CCW, area 18 (shoelace). Four edges of length √10 (`V1V2`, `V2V3`, `V3V4`, `V4V0`) and one short base edge of length 4 (`V0V1`), ratio √10:4. Right angles at `V2` and `V3`... actually at `V2=(3,3)` and `V4=(-3,3)` (non-adjacent, as required for a "type 4" pentagon). Bilaterally symmetric about the vertical line through `V3=(0,4)` and the base's midpoint `(0,0)`.

### Step 1: the 4-pentagon pinwheel (fundamental domain)

Rotate this pentagon 90° CCW about its own right-angle vertex `(3,3)`, three times, to get 4 copies:

```
P[k] = rotate_90_ccw_about((3,3), k) applied to each vertex of V0..V4,  for k = 0,1,2,3
```

**Verified (Python/shapely, exact rational arithmetic via `fractions.Fraction` cross-checked against floats):** the union of `P[0..3]` has area exactly `4 × 18 = 72` with **zero pairwise overlap** (computed all `C(4,2)=6` pairwise intersections, each exactly 0), confirming the four rotated copies close up perfectly around `(3,3)` with matching edges (this specific fact was already given as verified in this task's briefing; re-confirmed here as the first step of a longer, from-scratch check). This 4-pentagon union is called the "quad" below -- it is the tiling's translational fundamental domain (a 4-tile primitive unit, matching the general "Type 4" pentagon-tiling literature's own statement that Type 4 tilings have a "4-tile primitive unit" under `p4`/`p4g` symmetry).

### Step 2: finding the translation lattice (this is the part the prior attempt got stuck on)

The quad's boundary is a 12-sided polygon (each of the 4 pentagons contributes 3 exposed edges: 2 of its 4 long √10 edges, plus its 1 short base edge -- the other 2 long edges are internal, shared with a neighbor inside the pinwheel). For the quad to tile the plane by **pure translation** (no further rotation/reflection needed between quads), every one of those 12 boundary edges must be the exact negative-direction image of some other boundary edge under a lattice translation.

**Verified by exhaustive search** (Python, exact integer/rational coordinates): every one of the 12 boundary edges matches another boundary edge under translation by one of only two vectors (or their negatives), in the original (pre-normalization) coordinate system centered on the pinwheel above:

```
A = (6, 6)
B = (6, -6)
```

(`A` and `B` are perpendicular, equal length `6√2`, so this is a square lattice, consistent with the tiling's `p4g` wallpaper symmetry.) Lattice cell area = `|det(A,B)| = |6·(-6) - 6·6| = 72`, exactly `4 × 18` = 4 pentagons per translational cell, consistent with the "4-tile primitive unit" fact above and with the Euler-characteristic count independently found in the literature search for this tiling ("elementary cell ... six vertices -- two of degree four and four of degree three" ⟹ `V=6, E=(2·4+4·3)/2=10, F=E-V=4` pentagons per cell on the torus).

**This is exactly the step the prior hand-derivation attempt got stuck on and produced contradictions trying to resolve.** The fix here was to stop guessing and brute-force it: enumerate every boundary edge of the verified-correct pinwheel, and for each one, search small integer combinations of two orthogonal candidate vectors for an exact translation match, rather than trying to reason out the lattice geometrically from the pinwheel's shape. All 12 edges matched using only `±A` or `±B` alone (never a diagonal combination like `A+B`), which is itself a useful confirmation: it means each face of the quad has exactly one direct neighbor in each of the 4 lattice directions, a simple square-adjacency structure.

**Full-plane closure check (Python/shapely, quantized to 1e-9 -- see "Why quantization was necessary" below):** tiled a 13×13 block of translational cells (`m, n` each in `[-6, 6]`, i.e. `676` pentagons total) using `T(m,n) = m·A + n·B`. Result: **a single connected `Polygon` (not a `MultiPolygon`), zero interior holes, area exactly `676 × 18 = 12168`**, matching the expected total with no gaps and no overlaps.

**Why quantization was necessary (and why this matters for the implementation, not just the derivation):** the very first version of this check used raw floating-point coordinates and reported the union as a `MultiPolygon` split into disconnected horizontal bands, despite an exact area match. This looked like a real defect (a genuine periodic gap between rows) but wasn't: floating-point noise (~1e-16) in coordinates that should be bit-identical (e.g. a vertex produced by one translate's `1/12` division vs. another's `2/12 - 1/12`) is enough for `shapely`'s exact-coordinate polygon boolean ops to treat two coincident vertices as merely *near* each other rather than identical, breaking edge adjacency. Rounding every coordinate to 1e-9 before the union (exactly this project's own `_tile_q()`/`_tile_quantize()` workaround in `modules/decoration.scad`, used for precisely this reason) made the union collapse to one connected polygon with the correct area and zero holes. This is a second, independent confirmation that the lattice is correct -- the "gap" was a floating-point artifact, not a geometry defect -- and it is also the reason `_tile_from_islands()`'s existing `_tile_quantize()` step is relied on (not re-implemented) by this pattern's own tile function in Task 1.

### Step 3: the affine transform to `_UNIT_TILE` space

`A` and `B` are perpendicular and equal length, so (unlike an oblique/sheared lattice) a **pure rotation + uniform scale** (no shear, no reflection) maps them exactly onto `(1,0)` and `(0,1)`:

```
u(x, y) = (x + y) / 12
v(x, y) = (x - y) / 12
```

Verified exactly (rational arithmetic): `u,v(A) = u,v(6,6) = (1, 0)`. `u,v(B) = u,v(6,-6) = (1, 1)`... concretely: `u(6,-6) = (6-6)/12 = 0`, `v(6,-6) = (6-(-6))/12 = 1`, i.e. `(0, 1)`. Both map exactly, confirming this transform is the correct normalization to this project's unit-tile convention (`_tile_from_islands()`'s `_UNIT_TILE = [[0,0],[1,0],[1,1],[0,1]]`, repeated by BOSL2 via literal `(1,0)`/`(0,1)` translation).

This transform has determinant `-1/72` (it includes a reflection as a linear map on its own), but the source basis `(A, B)` itself has determinant `-72` (also "reflected" relative to the standard basis, since `A` then `B` in that order sweep clockwise, not counter-clockwise). The product of the two signs is positive, meaning the *composition* -- the images of `A` and `B` under this map -- **is** a proper (non-reflected) `(1,0)`, `(0,1)` pair. (An earlier version of this derivation used `v(x,y) = (y-x)/12` instead, which flips this sign back the other way and requires negating `B` to land on `(0,1)`; that version is *not* used below because it introduces an actual mirror-image of the pentagon into the tile, which -- while geometrically valid, since the pentagon is bilaterally symmetric anyway -- was confirmed unnecessary and is more error-prone to reproduce than the direct `u=(x+y)/12, v=(x-y)/12` form, which needs no sign-flip on either lattice vector.)

Applying `u,v(x,y) = ((x+y)/12, (x-y)/12)` to each of the 4 pinwheel pentagons `P[0..3]` gives 4 exact-fraction pentagons in unit-tile space (computed with Python's `fractions.Fraction`, so these are exact, not rounded):

```
P0_uv = [(-1/6,-1/6), (1/6,1/6), (1/2,0), (1/3,-1/3), (0,-1/2)]
P1_uv = [(1/3,2/3),   (2/3,1/3), (1/2,0), (1/6,1/6),   (0,1/2)]
P2_uv = [(7/6,1/6),   (5/6,-1/6),(1/2,0), (2/3,1/3),   (1,1/2)]
P3_uv = [(2/3,-2/3),  (1/3,-1/3),(1/2,0), (5/6,-1/6),  (1,-1/2)]
```

(Each retains the pinwheel's shared vertex, `(1/2, 0)` -- the image of `(3,3)` -- as its 3rd listed vertex; this is the point where all 4 pentagons meet, now sitting at the midpoint of the tile's bottom-adjacent lattice structure rather than at a tile corner.) Each has area exactly `1/4` (verified: `18 / 72 = 1/4`, since the whole quad has area 72 mapping to unit-tile-cell area 1, and each of the 4 pentagons is an equal `1/4` share).

**Winding note (matters for `offset()`):** the transform above has a negative-determinant *linear* part (see above), so it reverses the pentagon's winding: `P0..P3` above are wound **CW** in `(u,v)` space (verified: shoelace signed area of `P0_uv` is `-1/4`), the opposite of the original CCW `V0..V4`. This is fine and was verified not to matter to BOSL2's `offset(delta=-gap/2, closed=true)` (see "OpenSCAD/BOSL2 verification" below) -- but implementers should not be surprised that these coordinates are CW where the source pentagon was CCW; that is expected, not a mistake to "fix."

### Step 4: covering the unit tile -- which translated copies are needed

Like `tumbling_cubes`'/`rhombille`'s hexagons (which straddle tile edges via `_TC_CENTERS`, a list of 5 hexagon centers, not just 1), the Cairo pentagon's natural placement straddles the `_UNIT_TILE` boundary and needs more than one lattice cell's worth of copies to fully cover `[0,1]×[0,1]` after clipping. The quad's own footprint in `(u,v)` space spans `u ∈ [-1/6, 7/6]`, `v ∈ [-2/3, 2/3]` -- well outside `[0,1]²` -- so `_tile_from_islands()`'s own clip-to-`_UNIT_TILE` step (`intersection(force_region(il[0]), [_UNIT_TILE])`) is what actually trims each copy down to its visible sliver, exactly like every other multi-cell pattern in this file already relies on.

**Exhaustively searched (Python/shapely)** which `(m, n, k)` triples -- translate pentagon `P[k]_uv` by lattice step `(m, n)` -- have any nonzero-area intersection with `[0,1]×[0,1]`, over `m, n ∈ [-2, 2]`, `k ∈ [0,3]`. Exactly **8** such triples exist, and their clipped intersections with the unit square:

```
(m, n, k)     clipped-to-unit-square area
(-1, 0, 2)    1/24
( 0, 0, 0)    1/24
( 0, 0, 1)    1/4
( 0, 0, 2)    1/6
( 0, 1, 0)    1/6
( 0, 1, 2)    1/24
( 0, 1, 3)    1/4
( 1, 1, 0)    1/24
```

**Sum of clipped areas = exactly 1.0** (verified: `4×1/24 + 2×1/6 + 2×1/4 = 1/6 + 1/3 + 1/2 = 1`), and the union of the 8 clipped pieces was verified (via `shapely`, coordinates quantized to 1e-9 as above) to equal the unit square **exactly**: `unit_square.symmetric_difference(union_of_8_pieces).area == 0.0`, with **zero pairwise overlap** among the 8 pieces. This is the complete, minimal set of islands needed for `_cairo_pentagonal_tile()` -- no other `(m,n,k)` combination contributes any area to `[0,1]²`.

**Twin-vertex-on-opposite-edges invariant, checked directly:** collecting every vertex of the 8 clipped pieces that lies exactly on `u=0`, `u=1`, `v=0`, or `v=1` gives, on every edge, exactly the same 3 points: the two tile corners plus one midpoint crossing at `0.5`. `u=0` and `u=1` edges have identical vertex sets `{0, 0.5, 1}` (by the other coordinate); so do `v=0` and `v=1`. This is the exact invariant `_tile_from_islands()`/BOSL2 depend on for stitching repeats together, and it holds exactly (not just approximately) for this construction.

### Step 5: OpenSCAD/BOSL2 verification (not just Python)

The Python/shapely proof above establishes the *mathematical* tiling is correct, but the actual risk for this codebase is whether the real `offset()`/`_tile_from_islands()`/`vnf_from_region()` pipeline in `lib/BOSL2/` handles this construction the same way (correct winding, no degenerate `offset()` shrink, valid VNF, no leftover open edges). This was verified directly by writing a throwaway OpenSCAD script that includes the real `modules/decoration.scad`, defines the 8 `(m,n,k)` placements and the 4 `P[k]_uv` pentagons exactly as above, builds the islands list with `offset(poly, delta=-_CP_GAP/2, closed=true)` (gap `0.05`, matching the constant Task 1 below uses) feeding `_tile_from_islands()`, and asserts on the result. Result (`openscad -o /tmp/x.csg <script>`, exit 0, all echoes as expected):

- `polygon_area(P[k]_uv, signed=true)` for all 4 pentagons: `-0.25` (confirms the CW winding predicted above, consistently negative/CW for all 4 orientations).
- Every one of the 8 `offset(poly, delta=-0.025, closed=true)` calls (`gap/2 = 0.025`) returned a valid 5-vertex shrunk pentagon with `abs(signed_area)` reduced from `0.25` to `≈0.203306` (i.e. BOSL2's `offset()` shrinks correctly regardless of the CW winding -- no sign confusion, no degenerate/empty result).
- `_tile_from_islands(islands)` (the real function, unmodified) produced `is_vnf(tex) == true`.
- `pointlist_bounds(tex[0])` = exactly `[[0,0,0],[1,1,1]]` -- the tile fits the unit cube exactly, with the full `[0,1]` extent actually reached (not a shrunk-inward tile).
- The twin-vertex check (same `_tile_edge_profile()` helper this repo's other tile tests already use) gave **identical** point lists for the `u=0`/`u=1` edges and for the `v=0`/`v=1` edges: `[[0,0],[0.0353553,0],[0.0353553,1],[0.444098,0],[0.444098,1],[0.555902,0],[0.555902,1],[0.964645,0],[0.964645,1],[1,0]]` on both sides of each axis, `10` points each, exact match.
- A full real-render smoke test: `cyl(h=100, r1=75, r2=60, $fn=50, texture=tex, tex_reps=[12,8], tex_depth=1.5, tex_inset=false)` differenced against a disjoint cube (forcing real CGAL Nef-polyhedron evaluation, the same technique this repo's own test files use) completed with **exit 0**, no `CGAL error`, and OpenSCAD's own summary reported `Simple: yes` (a valid, non-self-intersecting manifold) with `3` volumes (planter wall + the untouched half of the cube's cut, as expected from a `difference()` against a disjoint object).

This is one configuration (`pattern_repeat=12`, `smoothness`/`$fn=50`, `raised`-equivalent `tex_inset=false`), not the full CGAL sweep this project requires before shipping -- see Task 1 Step 5 below, which is not optional just because this smoke test passed.

### Relief Mode Decision

**Recommendation: mode-independent, uniform height `1.0` for every pentagon, like `rhombille` -- no `relief_mode` parameter on `_cairo_pentagonal_tile()`.**

Reasoning: the "kis" family's raised/etched split exists because each of *their* tile cells is itself a multi-triangle fan (a kis-operation result) with an obvious sub-structure to vary height across (alternating heights per triangle reads as a pinwheel facet in raised mode, and flattening that same fan to one height in etched mode gives a genuinely different, flatter VNF that reads as an engraved panel rather than an inverted bump). The Cairo pentagon has no analogous natural sub-fan -- it is a single flat convex face per tile, exactly like `rhombille`'s rhombi (each rhombus one flat plateau) or `tumbling_cubes`' rhombi (which vary height only because three DIFFERENT heights sell an isometric-cube illusion specific to that motif, not because etched/raised differ). There is no motif-specific reason to split a single flat pentagon into sub-heights, and doing so arbitrarily (e.g., alternating heights by orientation `k`) would not read as anything meaningful the way `tumbling_cubes`' three-height cube illusion does -- it would just look like a pattern-matching bug. `decorated_solid()`'s existing `tex_inset` machinery already gives a clean etched look for a uniform-height VNF tile (see `rhombille`'s own gallery entry: "etched here is a true inverted copy of the raised relief"), which satisfies this project's etched-should-look-engraved goal (TODO.md: "I wanted it to have an engraved look") just as well as `rhombille`'s does.

## Task 1: `_cairo_pentagonal_tile()` -- geometry, wiring, tests, docs

**Files:**
- Modify: `modules/decoration.scad` (add `_CP_P0`..`_CP_P3`, `_CP_PENTS`, `_CP_PLACEMENTS`, `_CP_GAP`, `_CP_Z`, `_cp_pentagon()`, `_cairo_pentagonal_tile()`; extend `PATTERN_TYPES`; extend `_decoration_texture()`; extend the CGAL-warning `echo()` pattern lists in `decorated_solid()`)
- Create: `tests/test_decoration_cairo_pentagonal.scad`
- Modify: `tests/test_decoration_pattern_types.scad` (extend `EXPECTED_PATTERN_TYPES` and `EXPECTED_VNF_PATTERN_TYPES`)
- Modify: `tests/test_decoration_etched_groove.scad` (extend `VNF_PATTERN_TYPES`)
- Modify: `tests/test_decoration_tile_aspect.scad` (extend the VNF-tile `for` loop's pattern list)
- Modify: `.github/workflows/test.yml` (add `"cairo_pentagonal"` to every pattern-type loop)
- Modify: `planter.scad` (Customizer dropdown comment for `pattern_type`)
- Modify: `README.md` (parameter table, interlocking-patterns enumeration, CGAL section)
- Modify: `docs/gallery.md` (new subsection + regenerated images via `docs/images/render.sh`)
- Modify: `TODO.md` (check off the Cairo pentagonal line)

**Interfaces:**
- Consumes: `_tile_from_islands(islands)`, `_UNIT_TILE` -- both existing, defined in `modules/decoration.scad`'s "Shared plateau-tile builder" section.
- Produces: `_cairo_pentagonal_tile()` (no arguments -- geometry doesn't depend on `relief_mode`, matching `_rhombille_tile()`'s signature). `_decoration_texture(pattern_type, relief_mode)` gains one more branch: `pattern_type == "cairo_pentagonal" ? _cairo_pentagonal_tile() :`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_decoration_cairo_pentagonal.scad`, following `tests/test_decoration_rhombille.scad`'s exact structure (same file this plan's Architecture section is modeled on):

```openscad
// tests/test_decoration_cairo_pentagonal.scad
//
// "cairo_pentagonal" is a custom VNF tile (the Cairo pentagonal tiling,
// Wikipedia "V3^2.4.3.4" -- congruent, irregular pentagons, every pentagon at
// the same height), not a BOSL2 texture name, so it needs a real-render
// check: a tile whose points leave the unit square, whose edges don't line
// up across the tile boundary, or whose walls are wound backwards only fails
// when the geometry is actually evaluated.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("cairo_pentagonal", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"cairo_pentagonal\"");

_tex = _decoration_texture("cairo_pentagonal", "raised");
assert(is_list(_tex) && len(_tex) == 2,
    "_decoration_texture(\"cairo_pentagonal\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex), "_decoration_texture(\"cairo_pentagonal\") must be a valid VNF");

// A VNF texture tile's footprint must lie inside the unit square with Z in
// [0,1]; BOSL2 rejects anything else at render time.
_bounds = pointlist_bounds(_tex[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("cairo_pentagonal tile must fit in the unit cube, got bounds ", _bounds));
// Unlike some VNF tiles that shrink inward and never actually touch every
// edge of the unit square, this construction's pentagons genuinely reach
// every side -- confirm the full extent is used, not just bounded by it.
assert(approx(_bounds[0][0], 0) && approx(_bounds[0][1], 0) &&
       approx(_bounds[1][0], 1) && approx(_bounds[1][1], 1),
    str("cairo_pentagonal tile should reach every edge of the unit square exactly, got bounds ", _bounds));

// VNF tiles take no `style` (that's a heightfield-triangulation setting), and
// _decoration_style() must reach that answer from the resolved texture rather
// than from a pattern_type-specific branch.
assert(_decoration_style("cairo_pentagonal", "raised") == undef,
    "cairo_pentagonal is a VNF tile and must not carry a style override");
assert(_decoration_style("cairo_pentagonal", "etched") == undef,
    "cairo_pentagonal is a VNF tile and must not carry a style override when etched");

// Every pentagon sits at the SAME height, and it's the tile's full height:
// this pattern is a plain pentagon mosaic, not a multi-height illusion like
// tumbling_cubes, and pattern_depth should be fully used. Check the constant
// AND the actual VNF, the same way test_decoration_rhombille.scad does --
// asserting _CP_Z alone would still pass if _cairo_pentagonal_tile()
// accidentally varied height per pentagon orientation.
assert(_CP_Z == 1, str("cairo_pentagonal's uniform pentagon height must be 1, got ", _CP_Z));
_zs = unique([for (p = _tex[0]) p[2]]);
assert(_zs == [0, 1],
    str("cairo_pentagonal's VNF must use exactly two Z levels -- ground (0) and every ",
        "pentagon at the tile's full height (1) -- got ", _zs));

// raised and etched must resolve to the exact same VNF -- this pattern's
// geometry doesn't depend on relief_mode (decorated_solid()'s tex_inset
// handles the raised/etched distinction), unlike the three kis-family
// patterns which genuinely build a different tile per mode.
_tex_etched = _decoration_texture("cairo_pentagonal", "etched");
assert(_tex == _tex_etched,
    "cairo_pentagonal's tile geometry must be identical for \"raised\" and \"etched\" -- only decorated_solid()'s tex_inset should differ");

// The invariant the whole tile design rests on: every vertex the tile leaves
// on one edge needs a twin at the same position on the opposite edge, or
// repeats don't stitch and the surface leaks. Rendering without an error is a
// weak proxy for this -- BOSL2 only enforces it for vertices sitting on
// *open* edges, and a near-miss (an edge resampled at a slightly different
// point, an off-by-epsilon coordinate) can still render while producing a
// subtly non-tiling mesh. So compare the two edges directly.
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex, axis, 0);
    hi = _tile_edge_profile(_tex, axis, 1);
    name = (axis == 0) ? "x" : "y";
    // This construction's own derivation (see the plan's Geometry Derivation
    // section) found exactly 3 points per edge -- both tile corners plus one
    // midpoint crossing -- so more than the 2 corners alone is what proves a
    // pentagon genuinely crosses the seam, not just touches at a corner.
    assert(len(lo) > 2,
        str("cairo_pentagonal tile has only ", len(lo), " vertices on its ", name,
            "=0 edge -- no pentagon spans the seam"));
    assert(len(lo) == len(hi),
        str("cairo_pentagonal tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("cairo_pentagonal tile ", name, " edge vertices don't line up: ", mismatched));
}

difference() {
    decorated_solid("cairo_pentagonal", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
openscad -o /tmp/test.csg tests/test_decoration_cairo_pentagonal.scad
```
Expected: FAIL -- `"cairo_pentagonal"` is not yet in `PATTERN_TYPES` (ERROR: Assertion failed at the `in_list` check).

- [ ] **Step 3: Add the tile geometry to `modules/decoration.scad`**

Insert a new section immediately after the existing `_rhombille_tile()` function (right before the `"--- Kisrhombille"` comment block), so the two most recently added tiles sit next to each other in file order (matching how `rhombille` itself was placed right after `tumbling_cubes`):

```openscad
// --- Cairo pentagonal (dual of the snub square tiling) ----------------------
//
// Wikipedia "V3^2.4.3.4": a tessellation by congruent, irregular,
// bilaterally-symmetric convex pentagons -- four long edges and one short
// edge, two non-adjacent right angles. Every pentagon sits at the same
// height here (like rhombille), since -- unlike the "kis" family -- a single
// Cairo pentagon has no natural sub-fan to vary height across; see this
// pattern's plan document (docs/superpowers/plans/2026-09-19-cairo-pentagonal-pattern.md)
// for the full derivation and the computational area/closure verification
// this construction is based on (Python/shapely area-and-overlap checks on a
// 13x13-cell patch, plus a live OpenSCAD/BOSL2 smoke test of this exact code
// path) -- do not re-derive the lattice by hand; it was verified, not guessed.
//
// Starting pentagon (Wikipedia's own "type 4" worked example), rotated 90
// degrees about its own right-angle vertex (3,3) three times to close a
// 4-pentagon pinwheel (the tiling's translational fundamental domain), then
// mapped into unit-tile space by u=(x+y)/12, v=(x-y)/12 -- a pure rotation
// plus uniform scale (verified to send this pinwheel's translation lattice
// vectors (6,6) and (6,-6) exactly onto (1,0) and (0,1)). The 4 resulting
// pentagons below are already in that normalized (u,v) space; each has area
// exactly 1/4 and is wound CW (the normalizing transform reverses the
// original CCW winding -- verified harmless to BOSL2's offset()).
_CP_P0 = [[-1/6,-1/6], [1/6,1/6], [1/2,0], [1/3,-1/3], [0,-1/2]];
_CP_P1 = [[1/3,2/3],   [2/3,1/3], [1/2,0], [1/6,1/6],   [0,1/2]];
_CP_P2 = [[7/6,1/6],   [5/6,-1/6],[1/2,0], [2/3,1/3],   [1,1/2]];
_CP_P3 = [[2/3,-2/3],  [1/3,-1/3],[1/2,0], [5/6,-1/6],  [1,-1/2]];
_CP_PENTS = [_CP_P0, _CP_P1, _CP_P2, _CP_P3];

// Which (lattice-step, pentagon-orientation) copies have any overlap with the
// unit square -- exhaustively searched over lattice steps -2..2 in each
// direction; exactly these 8 do (their clipped areas sum to exactly 1.0, and
// their union was verified to equal the unit square exactly, with zero
// overlap among them). Each entry is [m, n, k]: pentagon _CP_PENTS[k]
// translated by (m, n) in unit-tile lattice steps.
_CP_PLACEMENTS = [[-1,0,2], [0,0,0], [0,0,1], [0,0,2],
                  [0,1,0], [0,1,2], [0,1,3], [1,1,0]];

function _cp_pentagon(m, n, k) = [for (p = _CP_PENTS[k]) [p[0] + m, p[1] + n]];

_CP_GAP = 0.05; // engraved groove width, in tile fractions -- own constant,
                // same scale as _KIS_GAP/_RH_GAP but never shared with them
_CP_Z   = 1.0;  // every pentagon reaches the tile's full height (uniform,
                // like rhombille -- see this pattern's plan document's
                // "Relief Mode Decision" for why no relief_mode split is used)

function _cairo_pentagonal_tile() =
    _tile_from_islands([
        for (pl = _CP_PLACEMENTS)
            let (poly = _cp_pentagon(pl[0], pl[1], pl[2]),
                 r = offset(poly, delta = -_CP_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _CP_Z]
    ]);
```

- [ ] **Step 4: Wire it into `PATTERN_TYPES` and `_decoration_texture()`**

In `PATTERN_TYPES`, append `"cairo_pentagonal"` after `"rhombille"`:

```openscad
PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                 "bricks", "checkers", "dots", "cubes", "tri_grid",
                 "teardrop", "tumbling_cubes", "intertwine", "islamic_star",
                 "tetrakis_square", "kisrhombille", "triakis_triangular",
                 "rhombille", "cairo_pentagonal"];
```

Update the file's opening comment block above `PATTERN_TYPES` (currently documents "the eight custom VNF tiles") to say "the nine custom VNF tiles" and add `cairo_pentagonal` to the named list alongside `rhombille`.

In `_decoration_texture()`, add one more branch, right after the `rhombille` line:

```openscad
    pattern_type == "rhombille"          ? _rhombille_tile() :
    pattern_type == "cairo_pentagonal"   ? _cairo_pentagonal_tile() :
    pattern_type;
```

- [ ] **Step 5: Extend the CGAL-warning pattern list in `decorated_solid()`**

For now, add `"cairo_pentagonal"` to the *milder* "measured clean everywhere" bucket (the `else if` branch currently listing `"tetrakis_square", "kisrhombille", "triakis_triangular"`) as a **starting hypothesis only** -- Step 8 below runs the real CGAL sweep and this placement must be revisited (moved to the "known to abort" bucket alongside `tumbling_cubes`/`intertwine`/`islamic_star`/`rhombille`, with documented failing values) if that sweep finds a break. Do not skip Step 8 on the strength of this plan's own single-configuration smoke test (Geometry Derivation, Step 5) -- that one data point is encouraging but is not a sweep across `pattern_repeat`/`smoothness`.

- [ ] **Step 6: Run the new test and the full pattern-types test**

```bash
openscad -o /tmp/test_cairo_pentagonal.csg tests/test_decoration_cairo_pentagonal.scad
openscad -o /tmp/test_cairo_pentagonal.stl tests/test_decoration_cairo_pentagonal.scad 2>&1 | tee /tmp/cairo_render.log
grep -i "CGAL error" /tmp/cairo_render.log
```
Expected: PASS (exit 0, no ERROR, no `CGAL error` in the log).

Update `tests/test_decoration_pattern_types.scad`:

```openscad
EXPECTED_PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                          "bricks", "checkers", "dots", "cubes", "tri_grid",
                          "teardrop", "tumbling_cubes", "intertwine",
                          "islamic_star", "tetrakis_square", "kisrhombille",
                          "triakis_triangular", "rhombille", "cairo_pentagonal"];

EXPECTED_VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine",
                              "islamic_star", "tetrakis_square", "kisrhombille",
                              "triakis_triangular", "rhombille", "cairo_pentagonal"];
```

Also update that file's header comment to mention `cairo_pentagonal` joins the list as a ninth VNF pattern, with the same "does NOT need the etched-vs-raised carve-out" note `rhombille`'s own entry there already carries (word it precisely: this pattern, like `rhombille`, resolves to the exact same VNF in both relief modes).

Re-run `tests/test_decoration_pattern_types.scad` and confirm it still passes with the extended lists.

Update `tests/test_decoration_etched_groove.scad`'s `VNF_PATTERN_TYPES`:

```openscad
VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine", "islamic_star",
                     "rhombille", "cairo_pentagonal"];
```

(`cairo_pentagonal` must **not** be added to `KIS_PATTERN_TYPES` in that same file -- its etched and raised tiles are identical, the opposite of that list's defining property.) Re-run that file and confirm it still passes.

Update `tests/test_decoration_tile_aspect.scad`'s VNF-tile-pattern `for` loop:

```openscad
for (pt = ["teardrop", "tumbling_cubes", "intertwine", "islamic_star", "rhombille",
           "cairo_pentagonal", "tetrakis_square", "kisrhombille", "triakis_triangular",
           "diamonds", "pyramids", "checkers"]) {
```

Re-run that file and confirm it still passes (this pattern uses the plain square-tile vertical-reps formula, same as every other custom VNF tile -- no new aspect-correction category needed).

- [ ] **Step 7: `planter.scad` Customizer dropdown comment**

Find `pattern_type`'s Customizer dropdown declaration/comment in `planter.scad` (grep for `pattern_type` and look for the comma-separated value-list comment immediately above/beside its `[...]` dropdown annotation, the same one README.md's parameter table mirrors) and add `"cairo_pentagonal"` to it, in the same position (end of list, after `"rhombille"`). This is the exact step a prior PR review caught missing -- do not skip it.

- [ ] **Step 8: CGAL sweep -- determine the real warning bucket**

Following the exact methodology `rhombille`'s own plan (`docs/superpowers/plans/2026-09-17-rhombille-pattern.md`, Step 6) and the kis-family plan used: render the full assembly (`tests/test_planter_integration.scad`, matching `.github/workflows/test.yml`'s own invocation pattern) with `pattern_type="cairo_pentagonal"` across a sweep of `pattern_repeat` values (at least: a low value like 4, the shipped default 16, and a higher value like 24 or 32) crossed with `smoothness` values (at least 24 and the shipped default 60), in **both** `relief_mode="raised"` and `"etched"` -- the same joint-dependency methodology README.md documents for `tumbling_cubes`/`islamic_star`/`intertwine`/`rhombille` (a value clean in one relief mode is not automatically clean in the other). Example invocation, matching this repo's established pattern:

```bash
for reps in 4 16 24 32; do
  for smooth in 24 60; do
    for relief in raised etched; do
      openscad -D 'pattern_type="cairo_pentagonal"' -D "relief_mode=\"$relief\"" \
               -D "pattern_repeat=$reps" -D "smoothness=$smooth" \
               -o /tmp/cp_${reps}_${smooth}_${relief}.stl tests/test_planter_integration.scad \
               2>&1 | tee /tmp/cp_${reps}_${smooth}_${relief}.log
      grep -i "CGAL error" /tmp/cp_${reps}_${smooth}_${relief}.log && echo "ABORT: reps=$reps smooth=$smooth relief=$relief"
    done
  done
done
```

Do this on the real CI runner if at all possible, not local-only -- README.md and this repo's git history both document that CGAL fragility has previously differed between a local macOS build and GitHub Actions' Ubuntu build despite an identical reported OpenSCAD version (`intertwine`'s and `rhombille`'s own CGAL notes in README.md give the exact precedent and why it matters).

- If every combination is clean: leave Step 5's placement in the "measured clean everywhere" bucket. Record the specific values tested in README.md's CGAL section (Step 10 below).
- If any combination aborts CGAL: move `"cairo_pentagonal"` to the "known to abort" bucket in `decorated_solid()`'s `echo()` (alongside `tumbling_cubes`/`intertwine`/`islamic_star`/`rhombille`), and document the specific failing `pattern_repeat`/`smoothness`/`relief_mode` combinations in README.md exactly the way `rhombille`'s own failure-mode documentation there is written (name specific clean and specific failing values, not a vague range).

- [ ] **Step 9: `.github/workflows/test.yml`**

Add `"cairo_pentagonal"` to every loop that enumerates all pattern types:
- Line ~74-75's per-tile CGAL-forcing loop (`for f in teardrop tumbling_cubes intertwine islamic_star tetrakis_square kisrhombille triakis_triangular rhombille; do`) -- append `cairo_pentagonal` (this exercises `tests/test_decoration_cairo_pentagonal.scad` from Step 1/6 above).
- Line ~96's single-pattern texture-build loop (`for pt in none ridges ... rhombille; do`) -- append `cairo_pentagonal`.
- Line ~297-301's full-assembly reduced-value loop (the `for combo in "ridges 4" ... "rhombille 13"; do` list) -- append `"cairo_pentagonal <value>"` using whatever reduced `pattern_repeat` value Step 8's sweep found clean in **both** relief modes at `smoothness=24` (this loop's fixed smoothness), following the exact reasoning-and-comment style the `rhombille`/`intertwine`/`tumbling_cubes`/`islamic_star` entries immediately above it already use in that file (explain *why* that specific value was chosen -- clean neighbors on both sides, not an isolated clean value between two aborts -- not just what it is).
- If Step 8 found the shipped defaults (`pattern_repeat=16`, `smoothness=60`) unsafe in either relief mode: add a default-settings pin the same way the `for relief in raised etched; do run_assembly_combo "islamic_star" ...` block (lines ~337-341) already does for the other fragile patterns, following that exact pattern.
- Line ~452's invalid-`pattern_type` negative-check list -- append `cairo_pentagonal` (this list must match `PATTERN_TYPES` so the assertion-message check stays accurate).

Run the equivalent of this workflow's own test script locally (or push and watch the real run, per this plan's own CGAL-sweep step) and confirm zero `FAIL` lines.

- [ ] **Step 10: Documentation -- README.md**

- Add `"cairo_pentagonal"` to the `pattern_type` parameter's valid-values list (the same line documenting `..."rhombille"`).
- Extend the "N of the pattern_type values are interlocking" sentence (currently names `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`, `"rhombille"` explicitly) to also name `"cairo_pentagonal"` and update the count from five to six. This class of claim has already gone stale once in this repo's history (caught in the kis-family PR review) -- name it explicitly, don't just bump a number without checking the sentence still reads correctly with six names in the list.
- Add `"cairo_pentagonal"`'s entry to the CGAL-fragility section per Step 8's actual findings, following the exact structure and level of detail `rhombille`'s own paragraph there uses (specific clean values, specific failing values if any, and whether it was re-verified against a real CI run or only measured locally).

- [ ] **Step 11: Documentation -- gallery**

Add a new subsection to `docs/gallery.md`, immediately after the existing `### rhombille` subsection, matching its exact structure:

```markdown
### cairo_pentagonal

| Raised | Etched |
|---|---|
| ![cairo_pentagonal, raised](images/pattern-cairo_pentagonal-raised.png) | ![cairo_pentagonal, etched](images/pattern-cairo_pentagonal-etched.png) |

Interlocking. The Cairo pentagonal tiling (Wikipedia "V3^2.4.3.4", dual of the
snub square tiling): congruent, irregular pentagons -- four long edges and one
short edge, two non-adjacent right angles -- every pentagon raised to the same
height. Because the geometry doesn't change between raised and etched,
`"etched"` here is a true inverted copy of the raised relief, like
`rhombille`, not a separate flat-panel construction like the "kis" family.
```

Also add `cairo_pentagonal` to the gallery's Table of Contents list (immediately after the `rhombille` entry) and to the "Pattern Comparison" section's interlocking-patterns list if one exists there (check the same sentence README.md's own interlocking-patterns list mirrors, at/around gallery.md line 70, and keep the two files' wording consistent).

Regenerate images using `docs/images/render.sh` (check that script's exact invocation and output path convention, matching `pattern-<name>-<relief>.png`) -- confirm it completes cleanly and `git status` shows exactly the 2 new images plus doc edits, no unexpected changes to unrelated images.

- [ ] **Step 12: `TODO.md`**

Check off the Cairo pentagonal line in the tessellation backlog:

```markdown
    - [x] Cairo pentagonal tiling ("V3^2.4.3.4", distinctive interlocking pentagons -- probably the most visually striking one) -- batch 2
```

- [ ] **Step 13: Commit**

```bash
git add modules/decoration.scad tests/test_decoration_cairo_pentagonal.scad \
        tests/test_decoration_pattern_types.scad tests/test_decoration_etched_groove.scad \
        tests/test_decoration_tile_aspect.scad .github/workflows/test.yml \
        planter.scad README.md docs/gallery.md docs/images TODO.md
git commit -m "Add cairo_pentagonal pattern_type: the Cairo pentagonal tiling, verified computationally"
```

## Self-Review Notes

- **Spec coverage:** the Geometry Derivation section covers exact pentagon coordinates, the exact affine transform, the exact translation lattice (reduced to `(1,0)`/`(0,1)`), a description of both verifications run (Python/shapely closure proof and a live OpenSCAD/BOSL2 smoke test) and their results, and the Relief Mode Decision with reasoning -- all five things the task's "What to produce" section required. Task 1 covers every wiring point named in the task (`PATTERN_TYPES`, `_decoration_texture()`, the CGAL echo bucket, `planter.scad`'s dropdown comment, `EXPECTED_PATTERN_TYPES`/`EXPECTED_VNF_PATTERN_TYPES`, `test_decoration_etched_groove.scad`'s VNF list, `test_decoration_tile_aspect.scad`'s VNF list, the CI workflow's several loops, README.md, gallery.md, TODO.md).
- **No placeholders:** every constant (`_CP_P0`..`_CP_P3`, `_CP_PLACEMENTS`, `_CP_GAP`, `_CP_Z`) is a literal exact value derived and verified in the Geometry Derivation section, not a TBD. The one genuinely open item (which CGAL warning bucket this pattern belongs in) is an honest dependency on Task 1 Step 8's real measurement, not a placeholder -- the step gives the exact sweep methodology and both possible outcomes' exact handling, matching how the kis-family plan handled the same kind of measurement-dependent step.
- **Type consistency:** `_cairo_pentagonal_tile()` takes no arguments, matching `_rhombille_tile()`'s signature (both mode-independent), not the "kis" family's `_foo_tile(relief_mode)` shape -- checked consistently throughout Task 1's wiring steps and the test file.
