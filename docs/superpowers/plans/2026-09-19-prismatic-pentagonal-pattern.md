# Prismatic Pentagonal Tiling Pattern Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `"prismatic_pentagonal"` as a new `pattern_type` -- the prismatic pentagonal tiling (Wikipedia "V3³.4²", dual of the elongated triangular tiling), a tessellation by congruent, irregular convex pentagons (2 short edges, 3 long edges, two adjacent 90° angles and three 120° angles). Every pentagon sits at the same, uniform height (like `rhombille`/`cairo_pentagonal`), so it reads as a clean pentagon-mosaic relief/etch.

**Architecture:** One new custom VNF tile function, `_prismatic_pentagonal_tile()`, built the same way `_cairo_pentagonal_tile()`/`_rhombille_tile()` are: a list of `[region, height]` islands (each island a translated copy of one of **2** pre-computed pentagon orientations, shrunk by half the groove width) fed to the existing `_tile_from_islands()` helper. Unlike the "kis" family, this tile's geometry does not depend on `relief_mode`.

Unlike `cairo_pentagonal` (whose normalizing transform was a pure rotation + uniform scale), this pattern's natural translation lattice is an **oblique (non-rectangular) parallelogram** -- a direct consequence of the elongated triangular tiling mixing square rows (edge 1) with equilateral-triangle rows (height `sqrt(3)/2`), exactly the "√3 factor" risk this task's briefing called out in advance. The affine map from this pattern's natural coordinate system to `_UNIT_TILE` space is therefore a genuine **shear + anisotropic (non-uniform) scale**, not a pure rotation like `cairo_pentagonal`'s. This has two consequences spelled out in full in "Geometry Derivation" below:

1. The tile needs its own new aspect-correction category in `_square_tile_vertical_reps()` (constant `(2+sqrt(3))/2`, not `sqrt(3)`) -- `_ASPECT_SQRT3_PATTERNS` cannot be reused as-is because its hardcoded `sqrt(3)` is the wrong ratio for this pattern, so this task **generalizes** that mechanism into a per-pattern aspect-factor lookup rather than adding a fourth pattern name to a list whose constant doesn't fit it.
2. The shear component has **no existing correction mechanism anywhere in this codebase** (the existing sqrt(3) mechanism only ever adjusts a repeat *count*, never a repeat *angle*), and this task does not add one. The pentagon motif will render with a permanent, deliberate diagonal slant baked directly into the tile's own vertex coordinates. This is disclosed as a real, honest visual characteristic of this pattern -- not a defect to silently work around -- the same way this project documents other patterns' quirks (`hex_grid`/`tri_grid`'s aspect correction, `teardrop`'s scalloped end caps).

Both the translation lattice and the affine transform were derived and verified computationally (see "Geometry Derivation" below) -- **do not re-derive this by hand**; an initial by-hand attempt at guessing the lattice generators from the elongated triangular tiling's row structure produced multiple plausible-looking but WRONG candidate lattice vectors that failed a rigorous computational symmetry check (documented below as a cautionary data point, exactly the kind of trap this task's briefing warned about), before the correct generators were found and confirmed.

**Tech Stack:** OpenSCAD 2021.01, BOSL2 (`lib/BOSL2/std.scad`), this repo's existing `modules/decoration.scad` VNF-tile infrastructure (`_tile_from_islands()`, `_UNIT_TILE`), Python 3 + `shapely` 2.1.2 (used only for this plan's own offline verification, not shipped).

**Spec:** No separate spec document -- this plan follows the same shape as `docs/superpowers/plans/2026-09-19-cairo-pentagonal-pattern.md` and `TODO.md`'s tessellation backlog entry for "Prismatic pentagonal tiling ... batch 3". The geometry is derived and verified in this plan's own "Geometry Derivation" section below, starting from Wikipedia's description of the elongated triangular tiling and its dual.

## Global Constraints

