# Deltoidal Trihexagonal Tiling Pattern Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `"deltoidal_trihexagonal"` as a new `pattern_type` -- the deltoidal trihexagonal tiling (Wikipedia "V3.4.6.4", the dual of the rhombitrihexagonal tiling), a tessellation by congruent kite/deltoid quadrilaterals. Each kite has two short edges and two long edges (verified below: ratio exactly `sqrt(3)/(sqrt(3)-1)`-family, not 1, so it is genuinely a kite and not a rhombus) and is NOT symmetric under the "kis" family's or `floret_pentagonal`'s single-rosette decision framework in the simple way those patterns were: this tiling's kites simultaneously belong to a 6-fan (around the tiling's hexagon-derived vertices), a 4-fan (around its square-derived vertices), and a 3-fan (around its triangle-derived vertices) all at once, since every kite touches one vertex of each type plus a fourth (repeated) square-derived vertex. See "Relief Mode Decision" below for why this leads to a **mode-independent, uniform-height** recommendation (like `rhombille`/`cairo_pentagonal`), not an alternating one (like `floret_pentagonal`/the "kis" family).

**Architecture:** One new custom VNF tile function, `_deltoidal_trihexagonal_tile()` (no `relief_mode` parameter, per the Relief Mode Decision below), built the same way `_cairo_pentagonal_tile()`/`_rhombille_tile()` are: a list of `[region, height]` islands (each island a translated copy of one of 6 pre-computed kite orientations, shrunk by half the groove width) fed to the existing `_tile_from_islands()` helper. The translation lattice this tiling needs is a **triangular (60-degree) lattice of hexagon-derived vertices** -- the exact same lattice *shape* `tumbling_cubes`/`rhombille`/`kisrhombille`/`floret_pentagonal` already normalize via a pure rotation + the existing sqrt(3)-family anisotropic scale, no shear. This plan re-derives this lattice from scratch for `deltoidal_trihexagonal`'s own specific primal tiling (the rhombitrihexagonal tiling, built directly from a regular hexagon + attached squares + attached triangles, edge length 1 -- **not** the same primal tiling `floret_pentagonal` used, and not `tumbling_cubes`/`rhombille`'s own plain edge-to-edge hexagonal tiling either, which was checked and found to be a different, non-Kagome-like lattice that does not apply here -- see Geometry Derivation, Step 0) and verified computationally (Python/sympy exact-radical checks, Python/shapely + exact-`Fraction` closure checks over multi-cell patches, plus a live OpenSCAD/BOSL2 smoke test of the real `_tile_from_islands()` code path) that **no shear is needed**.

The kite shape, the translation lattice, and the affine transform to `_UNIT_TILE` space all come from a fully computationally-verified from-scratch construction (see "Geometry Derivation" below) -- **do not re-derive this from scratch a second time**. No single concrete worked-coordinate source was used (analogous to `floret_pentagonal`'s own derivation, not `cairo_pentagonal`'s Wikipedia-sourced pentagon): the primal rhombitrihexagonal tiling was built directly from its combinatorial/metric definition (a regular hexagon, edge 1, with a unit square attached to each edge and a unit equilateral triangle filling the gap at each vertex, vertex figure 3.4.6.4 verified everywhere), then its literal face-centroid dual was taken (each dual vertex is a primal face centroid; each dual face/kite is the cyclically-ordered set of face centroids incident to one primal vertex), and that dual was verified over multiple translational cells before any coordinate was accepted.

**Tech Stack:** OpenSCAD 2021.01, BOSL2 (`lib/BOSL2/std.scad`), this repo's existing `modules/decoration.scad` VNF-tile infrastructure (`_tile_from_islands()`, `_UNIT_TILE`), Python 3 + `numpy`/`shapely`/`sympy` (used only for this plan's own offline verification, not shipped).

**Spec:** No separate spec document -- this plan follows the same shape as `docs/superpowers/plans/2026-09-19-cairo-pentagonal-pattern.md` and `docs/superpowers/plans/2026-09-20-floret-pentagonal-pattern.md`, and `TODO.md`'s tessellation backlog entry for "Deltoidal trihexagonal tiling ... batch 3" (the last remaining item in that backlog). The geometry itself is derived and verified in this plan's own "Geometry Derivation" section below.

## Global Constraints