- New pattern name: `"prismatic_pentagonal"`, appended to `PATTERN_TYPES` immediately after `"cairo_pentagonal"` (the current last entry) -- matches the file's existing append-at-the-end convention and `TODO.md`'s batch-3 ordering.
- The tile is a VNF (not a BOSL2 texture string), added to `EXPECTED_VNF_PATTERN_TYPES` in `tests/test_decoration_pattern_types.scad`.
- The tile is **not** in `_ASPECT_EXCLUDED_PATTERNS` (it needs the vertical-reps aspect correction, unlike `"none"`/`"ridges"`/`"bricks"`) but it is also **not** simply added to `_ASPECT_SQRT3_PATTERNS` -- see the Architecture section above and "Geometry Derivation"'s "Aspect Correction" subsection: it needs a *different* correction constant, `(2+sqrt(3))/2`, so this task generalizes `_square_tile_vertical_reps()`'s aspect mechanism into a per-pattern factor lookup (`_tile_aspect_factor()`) rather than reusing the sqrt(3)-specific boolean.
- No `style` override: it's a VNF, so `_decoration_style_for()` must return `undef` for it (true automatically, but the task's test must assert this explicitly).
- Every pentagon is raised to the **same** height, `1.0` (the tile's own max), mode-independent -- see "Relief Mode Decision" below. `_prismatic_pentagonal_tile()` therefore takes **no** `relief_mode` parameter, matching `_rhombille_tile()`/`_cairo_pentagonal_tile()`'s signature.
- Use gap `0.05` (own named constant `_PP_GAP`, matching this repo's convention of never sharing another pattern's groove-width constant even at the same numeric value as `_KIS_GAP`/`_RH_GAP`/`_CP_GAP`).
- CGAL-fragility warning: add `"prismatic_pentagonal"` to `decorated_solid()`'s CGAL warning `echo()`, starting in the *milder* "measured clean everywhere" bucket as a hypothesis only (matching how `cairo_pentagonal`'s own Task 1 Step 5 started, per that plan's Global Constraints) -- Task 1's own CGAL-sweep step must independently re-measure across a `pattern_repeat`/`smoothness` grid in both relief modes before this placement is trusted. This tile has 6 flat pentagon islands per unit tile (fewer than `cairo_pentagonal`'s 8, but still large flat plateaus with wide-arc chords, the same failure mechanism as `tumbling_cubes`/`rhombille`/`cairo_pentagonal`) -- do not assume either bucket from the mechanism alone; measure it.
- README.md's `pattern_type` parameter table, the "N of the pattern_type values are interlocking" enumeration (currently names `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`, `"rhombille"`, `"cairo_pentagonal"` explicitly), the CGAL-fragility section, and the aspect-correction discussion (currently only mentions `"cubes"`/`"hex_grid"`/`"tri_grid"`'s sqrt(3) correction) must all be updated by name.
- `docs/gallery.md` needs a new subsection (raised + etched example renders) following the exact structure of the `cairo_pentagonal` subsection, and its Pattern Comparison intro paragraph (which currently says "16 of the 19 patterns" render square and calls out the three sqrt(3)-corrected exceptions) needs updating: with this pattern added there will be 20 total patterns, and a fourth (differently-shaped) aspect exception.
- `.github/workflows/test.yml`'s several pattern-type loops must include `"prismatic_pentagonal"`.
- `planter.scad`'s Customizer dropdown comment for `pattern_type` must be updated too -- a past PR review caught this being forgotten twice already; do not repeat it a third time.
- `tests/test_decoration_etched_groove.scad`'s `VNF_PATTERN_TYPES` list (mode-independent VNF tiles) must gain `"prismatic_pentagonal"`.
- `tests/test_decoration_tile_aspect.scad`'s VNF-tile list currently asserts every custom VNF tile uses the *plain* square-tile formula (`expected_dots`) -- `"prismatic_pentagonal"` must **not** go in that loop (it needs the new aspect-corrected formula instead), and this task must add a *new* assertion block there mirroring the existing `"cubes"`/`"hex_grid"`/`"tri_grid"` sqrt(3) block, but checking the `(2+sqrt(3))/2` factor instead.
- `docs/images/render.sh` reads `PATTERN_TYPES` directly out of `modules/decoration.scad` (see that script's own comment around line 155), so no separate pattern list needs updating there -- adding the name to `PATTERN_TYPES` is sufficient for the gallery-image regeneration script to pick it up automatically.

## Geometry Derivation

This section is the load-bearing evidence for the implementer: exact coordinates, the exact affine transform to `_UNIT_TILE` space, and a description of the two independent verifications run (a Python/shapely closure proof, and a live OpenSCAD/BOSL2 smoke test of the real `_tile_from_islands()` code path) with their results. Task 1 below re-states the final OpenSCAD constants/functions verbatim; this section is where they came from and why they're correct.

### Step 0: what got tried first and failed (the shear trap)

Before any of the verified construction below, this plan's own preparation first tried the "obvious" approach suggested by the task's own hint: build the elongated triangular tiling as literally described (a row of unit squares directly above a row of unit equilateral triangles, `h = sqrt(3)/2` tall, repeating), read off two candidate lattice vectors by inspecting the row structure by eye (`L1 = (1,0)` and `L2 = (0.5, 1+h)`, reasoning that shifting up one row-pair also shifts every other row by half a unit), and initially treated an even-multiple combination, `(0, 2(1+h))`, as if it were automatically a *pure translation* symmetry because it is an integer combination of two vectors that individually tested as pure translations from one single starting vertex.

**This reasoning was wrong, and a rigorous computational check caught it directly:** testing `(0, 2(1+h))` as a pure translation (no rotation) from *every* vertex in a large generated patch (not just one) found it held for only ~81% of tested vertices, not 100% -- meaning it is not actually a lattice translation symmetry of the full tiling by itself. (An even earlier version of this same check had a units bug -- comparing a 6-decimal-rounded coordinate against a 9-decimal-rounded dictionary key -- that produced a spurious ~10% match rate for vectors later proven to be genuine 100% symmetries; that bug was found and fixed before drawing any conclusion, and is recorded here as its own cautionary note: a "low match rate" result is only trustworthy once the comparison tolerance/precision has itself been checked.) This is exactly the kind of dead end the task's briefing warned this pattern could produce despite "looking simpler" than Cairo pentagonal -- the fix, as with Cairo, was to stop guessing lattice vectors from the picture and instead brute-force-verify every candidate against the actual generated vertex/face data.

### Step 1: build and verify the base elongated triangular tiling

Constructed programmatically (not by hand): square rows at `y in [j(1+h), j(1+h)+1]` for integer `j`, each column shifted horizontally by `0.5` on odd `j` (a running-bond offset between successive square rows); triangle rows filling the strip between consecutive square rows, alternating apex-up/apex-down triangles whose two boundary phases match the square row above and below.

**Verified (Python/shapely):** generated a patch of 273 faces (squares + triangles) over `j in [-3,3]`, `k in [-6,6]`; the union of all face polygons has area exactly equal to the sum of the individual face areas (no overlaps), is a single connected `Polygon` (not a `MultiPolygon`), and has zero interior holes. This confirms the base tiling itself (before taking its dual) is a valid, gapless tessellation, before building anything on top of it.

### Step 2: the dual pentagon, built directly from face data (not guessed)

Rather than reasoning out the dual pentagon's shape by hand, it was built mechanically and directly from the verified base tiling: for a given vertex, collect every incident face's centroid, sort those centroids by angle around the vertex, and connect them in that cyclic order -- the standard "face-centroid dual" construction.

**Verified (Python, over a large patch -- 1424 vertices after generating a much bigger base patch, `j in [-14,14]`, `k in [-24,24]`, with a 5-unit-wide margin trimmed off to avoid boundary artifacts):** every single one of the 1424 vertices has degree exactly 5 (confirming the `3.3.3.4.4` vertex figure everywhere, not just near the origin), every one of the 1424 resulting pentagons has area exactly `sqrt(3)/4 + 1/2 = (2+sqrt(3))/4` (matching to 9+ significant figures across all 1424, i.e. exact up to floating-point noise), the union of all 1424 pentagons is a single connected polygon, has zero interior holes, and its area matches the sum of the individual pentagon areas exactly (no gaps, no overlaps). This is the same style of large-patch closure proof `cairo_pentagonal`'s own plan used, scaled up further here specifically because Step 0 above had already produced one false-positive from an under-sized/under-margined patch.

One resulting pentagon, in its own natural (x, y) coordinates (the vertex it surrounds is at the origin):

```
A = ( 1/2,  1/2)
B = (-1/2,  1/2)
C = (-1/2, -h/3)      where h = sqrt(3)/2
D = (   0, -2h/3)
E = ( 1/2, -h/3)
```

Wound CCW, area `sqrt(3)/4 + 1/2`. Edge lengths (exact): `AB = 1`, `BC = EA = 1/2 + sqrt(3)/6`, `CD = DE = sqrt(3)/3`. Interior angles: `90°` at `A` and `B` (adjacent, sharing edge `AB`), `120°` at `C`, `D`, `E`. This pentagon does **not** have the same edge-length ratio as the "canonical" prismatic-pentagonal pentagon quoted by secondary sources (2 short edges of length 1, 3 long edges of length `sqrt(3)`, from a hexagon-bisection construction) -- centroid-based duals of a non-regular-vertex-figure tiling are not guaranteed to reproduce a specific "nice" edge-length ratio, only the correct combinatorial/angular structure, which this one has (matching the `90°,90°,120°,120°,120°` sequence exactly). Since the Python/shapely closure proof in Step 2 already independently confirms this exact pentagon tiles the plane with no gaps, overlaps, or holes, it is used as-is rather than chasing the specific canonical edge ratio.

### Step 3: finding the real translation lattice (the part Step 0 got wrong)

Rather than trust the by-hand `L1=(1,0)`, `L2=(0.5,1+h)` guess from Step 0, both vectors were re-verified directly against the actual pentagon vertex/shape data from Step 2, using a rigorous per-vertex congruence check (does translating -- with **no** rotation -- pentagon(v) by a candidate offset land exactly on pentagon(v+offset)'s own vertex set, for *every* vertex `v` in a large patch, not just one):

- `L1 = (1, 0)`: **430/430 tested vertices** match as a pure translation (rotation 0°). Confirmed as a genuine lattice vector.
- `L2 = (1/2, 1+h)`: from the single origin vertex, this also matched as a pure (rotation 0°) translation. This one fact (checked from only one vertex) is what Step 0's flawed reasoning then over-generalized into assuming every integer combination of `L1, L2` is automatically also a pure translation from *every* vertex -- which Step 0's own broader check (368/430, not 100%, for the composite vector `(0, 2(1+h)) = -L1 + 2L2`) showed is false in general.
- Directly testing `(0, 1)` (displacement to the next vertex "above"): **not** a pure translation from the origin (0/… match at rotation 0°), but **is** an exact match when the source pentagon is first **rotated 180°** before translating. The exact rotation center for this relation is `(0, 1/2)` -- the midpoint between the origin vertex and the vertex at `(0,1)` -- i.e. pentagon-at-`(0,1)` = pentagon-at-origin rotated 180° about `(0, 1/2)`.

**Conclusion, confirmed by the data above:** the tiling's true primitive translation lattice is generated by `L1 = (1, 0)` and `L2 = (1/2, 1+h)` (this much of Step 0's guess was right), but each primitive cell of that lattice (area `|det(L1,L2)| = 1+h ≈ 1.866`, exactly twice one pentagon's area `(2+sqrt(3))/4 ≈ 0.933`) contains **two** pentagons, not one: the "as-derived" orientation (call it **A**) and its own 180°-rotation (call it **B**), related by a 180° rotation about a point offset from the cell origin -- structurally the same "more than one oriented copy per translational cell" situation `cairo_pentagonal` had (there, 4 rotated copies; here, 2), just with a plain 180° rotation instead of four 90° steps, and with an **oblique** (non-rectangular) primitive cell instead of Cairo's square one, since `L1` and `L2` are not perpendicular (`L1 · L2 = 0.5 ≠ 0`) and not equal length (`|L1|=1`, `|L2| = sqrt(1/4 + (1+h)^2) ≈ 1.932`).

**A shear-free alternative was considered and rejected as unverified:** since `L2' = 2L2 - L1 = (0, 2(1+h))` is orthogonal to `L1` (dot product exactly 0), it looked tempting to use the *rectangular* sublattice `(L1, L2')` instead, which would only need a pure anisotropic scale (no shear) to normalize -- exactly like `_ASPECT_SQRT3_PATTERNS`'s existing mechanism, just with a different constant. This was tested the same rigorous way as everything else in this section, and it does **not** hold up: `(0, 2(1+h))` only matches as a pure (rotation-0°) translation for 348 of 430 tested vertices (81%, not 100%), so it is not actually a lattice symmetry by itself either -- using it would silently produce a tile that looks fine from a small sample and is subtly wrong at scale, the exact trap Step 0 already fell into once. The oblique lattice with a genuine shear (Step 4 below), by contrast, has been checked from every vertex in a large patch at 100%, not sampled from one point and extrapolated. **Do not revisit the shear-free rectangular-cell idea without repeating this same full-patch check** -- the temptation to "avoid the shear" by using `L2'` is real (it would match `_ASPECT_SQRT3_PATTERNS`'s existing style more closely) but is not backed by the same level of verification this plan otherwise insists on, and the one data point available (81%) is evidence against it, not for it.

### Step 4: the affine transform to `_UNIT_TILE` space -- shear + anisotropic scale

`L1` and `L2` are not orthogonal and not equal length, so (unlike `cairo_pentagonal`'s pure rotation + uniform scale) sending them exactly to `(1,0)` and `(0,1)` requires a general linear map with a shear term. Solving `T(L1) = (1,0)`, `T(L2) = (0,1)` for `T(x,y) = (x + b·y, d·y)` (this form already satisfies `T(1,0)=(1,0)` for any `b`, so only `T(L2)=(0,1)` needs solving):

```
d·(1+h) = 1        =>  d = 1/(1+h) = 4 - 2·sqrt(3)     (≈ 0.535898)
1/2 + b·(1+h) = 0  =>  b = -1/(2(1+h)) = sqrt(3) - 2    (≈ -0.267949)
```

verified exactly with `sympy` (exact radical arithmetic, not decimal approximation): `T(1,0) = (1,0)` and `T(1/2, 1+h) = (0,1)` both hold exactly.

**This transform is a shear (`b ≠ 0`) combined with a non-uniform scale (`d ≠ 1`, and the `x`-axis is left completely unscaled) -- explicitly answering the task's own question: yes, this pattern needs an anisotropic scale, and additionally (unlike `cubes`/`hex_grid`/`tri_grid`, whose sqrt(3) correction is a pure Y-scale with no shear) it needs a shear on top of that.** The shear is baked directly into the pentagon vertex coordinates below (Step 5) -- BOSL2's plain grid-based texture repeat (translating the tile content by exact `(1,0)`/`(0,1)` steps, no per-repeat transform) is all that's needed to stitch it correctly, since the shear is already "pre-applied" to every vertex before the tile is ever handed to BOSL2. What the shear does **not** get automatically is any correction from `_square_tile_vertical_reps()`: that mechanism can only ever scale a repeat *count*, never rotate/shear the tile's own content, so the practical result is that this pattern will show a consistent, permanent diagonal slant to its pentagon motif on the rendered wall. This is disclosed here explicitly rather than treated as an implementation detail to quietly work around.

### Step 5: applying the transform -- exact pentagon coordinates in `_UNIT_TILE` space

Pentagon **A** (the as-derived orientation from Step 2) transformed by `T`:

```
A0 = ((sqrt(3)-1)/2,   2-sqrt(3))
A1 = ((sqrt(3)-3)/2,   2-sqrt(3))
A2 = ((sqrt(3)-3)/3,   (3-2*sqrt(3))/3)
A3 = ((2*sqrt(3)-3)/3, (6-4*sqrt(3))/3)
A4 = (sqrt(3)/3,       (3-2*sqrt(3))/3)
```

Pentagon **B** (the 180°-rotation of **A** about `(0, 1/2)` in the original coordinates, i.e. `B_i = (0,1) - A_i` before transforming -- transformed by the same `T`, using `T`'s linearity, `T((0,1)-A_i) = T(0,1) - T(A_i)`):

```
B0 = ((sqrt(3)-3)/2,   2-sqrt(3))
B1 = ((sqrt(3)-1)/2,   2-sqrt(3))
B2 = ((2*sqrt(3)-3)/3, (9-4*sqrt(3))/3)
B3 = ((sqrt(3)-3)/3,   (6-2*sqrt(3))/3)
B4 = ((2*sqrt(3)-6)/3, (9-4*sqrt(3))/3)
```

**Verified exactly with `sympy`:** both `A` and `B` (in `_UNIT_TILE` space) have area exactly `1/2`, both are wound CCW (signed shoelace area `+1/2`, not negative -- unlike `cairo_pentagonal`'s CW result), and both are convex (`shapely`: each polygon equals its own convex hull). `A1 == B1`... more precisely `A1 == B0` and `A0 == B1` exactly (the two pentagons share the edge that was `A`'s own `A0-A1` edge) -- a direct geometric confirmation that **A** and **B** are genuinely adjacent, sharing a full edge, not just touching at a point.

### Step 6: covering the unit tile -- which translated copies are needed

**Exhaustively searched (Python/shapely)** which `(m, n, orientation)` triples -- translate pentagon **A** or **B** by lattice step `(m, n)` in `_UNIT_TILE`-normalized coordinates -- have any nonzero-area intersection with `[0,1]×[0,1]`, over `m, n ∈ [-3, 3]` (re-run at this wider range specifically to rule out anything Step 0's under-sized-patch mistake might have hidden): exactly **6** such triples exist (confirmed the same 6 at both `[-2,2]` and `[-3,3]` search ranges, i.e. the search has converged, not just been cut off), fewer than `cairo_pentagonal`'s 8:

```
(m, n, orientation)   clipped-to-unit-square area
(0, 0, A)             0.116025
(0, 0, B)             0.113249
(0, 1, A)             0.136751
(1, 0, A)             0.151924
(1, 0, B)             0.386751
(1, 1, A)             0.095299
```

**Sum of clipped areas = exactly 1.0** (verified to 9 decimal places), and the union of the 6 clipped pieces was verified (via `shapely`) to equal the unit square **exactly** (`unit_square.symmetric_difference(union_of_6_pieces).area == 0.0`), a single connected polygon, zero interior holes, with **zero pairwise overlap** among the 6 pieces (checked all `C(6,2)=15` pairs directly, not inferred from the area/union match alone).

**Twin-vertex-on-opposite-edges invariant, checked directly:** collecting every vertex of the 6 clipped pieces lying exactly on `u=0`, `u=1`, `v=0`, or `v=1` gives, on every edge: `u=0` and `u=1` both have vertex set `{0, 2-sqrt(3), sqrt(3)-1, 1}` (4 points -- numerically `{0, 0.2679492, 0.7320508, 1}`, symmetric about `0.5` as expected), and `v=0` and `v=1` both have vertex set `{0, 1/2, 1}` (3 points). Both pairs match exactly. This holds regardless of the shear -- the shear is already baked into the vertex coordinates before this check runs, so the check confirms the *actual* tile stitches correctly, not just the pre-shear geometry.

### Step 7: OpenSCAD/BOSL2 verification (not just Python)

Verified directly, the same way `cairo_pentagonal`'s plan did: a throwaway OpenSCAD script that includes the real `modules/decoration.scad`, defines the 6 `(m,n,orientation)` placements and the `A`/`B` pentagons exactly as in Steps 5-6 above (using OpenSCAD's own `sqrt(3)` at evaluation time, not hardcoded decimals), builds the islands list with `offset(poly, delta=-_PP_GAP/2, closed=true)` (gap `0.05`, matching the constant Task 1 uses) feeding the real, unmodified `_tile_from_islands()`, and asserts on the result. Result (`openscad -o /tmp/pp_smoke.stl <script>`, exit 0):

- `polygon_area(A, signed=true)` and `polygon_area(B, signed=true)`: both exactly `0.5` (confirms CCW winding for both orientations, matching Step 5's prediction).
- Every one of the 6 `offset(poly, delta=-0.025, closed=true)` calls returned a valid shrunk pentagon (`abs(signed_area)` reduced from `0.5` to `≈0.427755` -- identical for all 6, since **A** and **B** are congruent and shrunk by the same delta).
- `_tile_from_islands(islands)` (the real function, unmodified) produced `is_vnf(tex) == true`.
- `pointlist_bounds(tex[0])` = exactly `[[0,0,0],[1,1,1]]`.
- The twin-vertex check (`_tile_edge_profile()` helper, same as other tile tests) gave **identical** point lists for `u=0`/`u=1` (`[[0,1],[0.242949,0],[0.242949,1],[0.292949,0],[0.292949,1],[0.706169,0],[0.706169,1],[0.757933,0],[0.757933,1],[1,1]]`, 10 points) and for `v=0`/`v=1` (`[[0,1],[0.472049,0],[0.472049,1],[0.527951,0],[0.527951,1],[1,1]]`, 6 points), exact match both times.
- A full real-render smoke test: `cyl(h=100, r1=75, r2=60, $fn=50, texture=tex, tex_reps=[12,8], tex_depth=1.5, tex_inset=false)` differenced against a disjoint cube (forcing real CGAL Nef-polyhedron evaluation) completed with **exit 0**, no `CGAL error`, `Simple: yes`, `Volumes: 2` -- a valid, non-self-intersecting manifold.

This is one configuration (`pattern_repeat=12`, `$fn=50`, `raised`-equivalent `tex_inset=false`), not the full CGAL sweep this project requires before shipping -- see Task 1's CGAL-sweep step below, which is not optional just because this smoke test passed.

### Aspect Correction

`_square_tile_vertical_reps()`'s existing `_ASPECT_SQRT3_PATTERNS` mechanism corrects `cubes`/`hex_grid`/`tri_grid` by a factor of exactly `sqrt(3)` -- the ratio their own BOSL2-documented "true regular shape" construction needs. This pattern's natural repeat cell (before normalization) is `1` wide (`L1`) by `1+h = (2+sqrt(3))/2 ≈ 1.866` tall in the *un-sheared* sense that matters for vertical-repeat counting (the shear itself doesn't change how many repeats are needed vertically, only how they're slanted) -- **a different constant than `sqrt(3)`**, so simply adding `"prismatic_pentagonal"` to `_ASPECT_SQRT3_PATTERNS` would silently apply the wrong correction. Task 1 therefore generalizes `_square_tile_vertical_reps()`'s aspect mechanism into a small per-pattern factor lookup (`_tile_aspect_factor()`), preserving the exact existing behavior for `cubes`/`hex_grid`/`tri_grid` (still `sqrt(3)`, still gated by `_ASPECT_SQRT3_PATTERNS`) while giving `"prismatic_pentagonal"` its own factor, `(2+sqrt(3))/2`, through the same divide-for-vertical/multiply-for-horizontal flip the existing mechanism already does for `pattern_orientation`.

### Relief Mode Decision

**Recommendation: mode-independent, uniform height `1.0` for every pentagon, like `rhombille`/`cairo_pentagonal` -- no `relief_mode` parameter on `_prismatic_pentagonal_tile()`.**

Reasoning, following the exact decision framework `cairo_pentagonal`'s own plan used: the "kis" family's raised/etched split exists because each of *their* tile cells is itself a multi-triangle fan with an obvious sub-structure to vary height across. This pentagon (like the Cairo pentagon) is a single flat convex face per island -- there is no natural sub-fan to split, and no motif-specific reason (unlike `tumbling_cubes`' three-height cube illusion) to introduce arbitrary height variation. `decorated_solid()`'s existing `tex_inset` machinery already gives a clean, true-inverted etched look for a uniform-height VNF tile, satisfying this project's "etched should look engraved" goal the same way `rhombille`/`cairo_pentagonal` already do.

## Task 1: `_prismatic_pentagonal_tile()` -- geometry, aspect-correction generalization, wiring, tests, docs

**Files:**
- Modify: `modules/decoration.scad` (add `_PP_A0`..`_PP_A4`, `_PP_B0`..`_PP_B4`, `_PP_A`, `_PP_B`, `_PP_PLACEMENTS`, `_PP_GAP`, `_PP_Z`, `_pp_pentagon()`, `_prismatic_pentagonal_tile()`; extend `PATTERN_TYPES`; extend `_decoration_texture()`; extend the CGAL-warning `echo()` pattern lists; generalize `_square_tile_vertical_reps()`'s aspect mechanism into `_tile_aspect_factor()`)
- Create: `tests/test_decoration_prismatic_pentagonal.scad`
- Modify: `tests/test_decoration_pattern_types.scad` (extend `EXPECTED_PATTERN_TYPES` and `EXPECTED_VNF_PATTERN_TYPES`)
- Modify: `tests/test_decoration_etched_groove.scad` (extend `VNF_PATTERN_TYPES`)
- Modify: `tests/test_decoration_tile_aspect.scad` (add a new aspect-factor assertion block; do **not** add this pattern to the plain-formula loop)
- Modify: `.github/workflows/test.yml` (add `"prismatic_pentagonal"` to every pattern-type loop)
- Modify: `planter.scad` (Customizer dropdown comment for `pattern_type`)
- Modify: `README.md` (parameter table, interlocking-patterns enumeration, aspect-correction discussion, CGAL section)
- Modify: `docs/gallery.md` (new subsection + regenerated images via `docs/images/render.sh`; update the Pattern Comparison intro's "16 of 19"/"three sqrt(3)-corrected patterns" language)
- Modify: `TODO.md` (check off the Prismatic pentagonal line)

**Interfaces:**
- Consumes: `_tile_from_islands(islands)`, `_UNIT_TILE` -- both existing, defined in `modules/decoration.scad`'s "Shared plateau-tile builder" section.
- Produces: `_prismatic_pentagonal_tile()` (no arguments -- geometry doesn't depend on `relief_mode`, matching `_rhombille_tile()`/`_cairo_pentagonal_tile()`'s signature). `_decoration_texture(pattern_type, relief_mode)` gains one more branch: `pattern_type == "prismatic_pentagonal" ? _prismatic_pentagonal_tile() :`. `_tile_aspect_factor(pattern_type)` is a new function returning the vertical-reps correction factor for a pattern (`sqrt(3)` for `_ASPECT_SQRT3_PATTERNS` members, `(2+sqrt(3))/2` for `"prismatic_pentagonal"`, `1` otherwise); `_square_tile_vertical_reps()` is refactored to call it instead of its own inline `is_sqrt3` boolean.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_decoration_prismatic_pentagonal.scad`, following `tests/test_decoration_cairo_pentagonal.scad`'s exact structure:

```openscad
// tests/test_decoration_prismatic_pentagonal.scad
//
// "prismatic_pentagonal" is a custom VNF tile (the prismatic pentagonal
// tiling, Wikipedia "V3^3.4^2" -- congruent, irregular pentagons, every
// pentagon at the same height), not a BOSL2 texture name, so it needs a
// real-render check: a tile whose points leave the unit square, whose edges
// don't line up across the tile boundary, or whose walls are wound
// backwards only fails when the geometry is actually evaluated.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("prismatic_pentagonal", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"prismatic_pentagonal\"");

_tex = _decoration_texture("prismatic_pentagonal", "raised");
assert(is_list(_tex) && len(_tex) == 2,
    "_decoration_texture(\"prismatic_pentagonal\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex), "_decoration_texture(\"prismatic_pentagonal\") must be a valid VNF");

// A VNF texture tile's footprint must lie inside the unit square with Z in
// [0,1]; BOSL2 rejects anything else at render time.
_bounds = pointlist_bounds(_tex[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("prismatic_pentagonal tile must fit in the unit cube, got bounds ", _bounds));
// This construction's pentagons genuinely reach every side of the unit
// square (see the plan's Geometry Derivation, Step 6) -- confirm the full
// extent is used, not just bounded by it.
assert(approx(_bounds[0][0], 0) && approx(_bounds[0][1], 0) &&
       approx(_bounds[1][0], 1) && approx(_bounds[1][1], 1),
    str("prismatic_pentagonal tile should reach every edge of the unit square exactly, got bounds ", _bounds));

// VNF tiles take no `style` (that's a heightfield-triangulation setting), and
// _decoration_style() must reach that answer from the resolved texture rather
// than from a pattern_type-specific branch.
assert(_decoration_style("prismatic_pentagonal", "raised") == undef,
    "prismatic_pentagonal is a VNF tile and must not carry a style override");
assert(_decoration_style("prismatic_pentagonal", "etched") == undef,
    "prismatic_pentagonal is a VNF tile and must not carry a style override when etched");

// Every pentagon sits at the SAME height, and it's the tile's full height:
// this pattern is a plain pentagon mosaic, not a multi-height illusion like
// tumbling_cubes, and pattern_depth should be fully used.
assert(_PP_Z == 1, str("prismatic_pentagonal's uniform pentagon height must be 1, got ", _PP_Z));
_zs = unique([for (p = _tex[0]) p[2]]);
assert(_zs == [0, 1],
    str("prismatic_pentagonal's VNF must use exactly two Z levels -- ground (0) and every ",
        "pentagon at the tile's full height (1) -- got ", _zs));

// raised and etched must resolve to the exact same VNF -- this pattern's
// geometry doesn't depend on relief_mode (decorated_solid()'s tex_inset
// handles the raised/etched distinction), unlike the three kis-family
// patterns which genuinely build a different tile per mode.
_tex_etched = _decoration_texture("prismatic_pentagonal", "etched");
assert(_tex == _tex_etched,
    "prismatic_pentagonal's tile geometry must be identical for \"raised\" and \"etched\" -- only decorated_solid()'s tex_inset should differ");

// The invariant the whole tile design rests on: every vertex the tile leaves
// on one edge needs a twin at the same position on the opposite edge, or
// repeats don't stitch and the surface leaks. Rendering without an error is a
// weak proxy for this -- BOSL2 only enforces it for vertices sitting on
// *open* edges, and a near-miss can still render while producing a subtly
// non-tiling mesh. So compare the two edges directly.
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex, axis, 0);
    hi = _tile_edge_profile(_tex, axis, 1);
    name = (axis == 0) ? "x" : "y";
    // This construction's own derivation (see the plan's Geometry Derivation,
    // Step 6) found exactly 4 points on the u=0/u=1 edges and 3 points on the
    // v=0/v=1 edges -- both well beyond the 2 tile corners alone, so more
    // than 2 is what proves a pentagon genuinely spans the seam, not just
    // touches at a corner.
    assert(len(lo) > 2,
        str("prismatic_pentagonal tile has only ", len(lo), " vertices on its ", name,
            "=0 edge -- no pentagon spans the seam"));
    assert(len(lo) == len(hi),
        str("prismatic_pentagonal tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("prismatic_pentagonal tile ", name, " edge vertices don't line up: ", mismatched));
}

difference() {
    decorated_solid("prismatic_pentagonal", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
openscad -o /tmp/test.csg tests/test_decoration_prismatic_pentagonal.scad
```
Expected: FAIL -- `"prismatic_pentagonal"` is not yet in `PATTERN_TYPES` (ERROR: Assertion failed at the `in_list` check).

- [ ] **Step 3: Add the tile geometry to `modules/decoration.scad`**

Insert a new section immediately after the existing `_cairo_pentagonal_tile()` function (right before the `"--- Kisrhombille"` comment block), so the three most recently added tiles sit next to each other in file order:

```openscad
// --- Prismatic pentagonal (dual of the elongated triangular tiling) --------
//
// Wikipedia "V3^3.4^2": a tessellation by congruent, irregular convex
// pentagons -- 2 short edges, 3 long edges, two adjacent 90-degree angles and
// three 120-degree angles. Every pentagon sits at the same height here (like
// rhombille/cairo_pentagonal), since a single pentagon has no natural
// sub-fan to vary height across. See this pattern's plan document
// (docs/superpowers/plans/2026-09-19-prismatic-pentagonal-pattern.md) for
// the full derivation and the computational verification this construction
// is based on (Python/shapely closure checks over a 1424-pentagon patch,
// plus a live OpenSCAD/BOSL2 smoke test of this exact code path) -- do not
// re-derive the lattice by hand; an initial by-hand attempt at this exact
// pattern produced a plausible-looking but wrong lattice vector that only
// a full-patch computational check caught.
//
// Unlike cairo_pentagonal (a pure rotation + uniform scale into _UNIT_TILE
// space), this pattern's natural translation lattice is OBLIQUE (its two
// generators are neither perpendicular nor equal length, a direct
// consequence of mixing unit squares with sqrt(3)/2-tall equilateral
// triangles), so the normalizing transform below is a SHEAR plus an
// anisotropic scale. The shear is baked directly into every vertex
// coordinate below; BOSL2's plain axis-aligned tile repeat is all that's
// needed to stitch it (already verified -- see the plan's Step 6/7), but
// there is no mechanism anywhere in this file that corrects the shear
// itself, only the vertical repeat COUNT (see _tile_aspect_factor() and
// _PP_ASPECT below) -- this pattern renders with a permanent, deliberate
// diagonal slant to its pentagon motif. That is a real visual property of
// this tiling on this project's cylindrical wall, not a bug.
//
// Two pentagon orientations are needed per translational lattice cell (like
// cairo_pentagonal needing 4, just simpler here: a plain 180-degree
// rotation, not four 90-degree steps). _PP_A is the as-derived orientation;
// _PP_B is _PP_A rotated 180 degrees about (0, 1/2) in the PRE-transform
// coordinate system, already carried through the same transform.
_PP_A0 = [(sqrt(3)-1)/2,   2-sqrt(3)];
_PP_A1 = [(sqrt(3)-3)/2,   2-sqrt(3)];
_PP_A2 = [(sqrt(3)-3)/3,   (3-2*sqrt(3))/3];
_PP_A3 = [(2*sqrt(3)-3)/3, (6-4*sqrt(3))/3];
_PP_A4 = [sqrt(3)/3,       (3-2*sqrt(3))/3];
_PP_A  = [_PP_A0, _PP_A1, _PP_A2, _PP_A3, _PP_A4];

_PP_B0 = [(sqrt(3)-3)/2,   2-sqrt(3)];
_PP_B1 = [(sqrt(3)-1)/2,   2-sqrt(3)];
_PP_B2 = [(2*sqrt(3)-3)/3, (9-4*sqrt(3))/3];
_PP_B3 = [(sqrt(3)-3)/3,   (6-2*sqrt(3))/3];
_PP_B4 = [(2*sqrt(3)-6)/3, (9-4*sqrt(3))/3];
_PP_B  = [_PP_B0, _PP_B1, _PP_B2, _PP_B3, _PP_B4];

// Which (lattice-step, orientation) copies have any overlap with the unit
// square -- exhaustively searched over lattice steps -3..3 in each
// direction; exactly these 6 do (their clipped areas sum to exactly 1.0,
// their union was verified to equal the unit square exactly, with zero
// overlap among them). Each entry is [m, n, which]: pentagon _PP_A (which=0)
// or _PP_B (which=1), translated by (m, n) in unit-tile lattice steps.
_PP_PLACEMENTS = [[0,0,0], [0,0,1], [1,0,0], [1,0,1], [0,1,0], [1,1,0]];

function _pp_pentagon(m, n, which) =
    let (base = (which == 0) ? _PP_A : _PP_B)
    [for (p = base) [p[0] + m, p[1] + n]];

_PP_GAP = 0.05; // engraved groove width, in tile fractions -- own constant,
                // same scale as _KIS_GAP/_RH_GAP/_CP_GAP but never shared
                // with them
_PP_Z   = 1.0;  // every pentagon reaches the tile's full height (uniform,
                // like rhombille/cairo_pentagonal -- see this pattern's
                // plan document's "Relief Mode Decision")

function _prismatic_pentagonal_tile() =
    _tile_from_islands([
        for (pl = _PP_PLACEMENTS)
            let (poly = _pp_pentagon(pl[0], pl[1], pl[2]),
                 r = offset(poly, delta = -_PP_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _PP_Z]
    ]);
```

- [ ] **Step 4: Wire it into `PATTERN_TYPES` and `_decoration_texture()`**

In `PATTERN_TYPES`, append `"prismatic_pentagonal"` after `"cairo_pentagonal"`:

```openscad
PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                 "bricks", "checkers", "dots", "cubes", "tri_grid",
                 "teardrop", "tumbling_cubes", "intertwine", "islamic_star",
                 "tetrakis_square", "kisrhombille", "triakis_triangular",
                 "rhombille", "cairo_pentagonal", "prismatic_pentagonal"];
```

Update the file's opening comment block above `PATTERN_TYPES` (currently documents "the nine custom VNF tiles") to say "the ten custom VNF tiles" and add `prismatic_pentagonal` to the named list.

In `_decoration_texture()`, add one more branch, right after the `cairo_pentagonal` line:

```openscad
    pattern_type == "cairo_pentagonal"       ? _cairo_pentagonal_tile() :
    pattern_type == "prismatic_pentagonal"   ? _prismatic_pentagonal_tile() :
    pattern_type;
```

- [ ] **Step 5: Generalize `_square_tile_vertical_reps()`'s aspect-correction mechanism**

Replace the existing `_ASPECT_SQRT3_PATTERNS`-only logic with a small per-pattern factor lookup, preserving the exact existing behavior for `cubes`/`hex_grid`/`tri_grid` and adding this pattern's own constant:

```openscad
// BOSL2's own documentation (lib/BOSL2/skin.scad texture catalog comments)
// says these three need an additional sqrt(3) Y-scale for correct aspect:
// "cubes" for a true isometric-cube look, "hex_grid"/"tri_grid" so their
// V-groove border width is uniform on every side of the hexagon/triangle
// (regular hexagons/triangles, not stretched ones).
_ASPECT_SQRT3_PATTERNS = ["cubes", "hex_grid", "tri_grid"];

// "prismatic_pentagonal"'s own natural repeat cell (see this pattern's plan
// document's "Aspect Correction" section) is 1 wide by (1+h) tall, h =
// sqrt(3)/2 -- an aspect ratio of (2+sqrt(3))/2, NOT sqrt(3). This is a
// separate constant from _ASPECT_SQRT3_PATTERNS' hardcoded sqrt(3); reusing
// that list for this pattern would silently apply the wrong correction.
_PP_ASPECT = (2 + sqrt(3)) / 2;

// Returns the vertical-reps aspect-correction factor for a pattern: the
// factor _square_tile_vertical_reps() divides by (in "vertical"
// pattern_orientation) or multiplies by (in "horizontal") to keep that
// pattern's own natural cell proportion correct. 1 means no correction
// (the plain square-tile formula). Split out from
// _square_tile_vertical_reps() so a future pattern needing its own
// aspect ratio (like this one) doesn't have to grow a new boolean/ternary
// chain inside that function every time.
function _tile_aspect_factor(pattern_type) =
    in_list(pattern_type, _ASPECT_SQRT3_PATTERNS) ? sqrt(3) :
    pattern_type == "prismatic_pentagonal"        ? _PP_ASPECT :
    1;

function _square_tile_vertical_reps(pattern_type, pattern_orientation, pattern_repeat, r1, r2, height) =
    in_list(pattern_type, _ASPECT_EXCLUDED_PATTERNS) ? pattern_repeat :
    let(
        avg_circumference = PI * (r1 + r2),
        factor = _tile_aspect_factor(pattern_type),
        // BOSL2 rotates the TILE'S OWN CONTENT by 90 degrees for tex_rot=90
        // (this project's "horizontal" pattern_orientation) -- see
        // lib/BOSL2/skin.scad's _get_texture(). tex_reps' own axes stay tied
        // to the SURFACE regardless of tex_rot, so a texture whose intrinsic
        // Y needs to be `factor` times its intrinsic X has that requirement
        // land on the surface's vertical axis normally, but on the surface's
        // circumferential axis once rotated -- the correction flips from
        // dividing vertical_reps by `factor` to multiplying it.
        aspect_correction = (factor == 1) ? 1
            : (pattern_orientation == "horizontal") ? (1 / factor) : factor
    )
    max(1, round(pattern_repeat * height / (avg_circumference * aspect_correction)));
```

Also update the big comment block above `_square_tile_vertical_reps()` (the one currently ending "...so they use the plain formula like every BOSL2 catalog texture without a documented sqrt(3) requirement") to note that `prismatic_pentagonal` is the one exception among the custom VNF tiles: it DOES need a (non-sqrt(3)) aspect correction, unlike the other nine, because its own affine map to `_UNIT_TILE` space is not aspect-neutral the way theirs are.

- [ ] **Step 6: Extend the CGAL-warning pattern list in `decorated_solid()`**

For now, add `"prismatic_pentagonal"` to the *milder* "measured clean everywhere" bucket (the `else if` branch currently listing `"tetrakis_square", "kisrhombille", "triakis_triangular"`) as a **starting hypothesis only**, exactly the way `cairo_pentagonal`'s own Task 1 Step 5 started -- Step 9 below runs the real CGAL sweep and this placement must be revisited (moved to the "known to abort" bucket alongside `tumbling_cubes`/`intertwine`/`islamic_star`/`rhombille`/`cairo_pentagonal`, with documented failing values) if that sweep finds a break. Do not skip Step 9 on the strength of this plan's own single-configuration smoke test (Geometry Derivation, Step 7).

- [ ] **Step 7: Run the new test and the full pattern-types test**

```bash
openscad -o /tmp/test_prismatic_pentagonal.csg tests/test_decoration_prismatic_pentagonal.scad
openscad -o /tmp/test_prismatic_pentagonal.stl tests/test_decoration_prismatic_pentagonal.scad 2>&1 | tee /tmp/pp_render.log
grep -i "CGAL error" /tmp/pp_render.log
```
Expected: PASS (exit 0, no ERROR, no `CGAL error` in the log).

Update `tests/test_decoration_pattern_types.scad`:

```openscad
EXPECTED_PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                          "bricks", "checkers", "dots", "cubes", "tri_grid",
                          "teardrop", "tumbling_cubes", "intertwine",
                          "islamic_star", "tetrakis_square", "kisrhombille",
                          "triakis_triangular", "rhombille", "cairo_pentagonal",
                          "prismatic_pentagonal"];

EXPECTED_VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine",
                              "islamic_star", "tetrakis_square", "kisrhombille",
                              "triakis_triangular", "rhombille",
                              "cairo_pentagonal", "prismatic_pentagonal"];
```

Also update that file's header comment to mention `prismatic_pentagonal` joins the list as a tenth VNF pattern, with the same "does NOT need the etched-vs-raised carve-out" note `rhombille`/`cairo_pentagonal`'s own entries there already carry.

Re-run `tests/test_decoration_pattern_types.scad` and confirm it still passes with the extended lists.

Update `tests/test_decoration_etched_groove.scad`'s `VNF_PATTERN_TYPES`:

```openscad
VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine", "islamic_star",
                     "rhombille", "cairo_pentagonal", "prismatic_pentagonal"];
```

Re-run that file and confirm it still passes.

- [ ] **Step 8: `tests/test_decoration_tile_aspect.scad`**

**Do not** add `"prismatic_pentagonal"` to the existing plain-square-tile VNF loop (`for (pt = ["teardrop", ..., "checkers"])`) -- unlike every other custom VNF tile, this one needs the aspect-corrected formula, not the plain one, and adding it there would assert the wrong thing.

Instead, add a new block mirroring the existing `cubes`/`hex_grid`/`tri_grid` sqrt(3) block, using the `(2+sqrt(3))/2` factor:

```openscad
// "prismatic_pentagonal": its own aspect factor, (2+sqrt(3))/2, not
// sqrt(3) -- see modules/decoration.scad's _tile_aspect_factor() and this
// pattern's plan document's "Aspect Correction" section.
_pp_factor = (2 + sqrt(3)) / 2;
v_pp = _square_tile_vertical_reps("prismatic_pentagonal", "vertical", pattern_repeat, r1, r2, height);
expected_pp = round(pattern_repeat * height / (avg_circ * _pp_factor));
assert(v_pp == expected_pp,
    str("expected prismatic_pentagonal vertical_reps ", expected_pp, ", got ", v_pp));
assert(v_pp < v_dots,
    "prismatic_pentagonal vertical_reps must be smaller than the plain square-tile count ((2+sqrt(3))/2 > 1 correction)");
assert(v_pp != v_cubes,
    "prismatic_pentagonal's own aspect factor must differ from cubes/hex_grid/tri_grid's sqrt(3) factor at these inputs");

v_pp_horizontal = _square_tile_vertical_reps("prismatic_pentagonal", "horizontal", pattern_repeat, r1, r2, height);
expected_pp_horizontal = round(pattern_repeat * height * _pp_factor / avg_circ);
assert(v_pp_horizontal == expected_pp_horizontal,
    str("expected horizontal prismatic_pentagonal vertical_reps ", expected_pp_horizontal, ", got ", v_pp_horizontal));
assert(v_pp_horizontal > v_dots,
    "horizontal-orientation prismatic_pentagonal vertical_reps must be larger than the plain square-tile count (inverted correction)");
```

Re-run that file and confirm it passes, including the pre-existing assertions (this pattern's addition must not change `cubes`/`hex_grid`/`tri_grid`'s own numbers).

- [ ] **Step 9: `planter.scad` Customizer dropdown comment**

Find `pattern_type`'s Customizer dropdown declaration/comment in `planter.scad` (grep for `pattern_type`) and add `"prismatic_pentagonal"` to it, in the same position (end of list, after `"cairo_pentagonal"`). This is the exact step a prior PR review caught missing twice already -- do not repeat it a third time.

- [ ] **Step 10: CGAL sweep -- determine the real warning bucket**

Following the exact methodology `cairo_pentagonal`'s own plan (`docs/superpowers/plans/2026-09-19-cairo-pentagonal-pattern.md`, Step 8) used: render the full assembly (`tests/test_planter_integration.scad`) with `pattern_type="prismatic_pentagonal"` across a sweep of `pattern_repeat` values (at least: a low value like 4, the shipped default 16, and a higher value like 24 or 32) crossed with `smoothness` values (at least 24 and the shipped default 60), in **both** `relief_mode="raised"` and `"etched"`:

```bash
for reps in 4 16 24 32; do
  for smooth in 24 60; do
    for relief in raised etched; do
      openscad -D 'pattern_type="prismatic_pentagonal"' -D "relief_mode=\"$relief\"" \
               -D "pattern_repeat=$reps" -D "smoothness=$smooth" \
               -o /tmp/pp_${reps}_${smooth}_${relief}.stl tests/test_planter_integration.scad \
               2>&1 | tee /tmp/pp_${reps}_${smooth}_${relief}.log
      grep -i "CGAL error" /tmp/pp_${reps}_${smooth}_${relief}.log && echo "ABORT: reps=$reps smooth=$smooth relief=$relief"
    done
  done
done
```

Do this on the real CI runner if at all possible, not local-only -- README.md and this repo's git history document that CGAL fragility has previously differed between a local macOS build and GitHub Actions' Ubuntu build despite an identical reported OpenSCAD version (see `intertwine`'s and `rhombille`'s own CGAL notes in README.md for the exact precedent).

- If every combination is clean: leave Step 6's placement in the "measured clean everywhere" bucket. Record the specific values tested in README.md's CGAL section (Step 13 below).
- If any combination aborts CGAL: move `"prismatic_pentagonal"` to the "known to abort" bucket in `decorated_solid()`'s `echo()`, and document the specific failing `pattern_repeat`/`smoothness`/`relief_mode` combinations in README.md the way `rhombille`/`cairo_pentagonal`'s own failure-mode documentation there is written (name specific clean and specific failing values, not a vague range). If you find a narrow band of clean values, pick the reduced value for CI the same disciplined way `intertwine`'s/`rhombille`'s notes in `.github/workflows/test.yml` describe (a clean value with a tested margin on both sides, not an isolated one sandwiched between two aborts, and re-verify against a real CI run before trusting a local-only measurement).

- [ ] **Step 11: `.github/workflows/test.yml`**

Add `"prismatic_pentagonal"` to every loop that enumerates all pattern types:
- Line ~74-76's per-tile CGAL-forcing loop (`for f in teardrop tumbling_cubes intertwine islamic_star tetrakis_square kisrhombille triakis_triangular rhombille cairo_pentagonal; do`) -- append `prismatic_pentagonal` (this exercises `tests/test_decoration_prismatic_pentagonal.scad` from Step 1/7 above).
- Line ~97's single-pattern texture-build loop (`for pt in none ridges ... cairo_pentagonal; do`) -- append `prismatic_pentagonal`.
- Line ~315-319's full-assembly reduced-value loop (the `for combo in "ridges 4" ... "cairo_pentagonal 8"; do` list) -- append `"prismatic_pentagonal <value>"` using whatever reduced `pattern_repeat` value Step 10's sweep found clean in **both** relief modes at `smoothness=24` (this loop's fixed smoothness), following the exact reasoning-and-comment style the `rhombille`/`cairo_pentagonal` entries immediately above it already use (explain *why* that specific value was chosen -- clean neighbors on both sides, not an isolated clean value between two aborts).
- If Step 10 found the shipped defaults (`pattern_repeat=16`, `smoothness=60`) unsafe in either relief mode: add a default-settings pin the same way the `for relief in raised etched; do run_assembly_combo "cairo_pentagonal" ...` block already does; otherwise, add this pattern to that same pinned-defaults loop (it's cheap to render -- a few seconds, like `rhombille`/`cairo_pentagonal` -- so there's no runtime reason to leave it out if it measures clean there).
- Line ~373's textured-solid-union claim comment and the union check just above it (`for pt in tumbling_cubes islamic_star; do ... done`) -- if Step 10's sweep (or an equivalent one-off union check, mirroring the exact idiom `cairo_pentagonal`'s own README note used: union with a `"dots"` solid, differenced against a disjoint cube) finds this pattern CGAL-aborts on union with another textured solid, add it to the "abort" side of that comment's claim (alongside `teardrop`/`intertwine`/`rhombille`/`cairo_pentagonal`) rather than leaving the comment's enumeration stale.
- Line ~481's invalid-`pattern_type` negative-check list -- append `prismatic_pentagonal` (this list must match `PATTERN_TYPES` so the assertion-message check stays accurate).

Run the equivalent of this workflow's own test script locally (or push and watch the real run) and confirm zero `FAIL` lines.

- [ ] **Step 12: Documentation -- README.md**

- Add `"prismatic_pentagonal"` to the `pattern_type` parameter's valid-values list (the line documenting `..."cairo_pentagonal"`).
- Extend the "N of the pattern_type values are interlocking" sentence (currently names `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`, `"rhombille"`, `"cairo_pentagonal"` explicitly) to also name `"prismatic_pentagonal"` and update the count from six to seven. This class of claim has already gone stale once in this repo's history -- name it explicitly.
- Add a short discussion of this pattern's aspect distortion near the existing `hex_grid`/`tri_grid`/`cubes` sqrt(3) discussion (find where README.md currently explains that aspect correction, if it does -- otherwise near the `pattern_type` parameter table): explain that `"prismatic_pentagonal"` also needs a (different, `(2+sqrt(3))/2`) vertical-reps correction, AND that its tile has a permanent diagonal shear/slant baked into its geometry that no setting corrects -- word this plainly, the same honest-limitation tone `README.md` already uses for `intertwine`'s render time and `teardrop`'s scalloped end caps.
- Add `"prismatic_pentagonal"`'s entry to the CGAL-fragility section per Step 10's actual findings, following the exact structure and level of detail `rhombille`/`cairo_pentagonal`'s own paragraphs there use.

- [ ] **Step 13: Documentation -- gallery**

Add a new subsection to `docs/gallery.md`, immediately after the existing `### cairo_pentagonal` subsection, matching its exact structure:

```markdown
### prismatic_pentagonal

| Raised | Etched |
|---|---|
| ![prismatic_pentagonal, raised](images/pattern-prismatic_pentagonal-raised.png) | ![prismatic_pentagonal, etched](images/pattern-prismatic_pentagonal-etched.png) |

Interlocking. The prismatic pentagonal tiling (Wikipedia "V3^3.4^2", dual of
the elongated triangular tiling): congruent, irregular pentagons -- 2 short
edges, 3 long edges, two adjacent right angles -- every pentagon raised to
the same height. Unlike every other pattern in this gallery, this tile's own
normalizing transform is a shear, not just a rotation/scale, so its pentagon
motif renders with a permanent diagonal slant -- a real property of this
tiling on a square repeat grid, not a rendering artifact. Because the
geometry doesn't change between raised and etched, `"etched"` here is a true
inverted copy of the raised relief, like `rhombille`/`cairo_pentagonal`, not
a separate flat-panel construction like the "kis" family.
```

Also add `prismatic_pentagonal` to the gallery's Table of Contents list (immediately after the `cairo_pentagonal` entry).

Update the Pattern Comparison section's intro paragraph: it currently says renders come out square "for 16 of the 19 patterns" with three sqrt(3)-corrected exceptions (`cubes`, `hex_grid`, `tri_grid`). With this pattern added there are 20 total patterns and a **fourth** exception with its own (different, and additionally sheared) aspect -- update the count and add `prismatic_pentagonal` to the exceptions list, noting its correction factor differs from the other three's shared `sqrt(3)` (so its close-up image will be a different non-square proportion than theirs) and that its motif will also visibly show the diagonal shear the other three don't have.

Regenerate images using `docs/images/render.sh` (it reads `PATTERN_TYPES` directly from `modules/decoration.scad`, so no separate pattern list in that script needs editing -- confirm it picks up the new pattern automatically). Confirm the run completes cleanly and `git status` shows exactly the 2 new images plus doc edits, no unexpected changes to unrelated images.

- [ ] **Step 14: `TODO.md`**

Check off the Prismatic pentagonal line in the tessellation backlog:

```markdown
    - [x] Prismatic pentagonal tiling ("V3^3.4^2") -- batch 3
```

- [ ] **Step 15: Commit**

```bash
git add modules/decoration.scad tests/test_decoration_prismatic_pentagonal.scad \
        tests/test_decoration_pattern_types.scad tests/test_decoration_etched_groove.scad \
        tests/test_decoration_tile_aspect.scad .github/workflows/test.yml \
        planter.scad README.md docs/gallery.md docs/images TODO.md
git commit -m "Add prismatic_pentagonal pattern_type: the prismatic pentagonal tiling, verified computationally"
```

## Self-Review Notes

- **Spec coverage:** the Geometry Derivation section covers exact pentagon coordinates (both orientations), the exact affine transform (explicitly identified as a shear + anisotropic scale, not a pure rotation), the exact translation lattice (reduced to `(1,0)`/`(0,1)`), a description of both verifications run (Python/shapely closure proof over a 1424-pentagon patch, and a live OpenSCAD/BOSL2 smoke test) and their results, the Relief Mode Decision, and an explicit statement that the pattern needs a new (non-`sqrt(3)`) aspect-correction category plus an uncorrected shear -- all points the task's "What to produce" section required, including the two the task specifically warned are easy to miss (the anisotropic-scale question, and whether `_ASPECT_SQRT3_PATTERNS` needs a new sibling).
- **No placeholders:** every constant (`_PP_A0`..`_PP_A4`, `_PP_B0`..`_PP_B4`, `_PP_PLACEMENTS`, `_PP_GAP`, `_PP_Z`, `_PP_ASPECT`) is a literal exact value derived and verified in the Geometry Derivation section, not a TBD. The CGAL warning bucket is an honest dependency on Step 10's real measurement, matching how `cairo_pentagonal`'s own plan handled the same kind of measurement-dependent step.
- **Documented dead end:** Step 0 of the Geometry Derivation records the specific wrong turn taken (treating `(0, 2(1+h))` as a pure translation without checking it against more than one vertex) and how the mistake was caught, per this task's explicit instruction not to repeat the prior Cairo-pentagonal hand-derivation failure mode -- and per the same discipline, a second, structurally similar temptation (the "shear-free" `L2'` rectangular-cell alternative) was tested and explicitly rejected with its own falsifying data point (81%, not 100%) rather than left as an untested "cleaner-looking" alternative.
- **Type consistency:** `_prismatic_pentagonal_tile()` takes no arguments, matching `_rhombille_tile()`/`_cairo_pentagonal_tile()`'s signature -- checked consistently throughout Task 1's wiring steps and the test file.