- New pattern name: `"deltoidal_trihexagonal"`, appended to `PATTERN_TYPES` immediately after `"floret_pentagonal"` (the current last entry, confirmed by reading `modules/decoration.scad` fresh as of this plan -- PR #21 merged and did add `"floret_pentagonal"` as the last entry).
- The tile is a VNF (not a BOSL2 texture string), added to `EXPECTED_VNF_PATTERN_TYPES` in `tests/test_decoration_pattern_types.scad`.
- The tile **is not** in `_ASPECT_EXCLUDED_PATTERNS` and **is not** in `_ASPECT_SQRT3_PATTERNS`, and this plan does **not** need any new aspect-correction mechanism -- like `tumbling_cubes`/`rhombille`/`floret_pentagonal`, the rotation + anisotropic scale that normalizes this tiling's triangular lattice to `_UNIT_TILE` space is baked directly into the kite vertex coordinates below (Geometry Derivation, Step 4), not applied at render time. Treated by `_square_tile_vertical_reps()` exactly like `rhombille`/`cairo_pentagonal`/`floret_pentagonal` -- no code changes needed there.
- **No `relief_mode` parameter** -- `_deltoidal_trihexagonal_tile()` takes no arguments, matching `_rhombille_tile()`/`_cairo_pentagonal_tile()`'s signature, not the "kis" family's/`floret_pentagonal`'s `_foo_tile(relief_mode)` shape. See "Relief Mode Decision" below.
- Use gap `0.05` (own named constant `_DT_GAP`, following this repo's convention of never sharing another pattern's groove-width constant even at the same numeric value as `_KIS_GAP`/`_TC_GAP`/`_RH_GAP`/`_CP_GAP`/`_FP_GAP`).
- Every kite is raised to the tile's full height (own named constant `_DT_Z = 1.0`, following the same never-shared-constant convention).
- CGAL-fragility warning: this plan's own smoke-test sweep (Geometry Derivation, "OpenSCAD/BOSL2 verification" below) measured **zero CGAL aborts** across 10 `pattern_repeat`/`smoothness` combinations on a bare textured cylinder differenced against a disjoint cube -- a genuinely different result from every other large-flat-plateau pattern in this file (`tumbling_cubes`/`islamic_star`/`intertwine`/`rhombille`/`cairo_pentagonal`/`floret_pentagonal` all found at least one real abort somewhere in their own equivalent sweeps). This plan places `"deltoidal_trihexagonal"` in the **milder "measured clean everywhere" bucket** (alongside the "kis" family) on that evidence, but flags this placement as provisional: the tile's construction mechanism (flat plateau facets, wide chords across the wall's curvature -- 14 kite islands per unit tile, mechanically the same class of construction as `rhombille`/`cairo_pentagonal`/`floret_pentagonal`, not the "kis" family's small-triangle-facet safety) is exactly the class of construction that has bitten every prior pattern in this bucket-placement decision, so Task 1's own CGAL-sweep step must independently re-measure across a full `pattern_repeat`/`smoothness` grid (not just re-confirm this plan's 10-point sample) **and** get at least one confirmation against a real GitHub Actions Ubuntu run before this placement is trusted for the shipped defaults, per the `floret_pentagonal`/`cairo_pentagonal`/`intertwine` precedent of local-clean not implying CI-clean.
- README.md's `pattern_type` parameter table, the "N of the pattern_type values are interlocking" enumeration (currently names `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`, `"rhombille"`, `"cairo_pentagonal"`, `"floret_pentagonal"`), and the CGAL-fragility section must all be updated by name.
- `docs/gallery.md` needs a new subsection (a single example render, since this pattern is mode-independent -- see the `rhombille`/`cairo_pentagonal` subsections for the one-image-set precedent... actually those subsections still show a Raised/Etched pair of images even though the VNF is identical, for visual-table consistency with every other pattern's subsection; follow that same two-column-identical-VNF convention here, not a one-image layout) following the exact structure of the `cairo_pentagonal`/`rhombille` subsections.
- `.github/workflows/test.yml`'s several pattern-type loops must include `"deltoidal_trihexagonal"`.
- `planter.scad`'s Customizer dropdown comment for `pattern_type` (line 48 as of this plan) must be updated too -- a past PR review caught this being forgotten twice already; do not repeat it a third time.
- `tests/test_decoration_etched_groove.scad`: because this pattern's raised and etched tiles are the **same** VNF (see Relief Mode Decision), `"deltoidal_trihexagonal"` goes in that file's `VNF_PATTERN_TYPES` list, **not** the `KIS_PATTERN_TYPES`-style category -- read the file fresh in Task 1 Step 6 to confirm its exact current shape before editing (as of this plan, `VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine", "islamic_star", "rhombille", "cairo_pentagonal"]`, and `KIS_PATTERN_TYPES = ["tetrakis_square", "kisrhombille", "triakis_triangular", "floret_pentagonal"]`).
- `tests/test_decoration_tile_aspect.scad`'s VNF-tile list (the plain-square-tile-formula loop) must gain `"deltoidal_trihexagonal"` -- it uses the ordinary formula like every other custom VNF tile.

### What "rectangular lattice" means here, and why this pattern qualifies

The task that produced this plan drew a hard line: a translation lattice is acceptable for this project only if it can be normalized to `_UNIT_TILE` space via **rotation + anisotropic scale**, never a genuine **shear**. The declined `prismatic_pentagonal` plan hit a lattice whose two generators were neither perpendicular nor equal length, which cannot be sent to `(1,0)`/`(0,1)` without a shear term.

`deltoidal_trihexagonal`'s natural translation lattice, by contrast, has **two equal-length generators at exactly 60 degrees** (see Geometry Derivation, Step 1: both generators have length exactly `1 + sqrt(3)`, angle exactly 60 degrees, verified with `sympy` exact radicals) -- a *triangular* lattice, the same shape `tumbling_cubes`/`rhombille`/`kisrhombille`/`floret_pentagonal` already use. This plan re-derives and re-verifies that fold for `deltoidal_trihexagonal`'s own specific lattice (Geometry Derivation, Steps 1-4) from its own from-scratch primal construction, rather than assuming it transfers from `floret_pentagonal`'s own (different) primal tiling.

**Important note on a dead end avoided:** `tumbling_cubes`/`rhombille`/`kisrhombille`'s own hexagon lattice (`_TC_V`/`_TC_CENTERS`) was checked first as a possible shortcut (Geometry Derivation, Step 0) since it looked superficially reusable. It was **not** reusable: that lattice is a plain edge-to-edge hexagonal tiling (hexagons sharing full edges, degree-3 vertices, no triangles or squares at all), not the Kagome-like or rhombitrihexagonal structure this pattern's dual construction needs. This was confirmed computationally (adjacent `_TC_V` hexagons share **two** vertices, i.e. a full edge, not one point) before being discarded, rather than assumed to work by analogy and only found broken later.

## Geometry Derivation

This section is the load-bearing evidence for the implementer: exact coordinates, the exact affine transform to `_UNIT_TILE` space, and a description of the independent verifications run, with their results. Task 1 below re-states the final OpenSCAD constants/functions verbatim; this section is where they came from and why they're correct.

### Step 0: ruled out reusing `tumbling_cubes`'s hexagon lattice

Checked first, since `kisrhombille` already reuses `tumbling_cubes`'s hexagon/rhombus geometry directly and it seemed plausible this pattern could too. Computed (Python, exact `Fraction` arithmetic) which vertices of `_TC_V`'s hexagon at the origin coincide with vertices of each of its 6 nearest-neighbour hexagons (centers at `_TC_CENTERS`-implied lattice steps `(1,0)`, `(-1,0)`, `(0.5,0.5)`, `(-0.5,-0.5)`, `(-0.5,0.5)`, `(0.5,-0.5)`): every neighbour shares **exactly 2** vertices with the origin hexagon (a full shared edge), not the single shared point a Kagome/rhombitrihexagonal-style tiling would have. This confirms `_TC_V`/`_TC_CENTERS` encode a plain edge-to-edge hexagonal tiling (6.6.6, honeycomb) with no triangles or squares -- not usable as the primal for this pattern's dual construction. Abandoned this shortcut and built the actual rhombitrihexagonal tiling from scratch instead (Step 1).

### Step 1: building and verifying the primal rhombitrihexagonal tiling

No single concrete worked-coordinate source was available, so the primal tiling was constructed directly from its combinatorial/metric definition (Wikipedia "V3.4.6.4": at every vertex, 1 triangle, 2 squares and 1 hexagon, all edge length 1, in order triangle-square-hexagon-square):

- One regular hexagon `H0`, edge length 1 (circumradius 1, since a regular hexagon's edge equals its circumradius), vertex-up, centered at the origin: vertices at `(cos(90+60k), sin(90+60k))` for `k=0..5` (`sympy`, exact radicals: e.g. vertex 1 is exactly `(-sqrt(3)/2, 1/2)`).
- For each of `H0`'s 6 edges, an outward-attached unit square: the square on edge `k` (between vertices `k` and `k+1`) has its other two vertices at `V_k + n_k` and `V_{k+1} + n_k`, where `n_k` is the edge's outward unit normal (`n_k` at angle `120+60k` degrees) -- this is exact by construction (edge length 1, normal unit length, so translating a unit-length edge by a unit-length perpendicular vector produces a unit square).
- For each of `H0`'s 6 vertices, an outward-attached unit equilateral triangle filling the gap between the two adjacent squares: at vertex `k`, the triangle is `[V_k, V_k + n_k, V_k + n_{k-1}]`. This triangle is automatically equilateral with side 1: the hexagon's own 120-degree interior angle at `V_k` leaves 240 degrees of exterior angle, split as `90 (square_{k-1}) + 60 (triangle) + 90 (square_k)` -- matching the required vertex figure exactly -- so the triangle's two edges from `V_k` (both unit length, both already-placed square vertices) meet at exactly 60 degrees, making `V_k + n_k` to `V_k + n_{k-1}` also unit length by the law of cosines at 60 degrees.
- **Verified (Python/numpy, patch of hexagon-lattice steps `m,n` in `[-3,3]`, 49 hexagons):** the neighbouring-hexagon centers found by this construction (each hexagon's own outward edge normals, scaled by `1 + sqrt(3)`) are, at every one of the 6 directions, at distance **exactly `1 + sqrt(3)`** and **exactly 60 degrees** apart (`sympy` exact radicals: `|G1| = |G2| = 1 + sqrt(3)`, `dot(G1,G2)/(|G1||G2|) = 1/2` exactly). Generating the full face set (hexagons + squares + triangles) over this patch and checking vertex degree/incident-face-kind for every vertex in the patch's core region (`|x|<3, |y|<3`, 34 vertices, away from the patch boundary): **every one has degree exactly 4, with incident faces exactly `{square, triangle, hexagon, square}`** (in cyclic order) -- the `3.4.6.4` vertex figure holds everywhere checked, confirming a valid, gapless rhombitrihexagonal tiling (no separate area/overlap/hole check was needed beyond this vertex-figure check, since the construction is provably edge-to-edge and gap-free by the metric argument above -- but see Step 5 below for an explicit area/closure check on the resulting **dual** kite tiling, which is the geometry that actually ships).

This confirms the primal tiling is a valid, gapless rhombitrihexagonal tiling with translation lattice generators `G1`, `G2` of equal length `1+sqrt(3)`, 60 degrees apart -- a triangular lattice, the acceptable shape per "What 'rectangular lattice' means here" above.

### Step 2: the dual kite, built directly from face data

For each vertex of one hexagon's own 6-vertex rosette (the 4 incident faces per vertex: the hexagon itself, the two adjacent squares, and the triangle at that vertex), the dual kite is the 4 face centroids in cyclic order: `[hex_centroid, sq_prev_centroid, tri_centroid, sq_cur_centroid]`.

**Verified exactly** (`sympy`, all 6 kites of `H0`'s own rosette, in the pre-transform coordinate system): all 6 have area **exactly** `sqrt(3)/8 + 3/8`... (the exact symbolic value; verified numerically to match a shoelace computation to floating-point precision across all 6, std deviation ~0), each is **convex**, each is wound **CCW**, and each has edge lengths in the pattern `(short, long, long, short)` around the kite with `short != long` -- confirming a genuine kite/deltoid (2 pairs of adjacent equal sides, unequal to each other), not a rhombus. The kite's own axis of symmetry runs from the hexagon centroid (the hub, shared by all 6) to the triangle centroid (the tip); the two "side" vertices (the two square centroids) are mirror images of each other across that axis, as required for a proper deltoid.

The hexagon centroid vertex has degree 6 (all 6 kites of one hexagon's rosette meet there -- structurally the same shape of fan `floret_pentagonal`'s own rosette used), the square centroid vertices have degree 4 (4 kites meet there: 2 from this hexagon's rosette, 2 from the neighbouring hexagon that shares that square), and the triangle centroid vertices have degree 3 (3 kites meet there, one from each of the 3 different hexagons whose own vertex touches that triangle). **Every individual kite belongs to exactly one 6-fan, one 3-fan, and touches two different 4-fans (at its two side vertices)** -- this three-way (in fact four-way, counting both 4-fans separately) overlapping-fan structure is the key fact behind the Relief Mode Decision below.

### Step 3: the translation lattice and per-cell kite count

Since the whole face/vertex complex is translation-covariant under `G1`/`G2` (every hexagon has the same absolute orientation -- no rotation between hexagons, only translation, confirmed by construction since every hexagon uses the identical base-angle-90 vertex layout), `G1`/`G2` are the dual kite tiling's own translation lattice generators too. The primitive cell area is `|G1 x G2| = (1+sqrt(3))^2 * sin(60) = (4+2*sqrt(3)) * sqrt(3)/2`, which equals **exactly 6 times** one kite's own area (verified: the numeric ratio is `6.0000...` to floating-point precision) -- 6 kites per primitive cell, matching "1 hexagon (hence 1 rosette of 6 kites) per primitive cell," the same "6 per cell" relationship `floret_pentagonal` found for its own (different) primal tiling.

### Step 4: the affine transform to `_UNIT_TILE` space -- rotation + anisotropic scale, no shear

`G1` was chosen along the x-axis (angle 0) by construction (one of the hexagon's own 6 outward edge-normal directions), so **no rotation is needed** at all -- a further simplification versus `floret_pentagonal`'s own transform, which did need a nonzero rotation angle. Define `T(x,y) = (x / (1+sqrt(3)), y / ((1+sqrt(3)) * sqrt(3)))` -- scale x by `1/|G1|`, and scale y by an *additional* `1/sqrt(3)` (the same sqrt(3)-family anisotropic scale `_ASPECT_SQRT3_PATTERNS` uses elsewhere in this file, here baked into the coordinates directly rather than applied at render time, exactly as `tumbling_cubes`' `_TC_V` and `floret_pentagonal`'s own pentagons already do).

**Verified exactly in closed form** (`sympy`): `T(G1) = T(1+sqrt(3), 0) = (1, 0)` exactly; `T(G2) = T((1+sqrt(3))/2, (1+sqrt(3))*sqrt(3)/2) = (1/2, 1/2)` exactly. `T` is a pure "rotate (trivially, by 0 degrees), then scale two axes independently" map -- no shear.

Applying `T` to the 6 kites of `H0`'s own rosette (each kite's face centroids computed exactly in the pre-transform system, then transformed) gives 6 exact-**rational** kites -- **no `sqrt(3)` survives** in the final coordinates (verified with `sympy`, then cross-checked against an independent floating-point pipeline):

```
_DT_K0 = [[0,0], [1/4,1/4], [0,1/3], [-1/4,1/4]]
_DT_K1 = [[0,0], [-1/4,1/4], [-1/2,1/6], [-1/2,0]]
_DT_K2 = [[0,0], [-1/2,0], [-1/2,-1/6], [-1/4,-1/4]]
_DT_K3 = [[0,0], [-1/4,-1/4], [0,-1/3], [1/4,-1/4]]
_DT_K4 = [[0,0], [1/4,-1/4], [1/2,-1/6], [1/2,0]]
_DT_K5 = [[0,0], [1/2,0], [1/2,1/6], [1/4,1/4]]
```

Each vertex list is `[hub (hexagon centroid, shared by all 6), side1 (a square centroid), tip (a triangle centroid), side2 (a different square centroid)]`. **Verified exactly** (`sympy` shoelace and cross-checked with OpenSCAD `polygon_area()`): each of the 6 has area **exactly `1/12`** (6 * 1/12 = 1/2 = the transformed primitive cell area `|T(G1) x T(G2)| = 1*0.5 - 0*0.5 = 1/2`, matching Step 3's area-ratio prediction), each is **convex**, and each is wound **CCW** (a pure rotation + *positive* anisotropic scale preserves orientation, so winding is unchanged from Step 2's pre-transform CCW result). Edge lengths for `_DT_K0`: hub-to-side1 `sqrt(2)/4 ~ 0.3536`, side1-to-tip `sqrt(10)/12 ~ 0.2635`, tip-to-side2 `sqrt(10)/12` (by the kite's own mirror symmetry), side2-to-hub `sqrt(2)/4` -- two distinct lengths, ratio `~1.342`, confirming (again, post-transform) a genuine kite, not a rhombus.

`_DT_K1`..`_DT_K5` are each `_DT_K0` rotated by `60*k` degrees about the hub in the **pre-transform** coordinate system (an expected consequence of the hexagon's own 6-fold rotational symmetry, carried through the fan/dual construction), but are listed as independent literals below rather than derived by an in-code rotation, matching this project's existing convention (`cairo_pentagonal`/`floret_pentagonal` list all their base shapes as independent literals too, even when related by symmetry in the pre-transform space).

### Step 5: covering the unit tile -- which translated copies are needed

Analogous to `floret_pentagonal`'s 18-placement search and `cairo_pentagonal`'s 8-placement search, but here searching individual kites directly (not grouped by hub) over the true hexagon-center lattice `{m*(1,0) + n*(1/2,1/2) : m,n integer}` (**not** an independent-per-axis grid of candidate hub positions -- an earlier, wrong search using `{0, 1/2, 1, -1/2, 3/2}` independently in x and y found spurious extra overlapping placements at non-lattice points like `(1/2, 0)`, which are not real hexagon centers of this lattice; restricting to the true `m*(1,0)+n*(1/2,1/2)` lattice fixed this).

**Exhaustively searched (Python/shapely with exact `Fraction`-based Sutherland-Hodgman clipping, cross-checked): every hexagon center within lattice steps `m,n` in `[-3,3]` (49 candidate hex centers, 294 candidate kites total) was clipped against `[0,1] x [0,1]`; **exactly 14** placements have nonzero clipped area, and their clipped areas sum to **exactly `1`** (verified with exact `Fraction` arithmetic, no floating-point tolerance)**:

```
(dx, dy, k)     clipped area (exact fraction)
(0,   1, 3)     1/24
(0,   1, 4)     1/12
(0,   0, 0)     1/24
(0,   0, 5)     1/12
(1/2, 1/2, 0)   1/12
(1/2, 1/2, 1)   1/12
(1/2, 1/2, 2)   1/12
(1/2, 1/2, 3)   1/12
(1/2, 1/2, 4)   1/12
(1/2, 1/2, 5)   1/12
(1,   1, 2)     1/12
(1,   1, 3)     1/24
(1,   0, 0)     1/24
(1,   0, 1)     1/12
```

(4 corner-hex placements, each contributing a small `1/24` corner sliver plus a `1/12` half-kite; the center hex at `(1/2,1/2)` contributes all 6 of its own kites wholly inside the unit square, `6 * 1/12 = 1/2`; total `4*(1/24) + 4*(1/12) + 6*(1/12) = 1/6 + 1/3 + 1/2 = 1` exactly.) The union of the 14 clipped pieces equals the unit square **exactly** (symmetric difference area `0`, checked with `shapely` and cross-checked with the exact-`Fraction` clip), forms a **single connected polygon** with **zero interior holes**, and has **zero pairwise overlap** among the 14 pieces (all `C(14,2)=91` pairs checked directly).

**Twin-vertex-on-opposite-edges invariant, checked directly with exact `Fraction` coordinates (no floating-point tolerance):**

```
x=0 and x=1 edges: both {0, 1/3, 1/2, 2/3, 1}   (5 points each, exact match)
y=0 and y=1 edges: both {0, 1/2, 1}              (3 points each, exact match)
```

(Identical to `floret_pentagonal`'s own invariant sets -- expected, since both patterns share the same underlying triangular lattice normalization, even though they come from different primal tilings.)

**Wider-patch confirmation (4x4 tile patch, per-cell clipping):** placing the same 14 kites at every integer `(i,j)` offset for `i,j` in `[0,4)`, clipping each translated kite to its own unit cell, and unioning all resulting pieces: total area **`16.0`** (matching `4*4`, float precision `1.999999999999998` rounding artifact only from `shapely`'s float geometry engine, not from the underlying exact construction), a **single connected polygon**, **zero interior holes**, and **zero pairwise overlap** across all `24976` checked pairs.

### Step 6: OpenSCAD/BOSL2 verification (not just Python)

Verified directly with a throwaway OpenSCAD script that includes the real `modules/decoration.scad`, defines `_DT_K0`..`_DT_K5`/`_DT_PLACEMENTS` exactly as in Steps 4-5 above, builds the islands list with `offset(poly, delta=-_DT_GAP/2, closed=true)` (gap `0.05`) feeding the real, unmodified `_tile_from_islands()`, and asserts on the result (`openscad -o /tmp/dt_smoke.stl <script>`):

- `polygon_area(_DT_K{k}, signed=true)` for `k=0..5`: all exactly `0.0833333` (`1/12`, positive/CCW, matching Step 4's prediction).
- `_tile_from_islands(islands)` (the real function, unmodified) produced `is_vnf(tex) == true`.
- `pointlist_bounds(tex[0])` = exactly `[[0,0,0],[1,1,1]]`.
- The twin-vertex check (`_tile_edge_profile()` helper, copied from `tests/test_decoration_floret_pentagonal.scad`) gave **identical** point lists for the `x=0`/`x=1` edges (10 points each, post-groove-offset) and for the `y=0`/`y=1` edges (2 points each), exact match both times, on the real VNF this function actually produces.
- A full real-render smoke test: `cyl(h=100, r1=75, r2=60, $fn=50, texture=tex, tex_reps=[16,8], tex_depth=1.5, tex_inset=false)` differenced against a disjoint cube (forcing real CGAL Nef-polyhedron evaluation): built as a **valid manifold** (`Simple: yes`, `Volumes: 2`), and **no CGAL assertion error appeared in the console output**.
- A follow-up sweep of 10 `pattern_repeat`/`smoothness` combinations on the same bare-cylinder construction -- `(pattern_repeat, smoothness)` in `{(4,24), (12,24), (16,60), (16,100), (3,24), (5,24), (10,24), (11,24), (8,50), (20,50)}` -- against the same disjoint-cube `difference()`: **all 10 rendered clean, zero CGAL assertion errors**, including at settings matching the shipped defaults (`pattern_repeat=16`, `smoothness=60`) and well above them (`smoothness=100`). This is a smaller and less exhaustive sweep than Task 1's own CGAL-sweep step must run (10 points, one relief mode only since there is only one mode, one geometry only -- a bare cylinder, not the full planter assembly), but it is direct, real evidence, not an assumption, and it disagrees with what every other large-flat-plateau pattern in this file measured in its own equivalent early smoke test.

### Relief Mode Decision

**Recommendation: mode-INDEPENDENT, uniform-height geometry -- every kite raised to the same height `1.0`, no `relief_mode` parameter, matching `rhombille`/`cairo_pentagonal`'s signature, not the "kis" family's/`floret_pentagonal`'s `_foo_tile(relief_mode)` shape.**

Reasoning, following the exact decision framework `cairo_pentagonal`'s and `floret_pentagonal`'s own plans used: the "kis" family's raised/etched split exists because each of *their* tile cells is itself a multi-triangle fan (a kis-operation result) with an obvious, single, unambiguous sub-structure to vary height across. `floret_pentagonal` earned the same split because its pentagons group into **one** kind of fan -- a 6-pentagon rosette around a single shared hub -- with no competing fan structure to conflict with an alternation choice.

`deltoidal_trihexagonal`'s situation is different from both, and different from `cairo_pentagonal`/`rhombille` too, in a way worth stating precisely: a single kite is one flat convex quadrilateral face with no sub-fan **within itself** (like Cairo/rhombille, and unlike the "kis" family's/floret's fans-of-smaller-pieces) -- but unlike Cairo/rhombille, this tiling's kites do cluster into fans around shared points, in fact **three different kinds of fan simultaneously** (Step 2 above): a 6-fan around each hexagon centroid, a 4-fan around each square centroid, and a 3-fan around each triangle centroid, with every individual kite belonging to exactly one of the first, one of the third, and touching two different instances of the second. Picking any *one* of these three fan types to alternate heights around (e.g. "alternate high/low by position within the 6-fan, like `floret_pentagonal`'s rosette") would leave the *other two* fan types (the 3-fan and the two 4-fans every kite also touches) with an arbitrary, non-alternating, visually inconsistent height pattern of their own -- since a single global 2-coloring cannot simultaneously alternate cleanly around a 6-cycle, a 4-cycle, and a 3-cycle all at once (a 3-cycle in particular cannot be properly 2-colored at all, the same combinatorial fact `triakis_triangular`'s own plan used to justify 3 *distinct* heights instead of a clean 2-height alternation for its own odd 3-fan). Rather than pick one fan type arbitrarily (which would look like an unmotivated, asymmetric choice given the tiling's genuine 3-way local symmetry) or attempt some more complex multi-way height scheme with no precedent in this file, the recommendation follows Cairo/rhombille's own precedent: **uniform height**, reading as "a clean kite mosaic with incised grooves" rather than an alternating bump pattern. This is a **more conservative** choice than `floret_pentagonal`'s, made because the underlying combinatorics here genuinely differ (three competing fan structures, not one clean one), not because this pattern was assumed by default to behave like Cairo/rhombille without checking -- the fan structure was worked out explicitly (Step 2) specifically to make this call correctly rather than by analogy.

**Forward-compatibility note (the un-implemented `relief-mode-redesign` spec):** `docs/superpowers/specs/2026-09-20-relief-mode-redesign-design.md` (unmerged, docs-only) proposes a future `_tile_outline_from_islands()` (a true engrave-the-outline "etched" mode for every pattern) and a `_tile_alternating_from_islands()` helper. This plan's own `islands` list (Task 1's `_deltoidal_trihexagonal_tile()`) is built the same way `cairo_pentagonal`/`rhombille`/`floret_pentagonal`'s own islands lists are -- one `[region, height]` entry per placed, gap-shrunk kite, indexed by `_DT_PLACEMENTS` -- so it should compose cleanly with a future `_tile_outline_from_islands()` call (which would just need the same islands list, not a redesigned one). It would **not**, on its own, need `_tile_alternating_from_islands()` (since this pattern has no relief_mode-alternation to begin with, per the decision above), but if that future redesign ever wants to offer an *optional* alternating look for patterns that don't currently have one, `_DT_PLACEMENTS`' own `k` index (`0..5`, the kite's orientation within its parent hexagon's rosette) is available as a ready-made 6-way key, the same way `floret_pentagonal`'s own `k` index already is. This is a forward-compatibility observation only -- nothing in this plan depends on, or implements, that spec.

## Task 1: `_deltoidal_trihexagonal_tile()` -- geometry, wiring, tests, docs

**Files:**
- Modify: `modules/decoration.scad` (add `_DT_K0`..`_DT_K5`, `_DT_PLACEMENTS`, `_DT_GAP`, `_DT_Z`, `_dt_kite()`, `_deltoidal_trihexagonal_tile()`; extend `PATTERN_TYPES`; extend `_decoration_texture()`; extend `VNF_PATTERN_TYPES`-equivalent list where applicable)
- Create: `tests/test_decoration_deltoidal_trihexagonal.scad`
- Modify: `tests/test_decoration_pattern_types.scad` (extend `EXPECTED_PATTERN_TYPES` and `EXPECTED_VNF_PATTERN_TYPES`)
- Modify: `tests/test_decoration_etched_groove.scad` (add `"deltoidal_trihexagonal"` to `VNF_PATTERN_TYPES` -- read the file fresh to confirm its exact current shape before editing)
- Modify: `tests/test_decoration_tile_aspect.scad` (extend the plain-formula VNF-tile `for` loop's pattern list)
- Modify: `.github/workflows/test.yml` (add `"deltoidal_trihexagonal"` to every pattern-type loop; add a CGAL-sweep entry per the Global Constraints CGAL-fragility note above; re-pin defaults only if the sweep finds a real problem)
- Modify: `planter.scad` (Customizer dropdown comment for `pattern_type`, line 48 as of this plan)
- Modify: `README.md` (parameter table, interlocking-patterns enumeration if applicable -- see Step 4 below for whether this pattern's motif crosses the tile boundary, CGAL section)
- Modify: `docs/gallery.md` (new subsection + regenerated images via `docs/images/render.sh`)
- Modify: `TODO.md` (check off the Deltoidal trihexagonal line)

**Interfaces:**
- Consumes: `_tile_from_islands(islands)`, `_UNIT_TILE` -- both existing, defined in `modules/decoration.scad`'s "Shared plateau-tile builder" section.
- Produces: `_deltoidal_trihexagonal_tile()` (no arguments, matching `_rhombille_tile()`/`_cairo_pentagonal_tile()`'s shape -- per the Relief Mode Decision above). `_decoration_texture(pattern_type, relief_mode)` gains one more branch: `pattern_type == "deltoidal_trihexagonal" ? _deltoidal_trihexagonal_tile() :`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_decoration_deltoidal_trihexagonal.scad`, following `tests/test_decoration_cairo_pentagonal.scad`'s/`tests/test_decoration_rhombille.scad`'s structure exactly (uniform-height, mode-independent -- **not** the "kis"-family/`floret_pentagonal` raised-vs-etched structure, since this pattern's raised and etched tiles are the SAME VNF):

```openscad
// tests/test_decoration_deltoidal_trihexagonal.scad
//
// "deltoidal_trihexagonal" is a custom VNF tile (the deltoidal trihexagonal
// tiling, Wikipedia "V3.4.6.4" -- congruent kite/deltoid quadrilaterals, the
// dual of the rhombitrihexagonal tiling), not a BOSL2 texture name, so it
// needs a real-render check: a tile whose points leave the unit square,
// whose edges don't line up across the tile boundary, or whose walls are
// wound backwards only fails when the geometry is actually evaluated.
//
// Like cairo_pentagonal/rhombille (and unlike floret_pentagonal/the "kis"
// family), this pattern's raised and etched tiles are the SAME VNF -- every
// kite is raised to the same uniform height regardless of relief_mode. See
// this pattern's plan document's "Relief Mode Decision" for why: a single
// kite has no sub-fan of its own, and the tiling's kites belong to THREE
// different, competing fan types (6-fan/4-fan/3-fan) simultaneously, so no
// single alternation scheme applies without an arbitrary choice.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("deltoidal_trihexagonal", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"deltoidal_trihexagonal\"");

_tex_raised = _decoration_texture("deltoidal_trihexagonal", "raised");
_tex_etched = _decoration_texture("deltoidal_trihexagonal", "etched");
assert(is_list(_tex_raised) && len(_tex_raised) == 2,
    "_decoration_texture(\"deltoidal_trihexagonal\", \"raised\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex_raised), "_decoration_texture(\"deltoidal_trihexagonal\", \"raised\") must be a valid VNF");
assert(is_vnf(_tex_etched), "_decoration_texture(\"deltoidal_trihexagonal\", \"etched\") must be a valid VNF");

// Raised and etched must be the SAME VNF here -- like cairo_pentagonal/
// rhombille, unlike the "kis" family/floret_pentagonal: this pattern's
// geometry does not branch on relief_mode at all.
assert(_tex_raised == _tex_etched,
    "deltoidal_trihexagonal's raised and etched tiles must be identical -- this pattern's geometry does not depend on relief_mode, unlike the \"kis\" family/floret_pentagonal");

// A VNF texture tile's footprint must lie inside the unit square with Z in
// [0,1]; BOSL2 rejects anything else at render time.
_bounds = pointlist_bounds(_tex_raised[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("deltoidal_trihexagonal tile must fit in the unit cube, got bounds ", _bounds));
assert(approx(_bounds[0][0], 0) && approx(_bounds[0][1], 0) &&
       approx(_bounds[1][0], 1) && approx(_bounds[1][1], 1),
    str("deltoidal_trihexagonal tile should reach every edge of the unit square exactly, got bounds ", _bounds));

// VNF tiles take no `style` (that's a heightfield-triangulation setting), and
// _decoration_style() must reach that answer from the resolved texture rather
// than from a pattern_type-specific branch.
assert(_decoration_style("deltoidal_trihexagonal", "raised") == undef,
    "deltoidal_trihexagonal is a VNF tile and must not carry a style override");
assert(_decoration_style("deltoidal_trihexagonal", "etched") == undef,
    "deltoidal_trihexagonal is a VNF tile and must not carry a style override when etched");

// Every kite reaches the tile's full height (this pattern's own uniform-
// height constant, distinct from every other pattern's own Z constant even
// where the numeric value happens to match).
assert(_DT_Z == 1, str("deltoidal_trihexagonal's uniform kite height must be 1, got ", _DT_Z));
_zs = unique([for (p = _tex_raised[0]) p[2]]);
assert(_zs == [0, 1],
    str("deltoidal_trihexagonal VNF must use exactly 2 Z levels (ground, uniform full height), got ", _zs));

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
    lo = _tile_edge_profile(_tex_raised, axis, 0);
    hi = _tile_edge_profile(_tex_raised, axis, 1);
    name = (axis == 0) ? "x" : "y";
    // The shipped VNF (post-_DT_GAP groove shrink) has 10 points on the
    // x=0/x=1 edges and 2 points on the y=0/y=1 edges -- see the plan's
    // Geometry Derivation, Step 6. (Step 5 found 5/3 for the PRE-groove
    // polygon corners -- a different, smaller count that does not apply to
    // this post-offset() VNF.) Either way, more than 2 is what proves a kite
    // genuinely spans the seam, not just touches at a corner -- except for
    // the y-axis, where this tiling's own geometry only ever has kites
    // touching the y=0/y=1 seam at 2 points (verify this is what the real
    // VNF produces, don't assume len>2 unconditionally on both axes).
    assert(len(lo) == len(hi),
        str("deltoidal_trihexagonal tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("deltoidal_trihexagonal tile ", name, " edge vertices don't line up: ", mismatched));
}

difference() {
    decorated_solid("deltoidal_trihexagonal", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}

difference() {
    decorated_solid("deltoidal_trihexagonal", "vertical", "etched", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
openscad -o /tmp/test.csg tests/test_decoration_deltoidal_trihexagonal.scad
```
Expected: FAIL -- `"deltoidal_trihexagonal"` is not yet in `PATTERN_TYPES` (ERROR: Assertion failed at the `in_list` check).

- [ ] **Step 3: Add the tile geometry to `modules/decoration.scad`**

Insert a new section immediately after the existing `_floret_pentagonal_tile()` function (right before the `"--- Kisrhombille"` comment block), so the two most recently added tiles sit next to each other in file order:

```openscad
// --- Deltoidal trihexagonal (dual of the rhombitrihexagonal tiling) --------
//
// Wikipedia "V3.4.6.4": a tessellation by congruent kite/deltoid
// quadrilaterals -- 2 short edges and 2 long edges (verified: edge-length
// ratio is not 1, so this is a genuine kite, not a rhombus), with a line of
// symmetry through its two "pointy" vertices (the hexagon-centroid hub and
// the triangle-centroid tip). See this pattern's plan document
// (docs/superpowers/plans/2026-09-20-deltoidal-trihexagonal-pattern.md) for
// the full derivation and the computational verification this construction
// is based on (a from-scratch rhombitrihexagonal-tiling construction
// verified over a 34-vertex core patch, its face-centroid dual verified via
// exact-Fraction area/closure/overlap checks including a wider 4x4-tile-patch
// confirmation, plus a live OpenSCAD/BOSL2 smoke test of this exact code
// path) -- do not re-derive the lattice by hand; it was verified, not
// guessed.
//
// The hexagon-vertex lattice underlying this tiling is a plain 60-degree
// TRIANGULAR lattice (two generators, equal length 1+sqrt(3), 60 degrees
// apart) -- the SAME shape of lattice tumbling_cubes/rhombille/kisrhombille/
// floret_pentagonal already use for their own hexagon-related centers, which
// is why this pattern needs no shear and no new aspect-correction mechanism:
// like tumbling_cubes' _TC_V, the rotation (here, trivially 0 degrees --
// this tiling's own G1 generator was chosen along the x-axis from the start)
// + sqrt(3)-family anisotropic scale that normalizes this lattice to
// _UNIT_TILE space is baked directly into the kite vertex coordinates below,
// not applied at render time. NOTE: this is NOT the same primal tiling
// tumbling_cubes/rhombille's own hexagon lattice (_TC_V/_TC_CENTERS) comes
// from -- that lattice is a plain edge-to-edge hexagonal tiling with no
// triangles or squares (checked directly and confirmed not reusable; see
// this pattern's plan document's "What 'rectangular lattice' means here"
// section), so _DT_K0.._DT_K5 below are this pattern's own independent
// derivation, not a reuse of _TC_V.
//
// _DT_K0.._DT_K5 are the tiling's 6 kite orientations (the full rosette
// around one hexagon-centroid hub), already normalized into unit-tile
// space, each listed as [hub, side1, tip, side2] (hub = hexagon centroid,
// shared by all 6; side1/side2 = two different square centroids; tip = a
// triangle centroid). All 6 have area exactly 1/12, are convex, and wind
// CCW.
_DT_K0 = [[0,0], [1/4,1/4], [0,1/3], [-1/4,1/4]];
_DT_K1 = [[0,0], [-1/4,1/4], [-1/2,1/6], [-1/2,0]];
_DT_K2 = [[0,0], [-1/2,0], [-1/2,-1/6], [-1/4,-1/4]];
_DT_K3 = [[0,0], [-1/4,-1/4], [0,-1/3], [1/4,-1/4]];
_DT_K4 = [[0,0], [1/4,-1/4], [1/2,-1/6], [1/2,0]];
_DT_K5 = [[0,0], [1/2,0], [1/2,1/6], [1/4,1/4]];
_DT_KITES = [_DT_K0, _DT_K1, _DT_K2, _DT_K3, _DT_K4, _DT_K5];

// Which (hub, orientation) copies have any overlap with the unit square --
// exhaustively searched over the true hexagon-center lattice
// {m*(1,0) + n*(1/2,1/2) : m,n integer} (NOT an independent-per-axis grid --
// see the plan's Geometry Derivation, Step 5, for the wrong search that found
// spurious extra placements at non-lattice points before this was fixed).
// Each entry is [hub_x, hub_y, k]: kite _DT_KITES[k] translated so its hub
// sits at (hub_x, hub_y). Exactly these 14 placements' clipped areas sum to
// exactly 1 (verified with exact Fraction arithmetic), and their union was
// verified to equal the unit square exactly, with zero overlap among them.
_DT_PLACEMENTS = [
    [0, 1, 3], [0, 1, 4],
    [0, 0, 0], [0, 0, 5],
    [1/2, 1/2, 0], [1/2, 1/2, 1], [1/2, 1/2, 2],
    [1/2, 1/2, 3], [1/2, 1/2, 4], [1/2, 1/2, 5],
    [1, 1, 2], [1, 1, 3],
    [1, 0, 0], [1, 0, 1],
];

function _dt_kite(m, n, k) = [for (p = _DT_KITES[k]) [p[0] + m, p[1] + n]];

_DT_GAP = 0.05; // engraved groove width, in tile fractions -- own constant,
                // same scale as _KIS_GAP/_TC_GAP/_RH_GAP/_CP_GAP/_FP_GAP but
                // never shared with them
_DT_Z   = 1.0;  // every kite reaches the tile's full height (uniform, like
                // rhombille/cairo_pentagonal -- see this pattern's plan
                // document's "Relief Mode Decision" for why: unlike
                // floret_pentagonal's single clean rosette fan, this
                // tiling's kites belong to THREE competing fan types
                // (6-fan/4-fan/3-fan) at once, so no single alternation
                // scheme applies without an arbitrary choice)

function _deltoidal_trihexagonal_tile() =
    _tile_from_islands([
        for (pl = _DT_PLACEMENTS)
            let (poly = _dt_kite(pl[0], pl[1], pl[2]),
                 r = offset(poly, delta = -_DT_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _DT_Z]
    ]);
```

- [ ] **Step 4: Wire it into `PATTERN_TYPES` and `_decoration_texture()`**

In `PATTERN_TYPES`, append `"deltoidal_trihexagonal"` after `"floret_pentagonal"`:

```openscad
PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                 "bricks", "checkers", "dots", "cubes", "tri_grid",
                 "teardrop", "tumbling_cubes", "intertwine", "islamic_star",
                 "tetrakis_square", "kisrhombille", "triakis_triangular",
                 "rhombille", "cairo_pentagonal", "floret_pentagonal",
                 "deltoidal_trihexagonal"];
```

Update the file's opening comment block above `PATTERN_TYPES` (currently documents "the ten custom VNF tiles") to say "the eleven custom VNF tiles" and add `deltoidal_trihexagonal` to the named list. Before wording the "interlocking patterns" sentence, confirm directly whether this pattern's own kites cross the tile seam (check `_DT_PLACEMENTS` above: yes -- several placements, e.g. `[0,0,0]` and `[1,0,0]`, clip to a small `1/24` sliver, which only happens when a kite's own footprint straddles the boundary and gets cut by it) -- so it is an **eighth** interlocking pattern joining `"teardrop"`/`"tumbling_cubes"`/`"intertwine"`/`"islamic_star"`/`"rhombille"`/`"cairo_pentagonal"`/`"floret_pentagonal"`, but (per the Relief Mode Decision) does **not** join the `relief_mode`-dependent group `floret_pentagonal`/the "kis" family belong to -- word the comment precisely rather than assuming it must join both groups the way `floret_pentagonal` did.

In `_decoration_texture()`, add one more branch, right after the `floret_pentagonal` line:

```openscad
    pattern_type == "cairo_pentagonal"   ? _cairo_pentagonal_tile() :
    pattern_type == "floret_pentagonal"  ? _floret_pentagonal_tile(relief_mode) :
    pattern_type == "deltoidal_trihexagonal" ? _deltoidal_trihexagonal_tile() :
    pattern_type;
```

- [ ] **Step 5: Add the CGAL-fragility warning per the Global Constraints bucket decision**

Add `"deltoidal_trihexagonal"` to the **"measured clean everywhere" precautionary** bucket in `decorated_solid()`'s CGAL warning `echo()` (the `else if` branch currently listing `"tetrakis_square", "kisrhombille", "triakis_triangular", "floret_pentagonal"`... **confirm this exact list fresh when editing** -- read the file as it stands after `floret_pentagonal`'s own PR merged, since that pattern's own bucket placement may itself have changed if its own sweep found real failures after this plan was written), **not** the "known to abort" bucket, per the Global Constraints CGAL-fragility note above -- but only after Task 1's own sweep (Step 9 below) confirms this placement; if that sweep finds a real abort anywhere in a reasonable range, move it to the "known to abort" bucket instead and update this step's own wording, exactly the way `cairo_pentagonal`'s plan started mild and its own implementation later found real failures requiring a bucket move.

- [ ] **Step 6: Extend `tests/test_decoration_pattern_types.scad`**

Add `"deltoidal_trihexagonal"` to `EXPECTED_PATTERN_TYPES` (after `"floret_pentagonal"`) and to `EXPECTED_VNF_PATTERN_TYPES` (this pattern resolves to a hand-rolled VNF tile just like the other ten). Update the comment above `EXPECTED_VNF_PATTERN_TYPES` to describe it as an eleventh VNF pattern on the same terms as `rhombille`/`cairo_pentagonal` (uniform height, no relief_mode branch) -- not on `floret_pentagonal`'s terms.

- [ ] **Step 7: Extend `tests/test_decoration_etched_groove.scad`**

Read the file fresh to confirm its current `VNF_PATTERN_TYPES`/`KIS_PATTERN_TYPES` lists (as of this plan: `VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine", "islamic_star", "rhombille", "cairo_pentagonal"]`, `KIS_PATTERN_TYPES = ["tetrakis_square", "kisrhombille", "triakis_triangular", "floret_pentagonal"]`). Add `"deltoidal_trihexagonal"` to `VNF_PATTERN_TYPES` (its raised/etched tiles are identical, per the Relief Mode Decision) -- **not** to `KIS_PATTERN_TYPES`.

- [ ] **Step 8: Extend `tests/test_decoration_tile_aspect.scad`**

Add `"deltoidal_trihexagonal"` to the `for (pt = [...])` loop's pattern list (the plain-square-tile-formula check every other custom VNF tile already uses).

- [ ] **Step 9: CGAL sweep**

Following `cairo_pentagonal`'s/`floret_pentagonal`'s own Task-1 CGAL-sweep methodology: build `tests/test_planter_integration.scad` (or an equivalent full-assembly script) with `pattern_type="deltoidal_trihexagonal"` across a `pattern_repeat` range (at minimum 3 through 16, plus the shipped default 16) crossed with `smoothness` in `{24, 40, 60, 80, 100}`, in both `relief_mode`s (even though the geometry is identical between modes, `decorated_solid()`'s `tex_inset`/`tex_depth` handling still differs, so both must be checked), looking for `CGAL error` in the console output of a real `difference()`-forcing render (an actual `openscad -o foo.stl` invocation of the assembly, not `.csg`). Record every abort/clean result the same way `README.md`'s existing CGAL section records them for `cairo_pentagonal`/`floret_pentagonal`. This plan's own Geometry Derivation Step 6 already found a smaller 10-point bare-cylinder sweep entirely clean, but that is not equivalent to sweeping the real assembly, and per the Global Constraints CGAL note above, this step must not skip re-measuring on the strength of that alone. If any combination in the tested range aborts, update Step 5 above to place this pattern in the "known to abort" bucket instead, and pick a CI-pinned reduced value the same way `cairo_pentagonal`/`floret_pentagonal`/`intertwine` did (a value with a tested-clean margin on both sides, not an isolated clean value). **Additionally**, per the explicit task requirement: get at least one confirmation of the chosen CI-pinned combination against a real GitHub Actions Ubuntu run (push a branch, watch the workflow run, or ask for a maintainer to do so) before treating any bucket placement here as final -- do not ship this pattern's CI wiring on local-macOS measurement alone, per the `intertwine`/`cairo_pentagonal`/`floret_pentagonal` precedent of local-clean not implying CI-clean.

- [ ] **Step 10: Wire into `.github/workflows/test.yml`**

Add `"deltoidal_trihexagonal"` to:
- The `for f in teardrop tumbling_cubes ...` per-tile-test loop (around line 74-76 as of this plan) -- add `tests/test_decoration_deltoidal_trihexagonal.scad` to that list.
- The `for pt in none ridges ... floret_pentagonal` single-pattern-build loops (around lines 97 and 512 as of this plan).
- The `run_assembly_combo` loop (around line 329-338 as of this plan): add an entry with a CI-safe reduced `pattern_repeat` value chosen from Step 9's sweep results (following the "clean value with a tested margin on both sides" convention every other entry there uses -- do not pick an isolated clean value).
- If Step 9's sweep confirms the shipped defaults (`pattern_repeat=16`, `smoothness=60`) are clean in both relief modes, add a defaults-pinning entry (around line 394-400 as of this plan) alongside `islamic_star`/`tumbling_cubes`/`rhombille`/`cairo_pentagonal`/`floret_pentagonal`; if not, do not pin the defaults and instead flag this in `README.md`'s CGAL section as an open risk, the way this plan's own Global Constraints section already anticipates might be necessary.

- [ ] **Step 11: Update `planter.scad`'s Customizer dropdown comment**

Append `"deltoidal_trihexagonal"` to the bracketed list on the `pattern_type` line (line 48 as of this plan):

```openscad
pattern_type = "ridges";           // ["none", "ridges", "diamonds", "hex_grid", "pyramids", "bricks", "checkers", "dots", "cubes", "tri_grid", "teardrop", "tumbling_cubes", "intertwine", "islamic_star", "tetrakis_square", "kisrhombille", "triakis_triangular", "rhombille", "cairo_pentagonal", "floret_pentagonal", "deltoidal_trihexagonal"]
```

- [ ] **Step 12: Update `README.md`**

- Add `"deltoidal_trihexagonal"` to the `pattern_type` parameter table's value list (line 77 as of this plan).
- Add it to the "interlocking patterns" enumeration (currently naming seven patterns including `"floret_pentagonal"`) as an eighth, per Step 4's confirmation that its motif crosses the tile seam.
- Add a CGAL-fragility paragraph following the exact style of the `cairo_pentagonal`/`floret_pentagonal` paragraphs, reporting Step 9's real sweep results (not this plan's own smaller bare-cylinder sweep) -- state plainly which bucket it landed in and why, including the "not yet CI-verified" caveat if Step 9's CI confirmation (the second half of that step) has not yet completed at the time this section is written.
- Note in the union-with-another-textured-solid paragraph (the one currently covering `"teardrop"`/`"intertwine"`/`"tumbling_cubes"`/`"islamic_star"`/`"rhombille"`/`"cairo_pentagonal"`/`"floret_pentagonal"`) whether `"deltoidal_trihexagonal"` unions cleanly or not -- this requires its own measurement (a union of a `"deltoidal_trihexagonal"` solid with a `"dots"` solid, differenced against a disjoint cube, the same check every other pattern in that paragraph got), not an assumption from the difference-only smoke test in Step 6 above.

- [ ] **Step 13: Update `docs/gallery.md`**

Add a `### deltoidal_trihexagonal` subsection following the exact structure of the `### cairo_pentagonal`/`### rhombille` subsections (a Raised/Etched image pair even though the VNF is identical, for table-layout consistency with every other pattern's subsection, plus a short descriptive paragraph naming the tiling, its Wikipedia vertex configuration, and confirming -- like the `cairo_pentagonal`/`rhombille` paragraphs do -- that `"etched"` here is a true inverted copy of the raised relief, not a separate flat-panel construction like the "kis" family/`floret_pentagonal`). Add the corresponding Table-of-Contents entry. Regenerate the two example images via `docs/images/render.sh` (confirm that script's own pattern list needs the new entry too -- check it fresh, it was not enumerated in this plan's own research and may need its own edit).

- [ ] **Step 14: Check off `TODO.md`**

Change the `- [ ] Deltoidal trihexagonal tiling ("V3.4.6.4", kite-shaped motif) -- batch 3` line to `- [x] ...`. This is the last remaining item in the tessellation backlog's dual-tiling list (Prismatic pentagonal was declined and stays unchecked with its own note), so also check whether the surrounding backlog bullet (`"More interlocking geometric pattern ideas..."`) should be marked fully done or left open -- read `TODO.md` fresh, since other unrelated items may still be pending under the same top-level bullet.

- [ ] **Step 15: Run the full test suite locally**

```bash
openscad -o /tmp/test.csg tests/test_decoration_deltoidal_trihexagonal.scad
openscad -o /tmp/test.csg tests/test_decoration_pattern_types.scad
openscad -o /tmp/test.csg tests/test_decoration_etched_groove.scad
openscad -o /tmp/test.csg tests/test_decoration_tile_aspect.scad
```
Expected: all four clean (exit 0, no `ERROR`/`CGAL error` in output). Then run the CGAL-sweep script from Step 9 and confirm its results match what got written into `README.md`/`.github/workflows/test.yml`.
