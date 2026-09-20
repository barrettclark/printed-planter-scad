# Floret Pentagonal Tiling Pattern Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `"floret_pentagonal"` as a new `pattern_type` -- the floret pentagonal tiling (Wikipedia "V3^4.6", dual of the snub trihexagonal tiling), a tessellation by congruent, irregular pentagons arranged as rosettes of 6 pentagons pinwheeling around a degree-6 hub point (four 120-degree angles and one 60-degree angle per pentagon). Unlike `cairo_pentagonal`/`rhombille`, this pattern's 6-pentagon rosette has an obvious sub-structure to vary height across -- see "Relief Mode Decision" below -- so it **does** take a `relief_mode` parameter, alternating heights around the rosette in `"raised"` mode and flattening to one height in `"etched"` mode, the same decision framework the "kis" family uses.

**Architecture:** One new custom VNF tile function, `_floret_pentagonal_tile(relief_mode)`, built the same way `_cairo_pentagonal_tile()` is: a list of `[region, height]` islands (each island a translated copy of one of 6 pre-computed pentagon orientations, shrunk by half the groove width) fed to the existing `_tile_from_islands()` helper. The translation lattice this tiling actually needs is a **triangular (60-degree) lattice of hexagon-centers** -- structurally the same shape of lattice `tumbling_cubes`/`rhombille`/`kisrhombille` already normalize via their own `_TC_CENTERS`/`_TC_V` construction (a triangular lattice folds into a *centered rectangular* -- i.e. unit-square-with-a-center-point -- lattice under a pure rotation + the existing sqrt(3)-family anisotropic scale, no shear). This plan verified computationally (see "Geometry Derivation" below) that `floret_pentagonal`'s hexagon-center lattice folds the same way, so **no shear is needed** and this pattern does not require the `_tile_aspect_factor()` generalization the (declined) `prismatic_pentagonal` plan proposed. The anisotropic scale is baked directly into the final pentagon vertex coordinates (exactly like `tumbling_cubes`' `_TC_V` bakes its own sqrt(3)-family squish into its hexagon vertices), so `_floret_pentagonal_tile()` needs no separate aspect-correction bookkeeping at all -- it's built on `_UNIT_TILE` and treated as aspect-neutral by `_square_tile_vertical_reps()`, same as `rhombille`/`cairo_pentagonal`.

The pentagon shape, the translation lattice, and the affine transform to `_UNIT_TILE` space all come from a fully computationally-verified construction (see "Geometry Derivation" below) -- **do not re-derive this from scratch**. This construction was built from first principles (not copied from a secondary source's coordinates) because the floret pentagonal tiling's usual textbook description ("a hexagon divided into 6 pinwheeling pentagons") is not, by itself, enough to pin down exact vertex coordinates; the actual derivation here instead (1) constructed the *primal* snub trihexagonal tiling (regular hexagons + equilateral triangles, edge length 1, vertex figure 3.3.3.3.6 everywhere) directly from a hexagon-fan propagation rule, verified that construction closes up over a large patch with zero gaps/overlaps and the correct vertex figure everywhere, then (2) took the literal face-centroid dual (each dual pentagon's 5 vertices are the centroids of the 4 triangles + 1 hexagon surrounding one primal vertex, in cyclic order) and verified *that* over a large patch too, then (3) found the pentagon tiling's actual translation lattice, confirmed it is a plain 60-degree triangular lattice (not oblique in the shear-requiring sense -- see the definition below), and found the exact rotation + anisotropic-scale transform that normalizes it to `_UNIT_TILE` space with no shear.

**Tech Stack:** OpenSCAD 2021.01, BOSL2 (`lib/BOSL2/std.scad`), this repo's existing `modules/decoration.scad` VNF-tile infrastructure (`_tile_from_islands()`, `_UNIT_TILE`), Python 3 + `numpy` 2.5.3 + `shapely` 2.1.2 + `sympy` 1.14.0 (used only for this plan's own offline verification, not shipped).

**Spec:** No separate spec document -- this plan follows the same shape as `docs/superpowers/plans/2026-09-19-cairo-pentagonal-pattern.md` and `TODO.md`'s tessellation backlog entry for "Floret pentagonal tiling ... batch 3". The geometry itself is derived and verified in this plan's own "Geometry Derivation" section below, built from scratch (not sourced from a single worked example the way Cairo's Wikipedia "type 4" pentagon was), since no equivalently concrete worked-coordinate source was found for this specific tiling.

## Global Constraints

- New pattern name: `"floret_pentagonal"`, appended to `PATTERN_TYPES` immediately after `"cairo_pentagonal"` (the current last entry, confirmed by reading `modules/decoration.scad` fresh as of this plan) -- matches the file's existing append-at-the-end convention and `TODO.md`'s batch-3 ordering (prismatic pentagonal was declined -- see its own plan document -- so this is the next entry after Cairo pentagonal, skipping over the declined one).
- The tile is a VNF (not a BOSL2 texture string), added to `EXPECTED_VNF_PATTERN_TYPES` in `tests/test_decoration_pattern_types.scad`.
- The tile **is not** in `_ASPECT_EXCLUDED_PATTERNS` and **is not** in `_ASPECT_SQRT3_PATTERNS`, and this plan does **not** add or need `_tile_aspect_factor()`/any new aspect-correction mechanism -- unlike the declined `prismatic_pentagonal` construction, this pattern's own affine map to `_UNIT_TILE` space is a rotation + anisotropic scale that gets baked directly into the pentagon vertex coordinates below (see Geometry Derivation, Step 5), the same way `tumbling_cubes`' `_TC_V` bakes its own hexagon-squish into vertex coordinates rather than relying on a runtime correction. The tile is therefore treated by `_square_tile_vertical_reps()` exactly like `rhombille`/`cairo_pentagonal` -- no code changes needed there.
- Unlike `rhombille`/`cairo_pentagonal` (uniform height, no `relief_mode` parameter), `_floret_pentagonal_tile()` **does** take a `relief_mode` parameter, matching the "kis" family's signature -- see "Relief Mode Decision" below for why this pattern's 6-pentagon rosette genuinely has the sub-structure the "kis" family's decision framework requires, unlike Cairo/rhombille's single-flat-face situation.
- Use gap `0.05` (own named constant `_FP_GAP`, following this repo's convention of never sharing another pattern's groove-width constant even at the same numeric value as `_KIS_GAP`/`_TC_GAP`/`_RH_GAP`/`_CP_GAP`).
- CGAL-fragility warning: add `"floret_pentagonal"` directly to the **"known to abort"** bucket in `decorated_solid()`'s CGAL warning `echo()` (alongside `tumbling_cubes`/`intertwine`/`islamic_star`/`rhombille`/`cairo_pentagonal`), **not** the milder "measured clean everywhere" bucket -- unlike Cairo pentagonal's plan (which started in the milder bucket because it had no evidence of failure yet), this plan's own smoke test (Geometry Derivation, "OpenSCAD/BOSL2 verification" below) already reproduced a real CGAL assertion abort in `"raised"` mode at both `pattern_repeat=12`/`smoothness=50` and at settings close to the shipped defaults (`pattern_repeat=16`/`smoothness=60`), while `pattern_repeat=4`/`smoothness=24` (raised) and `pattern_repeat=12`/`smoothness=50` (etched) rendered clean. This tile has **18** island pieces per unit tile after clipping (more than `cairo_pentagonal`'s 8, and the most of any custom VNF tile in this file), each still a single flat pentagon facet with wide chords across the wall's curvature -- the same wide-arc-chord failure mechanism as `tumbling_cubes`/`rhombille`/`cairo_pentagonal`, not the "kis" family's small-triangle-facet safety. Task 1's own CGAL-sweep step must still independently re-measure across a full `pattern_repeat`/`smoothness` grid in both relief modes (matching `cairo_pentagonal`'s Step 8 methodology) -- this plan's starting-bucket placement is a documented finding, not a substitute for that sweep, and the shipped defaults may need a re-pin in `.github/workflows/test.yml` (see Step 9 below).
- README.md's `pattern_type` parameter table, the "N of the pattern_type values are interlocking" enumeration (currently names `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`, `"rhombille"`, `"cairo_pentagonal"` explicitly), and the CGAL-fragility section must all be updated by name.
- `docs/gallery.md` needs a new subsection (raised + etched example renders) following the exact structure of the `cairo_pentagonal` subsection.
- `.github/workflows/test.yml`'s several pattern-type loops must include `"floret_pentagonal"`.
- `planter.scad`'s Customizer dropdown comment for `pattern_type` must be updated too -- a past PR review caught this being forgotten twice already; do not repeat it a third time.
- `tests/test_decoration_etched_groove.scad`: because this pattern's raised and etched tiles are genuinely **different** VNFs (see Relief Mode Decision), `"floret_pentagonal"` goes in that file's `KIS_PATTERN_TYPES`-style category, **not** `VNF_PATTERN_TYPES` -- check that file's current structure (as of this plan, `KIS_PATTERN_TYPES = ["tetrakis_square", "kisrhombille", "triakis_triangular"]`) and either add `"floret_pentagonal"` to that list directly (if its per-pattern checks are generic enough) or add a parallel block for it, following whichever the current file structure actually supports -- read the file fresh in Task 1 Step 6, don't assume the exact list shape from this plan alone.
- `tests/test_decoration_tile_aspect.scad`'s VNF-tile list (the plain-square-tile-formula loop) must gain `"floret_pentagonal"` -- it uses the ordinary formula like every other custom VNF tile (no new aspect category, per the Global Constraints point above).

### What "rectangular lattice" means here, and why this pattern qualifies

The task that produced this plan drew a hard line: a translation lattice is acceptable for this project only if it can be normalized to `_UNIT_TILE` space via **rotation + anisotropic scale**, never a genuine **shear**. The declined `prismatic_pentagonal` plan hit a lattice whose two generators were neither perpendicular nor equal length (`L1=(1,0)`, `L2=(0.5,1+h)`), which cannot be sent to `(1,0)`/`(0,1)` without a shear term (an off-diagonal component that survives no matter how the map is pre-rotated).

`floret_pentagonal`'s natural translation lattice, by contrast, has **two equal-length generators at exactly 60 degrees** (see Geometry Derivation, Step 3: `|L1|=|L2|=sqrt(7)`, angle exactly 60 degrees) -- a *triangular* lattice, not an oblique one in the disqualifying sense. A triangular lattice is the **same shape of lattice** `tumbling_cubes`/`rhombille`/`kisrhombille` already use for their own hexagon centers (also two equal-length generators at 60 degrees), and this project has already established, in those three patterns' own shipped code, that this specific lattice shape folds into a `_UNIT_TILE`-compatible centered-rectangular lattice via a pure rotation followed by the same sqrt(3)-family anisotropic Y-scale `_ASPECT_SQRT3_PATTERNS` uses elsewhere -- no shear. This plan re-derives and re-verifies that fold for `floret_pentagonal`'s own specific lattice (Geometry Derivation, Step 4) rather than assuming it by analogy, per the task's explicit instruction to verify this for the specific tiling at hand.

## Geometry Derivation

This section is the load-bearing evidence for the implementer: exact coordinates, the exact affine transform to `_UNIT_TILE` space, and a description of the independent verifications run (Python/shapely/sympy closure proofs at multiple stages, and a live OpenSCAD/BOSL2 smoke test of the real `_tile_from_islands()` code path) with their results. Task 1 below re-states the final OpenSCAD constants/functions verbatim; this section is where they came from and why they're correct.

### Step 1: building and verifying the primal snub trihexagonal tiling

No single concrete worked-coordinate source was available for this tiling the way Wikipedia's Cairo pentagonal "type 4" pentagon was for `cairo_pentagonal`, so the primal tiling was constructed directly from its combinatorial definition (Wikipedia "V3.3.3.3.6": at every vertex, 4 equilateral triangles and 1 regular hexagon, all edge length 1) using a hexagon-fan propagation rule, then verified, rather than assumed:

- Hexagon centers were placed at `C(m,n) = m*L1 + n*L2` for integers `m,n`, where `L1 = (sqrt(3), 2)` and `L2 = rotate(L1, 60 degrees)` -- **verified exactly** (`sympy`, exact radicals): `|L1| = |L2| = sqrt(7)` and the angle between them is exactly 60 degrees. Every hexagon has the **same absolute orientation** (vertices at angles `30 + 60k` degrees from its own center, `k=0..5`, radius 1) -- this was *derived*, not assumed: working out the exterior 240-degree, 4-triangle fan around one hexagon vertex `v0` by hand (each of the 4 triangles spans exactly 60 degrees since consecutive unit-length rays 60 degrees apart automatically close into an equilateral triangle) produces a new point `p_b` at exactly `2 * v0` (i.e. twice `v0`'s own distance and angle from the hexagon center) that must belong to a *different* hexagon's own vertex set; solving for that neighboring hexagon's center from 3 of its own already-known vertices gives `C = (sqrt(3), 2)` at distance exactly `|C| = sqrt(3+4) = sqrt(7)` from the origin hexagon's center, oriented with vertices at the *same* `30+60k` angle pattern (i.e. relative rotation `0 mod 60 degrees` -- no rotation between hexagons, only translation).
- Given this hexagon lattice, the 4 exterior triangles at every hexagon vertex were generated by the same fan rule (rays at `theta-60, theta, theta+60` degrees from the vertex, where `theta` is that vertex's own outward radial angle relative to its hexagon's center) and deduplicated by quantized vertex coordinates.
- **Verified (Python/numpy, patch of hexagon lattice steps `m,n` in `[-6,6]`, 169 hexagons, 1506 unique triangles):** every one of 754+ generated triangles has all 3 edges of length exactly 1 (to floating-point precision) -- zero exceptions. The union of all hexagon and triangle face polygons (quantized to 1e-9 before the boolean, for the same reason `_tile_q()` exists in this project's own code) has area **exactly equal** to the sum of the individual face areas (zero overlap), forms a **single connected polygon** (not a `MultiPolygon`), and has **zero interior holes**. A 150-vertex core sample (hexagon steps `m,n` in `[-2,2]`, safely inside the margin of the larger generated patch) was checked directly for vertex figure: **all 150 have degree exactly 5, with exactly 1 hexagon and exactly 4 triangles** -- the `3.3.3.3.6` vertex figure holds everywhere checked, not just near the origin.

This confirms the primal tiling (before taking its dual) is a valid, gapless snub trihexagonal tiling.

### Step 2: the dual pentagon, built directly from face data

For each of the 150 core vertices, the incident faces (1 hexagon + 4 triangles) were collected, their centroids computed, and connected in the cyclic order given by sorting each centroid's angle around the vertex -- the standard face-centroid dual construction, the same method the (declined) `prismatic_pentagonal` plan used for its own dual.

**Verified (Python/shapely, all 150 core-vertex pentagons):** every pentagon has area **exactly** `1.0103629710818451` (matching to floating-point precision across all 150, std deviation `~4e-16`) -- this equals `1/6` of a hexagon's area (`(3*sqrt(3)/2)/6`) plus `4/3` of a triangle's area (`(sqrt(3)/4)*4/3`), consistent with each vertex "owning" 1/6 of its hexagon and 1/3 of each of its 4 triangles. The union of all 150 pentagons (quantized to 1e-9) has area **exactly equal** to the sum of individual areas (zero overlap), forms a **single connected polygon**, and has **zero interior holes**.

One representative pentagon (relative to its own hub vertex, in the *original*, pre-normalization coordinate system) has 4 interior angles of 120 degrees and 1 of 60 degrees at the hub (matching the `V3^4.6` vertex-configuration literature description exactly: 4 threes and a six around the dual vertex, i.e. 4 triangle-derived 120-degree corners and 1 hexagon-derived 60-degree hub corner in this specific centroid-dual construction).

### Step 3: the translation lattice

Since the entire construction (hexagon lattice, triangle fans, dual pentagons) is translation-covariant under `L1`/`L2` (every hexagon has the identical absolute orientation, so translating the whole complex by `L1` or `L2` maps hexagon `(m,n)` onto hexagon `(m+1,n)`/`(m,n+1)` exactly, carrying its vertex-pentagons along with it), `L1` and `L2` are themselves the pentagon tiling's own translation lattice generators -- no separate re-derivation needed. This was still checked directly: `L1 = (sqrt(3), 2)`, `L2 = (-sqrt(3)/2, 5/2)` (`L1` rotated 60 degrees), **both length exactly `sqrt(7)`, angle between them exactly 60 degrees** (verified with `sympy` exact radicals). The primitive cell area is `|det(L1,L2)| = 7*sin(60) = 7*sqrt(3)/2`, and `6` pentagons (one full hexagon's worth of rosette) fit per primitive cell (`7*sqrt(3)/2 / 1.0103629710818451 = 6.0000...` to floating precision) -- consistent with "1 hexagon (hence 1 rosette of 6 pentagons) per primitive cell."

**This is a triangular (60-degree, equal-length-generator) lattice, not an oblique one in the shear-requiring sense** -- see "What 'rectangular lattice' means here" above.

### Step 4: the affine transform to `_UNIT_TILE` space -- rotation + anisotropic scale, no shear

Define `T` as: rotate by `-angle(L1)` (so `L1` aligns with the x-axis), then scale x by `1/sqrt(7)` (so `|L1| -> 1`), then scale y by an *additional* `1/sqrt(3)` (the same sqrt(3)-family Y-squish `_ASPECT_SQRT3_PATTERNS` uses elsewhere in this file, here applied by construction rather than as a runtime correction). By construction this sends:

```
T(L1) = (1, 0)
T(L2) = (0.5, 0.5)
```

**Verified exactly in closed form:**

```
T(x, y) = ( (sqrt(3)*x + 2*y) / 7,  (3*y - 2*sqrt(3)*x) / 21 )

T(L1) = T(sqrt(3), 2) = ( (3+4)/7, (6-6)/21 ) = (1, 0)          -- exact
T(L2) = T(-sqrt(3)/2, 5/2) = ( (-3/2+5)/7, (15/2+3)/21 ) = (1/2, 1/2)   -- exact
```

`T` is a **pure linear map with no shear when expressed as rotate-then-axis-scale** (it was built by construction as `diag(1/sqrt(7), 1/(sqrt(7)*sqrt(3))) . R(-theta1)`, exactly the same 3-parameter "rotate, then scale two axes independently" form `_ASPECT_SQRT3_PATTERNS`'s own mechanism uses, generalized only in that the rotation angle here, `theta1 = atan2(2, sqrt(3))`, is not a multiple of 90 degrees the way Cairo's was -- but it is *still just a rotation*, not a shear, and the anisotropic scale factor is the *same* `sqrt(3)` this file already uses for `cubes`/`hex_grid`/`tri_grid`). This is baked directly into the final pentagon vertex coordinates below (Step 5), so **no runtime aspect correction is needed** -- exactly like `tumbling_cubes`' `_TC_V` already bakes its own squish into vertex coordinates rather than calling out to `_square_tile_vertical_reps()`'s sqrt(3) mechanism.

`T(lattice generated by L1, L2)` equals the set `{(a, b) : a-0.5b in Z, b in 0.5*Z}`... concretely, the **true** period lattice in normalized space is generated by `(1,0)` and `(0.5,0.5)` (finer than the unit-square lattice `Z^2` this project's `_UNIT_TILE` convention repeats by), with `Z^2` an index-2 sublattice of it -- **exactly** the same "5 hexagon centers per unit tile" relationship `tumbling_cubes`/`rhombille`'s own `_TC_CENTERS = [[0,0],[1,0],[0,1],[1,1],[0.5,0.5]]` already encodes. This was verified directly (not just by the general area-ratio argument): mapping the hexagon lattice steps `(m,n)` for `(0,0)`, `(1,0)`, `(0,1)`, `(1,1)` and `(0.5,0.5)` through `T` gives exactly:

```
(m,n)=(0,0)  -> T(hexcenter) = (0, 0)
(m,n)=(1,0)  -> T(hexcenter) = (1, 0)
(m,n)=(-1,2) -> T(hexcenter) = (0, 1)
(m,n)=(0,2)  -> T(hexcenter) = (1, 1)
(m,n)=(0,1)  -> T(hexcenter) = (0.5, 0.5)
```

(all verified exactly with `sympy`), confirming the 5 canonical hub positions for a `_TC_CENTERS`-style covering are `(0,0)`, `(1,0)`, `(0,1)`, `(1,1)`, `(0.5,0.5)` -- **identical** to `_TC_CENTERS` itself.

### Step 5: the 6 base pentagon shapes (relative to a hub at the origin)

Applying `T` to hexagon `(0,0)`'s own 6 vertex-pentagons (built via Steps 1-2's fan/dual construction, then transformed) gives 6 exact-fraction pentagons, **all rational -- no `sqrt(3)` survives in the final coordinates** (verified with `sympy`, then independently cross-checked against the floating-point pipeline). Each pentagon's first-listed vertex below is the shared hub `(0,0)` (the transformed hexagon centroid, common to all 6):

```
_FP_P0 = [[0,0], [2/7,-4/21], [1/2,-1/6], [4/7,-1/21], [3/7,1/21]]
_FP_P1 = [[0,0], [3/7,1/21], [1/2,1/6], [5/14,11/42], [1/7,5/21]]
_FP_P2 = [[-2/7,4/21], [0,0], [1/7,5/21], [0,1/3], [-3/14,13/42]]
_FP_P3 = [[-4/7,1/21], [-3/7,-1/21], [0,0], [-2/7,4/21], [-1/2,1/6]]
_FP_P4 = [[-1/2,-1/6], [-5/14,-11/42], [-1/7,-5/21], [0,0], [-3/7,-1/21]]
_FP_P5 = [[-1/7,-5/21], [0,-1/3], [3/14,-13/42], [2/7,-4/21], [0,0]]
```

**Verified exactly** (`sympy` shoelace and OpenSCAD `polygon_area()`, cross-checked): each of the 6 has area **exactly `1/12`** (6 pentagons * 1/12 = 1/2 = the transformed primitive cell area, matching Step 3/4's area-ratio prediction), each is **convex**, and each is wound **CCW** (`polygon_area(..., signed=true)` returns `+0.0833333` for all 6 -- unlike Cairo's construction, this transform does not flip winding, since a pure rotation + *positive* anisotropic scale preserves orientation).

`_FP_P3`, `_FP_P4`, `_FP_P5` are each the point-set of `_FP_P0`, `_FP_P1`, `_FP_P2` respectively, negated and cyclically re-listed -- an expected consequence of the original (pre-transform) hexagon+fan construction being symmetric under 180-degree rotation about the hub (a regular hexagon is itself 180-degree symmetric about its center, and the fan construction is rotation-covariant), carried through by `T`'s own linearity (`T(-p) = -T(p)`). This is recorded as a sanity-check fact, not relied upon in the code below -- all 6 are listed as independent literals, matching this project's existing convention (`cairo_pentagonal` lists all 4 of its pentagons as independent literals too, even though they are related by a 90-degree rotation in the *original*, pre-transform space).

### Step 6: covering the unit tile -- which translated copies are needed

Analogous to `cairo_pentagonal`'s 8-placement search (Cairo's own plan, Step 4) and `tumbling_cubes`/`rhombille`'s 5-hub `_TC_CENTERS` search, but here with 5 hubs times 6 orientations = up to 30 candidate pentagons per hub-neighborhood search.

**Exhaustively searched (Python/shapely):** every hexagon within `T`-image range `[-1.2, 2.2] x [-1.2, 2.2]` of the unit square (25 hexagons, 150 candidate pentagons total) was clipped against `[0,1] x [0,1]`; **exactly 18** placements have nonzero clipped area. The initial narrower search (using only the 5 exact canonical hub positions, no neighbors) came up short (sum of clipped areas `0.988`, not `1.0`) until the search range was widened to include 2 more hexagons whose hubs are the canonical `(0.5,0.5)` position shifted by `(-1,0)` and `(+1,0)` -- directly analogous to how `cairo_pentagonal`'s own derivation needed lattice steps beyond the "obvious" minimal set (its Step 4 searched `m,n` in `[-2,2]`, not just `[-1,1]`) to find its complete 8-placement covering; the same caution applies here and this plan's own search was widened from `[-2,2]` (hexagon-lattice steps, not the final 5-hub search which additionally needed a 2-hexagon-wider net) until the found set stopped growing.

**Sum of clipped areas = exactly `1.0`** (verified both in floating point and, independently, with **exact `Fraction` arithmetic** -- no floating-point tolerance involved in the final area-equality check), the union of the 18 clipped pieces equals the unit square **exactly** (`unit_square.symmetric_difference(union).area == 0.0`), forms a **single connected polygon** with **zero interior holes**, and has **zero pairwise overlap** among the 18 pieces (checked all `C(18,2)=153` pairs directly).

The 18 placements, each `[dx, dy, k]` (translate `_FP_P{k}` by `(dx, dy)`):

```
(dx, dy, k)      clipped-to-unit-square area (exact fraction)
(-1/2, 1/2, 0)   1/168
(0, 1, 0)        6/84 = 1/14
(0, 1, 5)        5/84
(0, 0, 0)        1/84
(0, 0, 1)        1/12  (whole pentagon, entirely inside)
(0, 0, 2)        2/84
(1/2, 1/2, 0)    13/168
(1/2, 1/2, 1)    1/12
(1/2, 1/2, 2)    1/12
(1/2, 1/2, 3)    13/168
(1/2, 1/2, 4)    1/12
(1/2, 1/2, 5)    1/12
(1, 1, 3)        1/84
(1, 1, 4)        1/12
(1, 1, 5)        2/84
(1, 0, 2)        5/84
(1, 0, 3)        6/84 = 1/14
(3/2, 1/2, 3)    1/168
```

(Individual fractions above are given to the precision they were spot-checked at; the load-bearing, fully-exact fact is the **sum** and the **union/overlap/hole** checks, all confirmed with exact `Fraction` arithmetic, not the individual per-piece values.)

**Twin-vertex-on-opposite-edges invariant, checked directly with exact `Fraction` coordinates (no floating-point tolerance):** collecting every vertex of the 18 clipped pieces lying exactly on `x=0`, `x=1`, `y=0`, or `y=1` gives:

```
x=0 and x=1 edges: both {0, 1/3, 1/2, 2/3, 1}   (5 points each, exact match)
y=0 and y=1 edges: both {0, 1/2, 1}              (3 points each, exact match)
```

This is the exact invariant `_tile_from_islands()`/BOSL2 depend on for stitching repeats together, confirmed exactly (not approximately) for this construction.

**Wider-patch confirmation (4x4 tile patch, per-cell clipping, matching how `_tile_from_islands()`/BOSL2 actually repeat the tile):** placing the same 18 pentagons at every integer `(i,j)` offset for `i,j` in `[0,4)`, clipping each translated pentagon to its own unit cell `[i,i+1] x [j,j+1]` (exactly what happens per texture repeat at render time), and unioning all resulting pieces: total area **exactly `16.0`** (matching `4*4`), a **single connected polygon**, **zero interior holes**, **zero pairwise overlap**, and symmetric difference against the `4x4` bounding box of **exactly `0.0`**. This directly confirms the tile repeats correctly across multiple copies, not just that one isolated tile closes up.

### Step 7: OpenSCAD/BOSL2 verification (not just Python)

Verified directly with a throwaway OpenSCAD script that includes the real `modules/decoration.scad`, defines `_FP_P0`..`_FP_P5`/`_FP_PLACEMENTS` exactly as in Steps 5-6 above, builds the islands list with `offset(poly, delta=-_FP_GAP/2, closed=true)` (gap `0.05`) feeding the real, unmodified `_tile_from_islands()`, and asserts on the result (`openscad -o /tmp/floret_smoke.stl <script>`):

- `polygon_area(_FP_P{k}, signed=true)` for `k=0..5`: all exactly `0.0833333` (`1/12`, positive/CCW, matching Step 5's prediction).
- `_tile_from_islands(islands)` (the real function, unmodified) produced `is_vnf(tex) == true` for both `_floret_pentagonal_tile("raised")` and `_floret_pentagonal_tile("etched")`.
- `pointlist_bounds(tex[0])` = exactly `[[0,0,0],[1,1,1]]` for the raised tile.
- The twin-vertex check (`_tile_edge_profile()` helper, same as other tile tests) gave **identical** point lists for the `x=0`/`x=1` edges (18 points each) and for the `y=0`/`y=1` edges (10 points each), exact match both times, on the real VNF this function actually produces.
- Z-level check: `unique([for (p = tex[0]) p[2]])` gave `[0, 0.45, 1]` for `"raised"` (ground, low pentagon, high pentagon) and `[0, 1]` for `"etched"` (ground, uniform pentagon height) -- confirming the two relief modes really do produce different VNFs, as the Relief Mode Decision below requires.
- A full real-render smoke test: `cyl(h=100, r1=75, r2=60, $fn=50, texture=tex, tex_reps=[12,8], tex_depth=1.5, tex_inset=false)` differenced against a disjoint cube (forcing real CGAL Nef-polyhedron evaluation): the geometry itself built as a **valid manifold** (`Simple: yes`, `Volumes: 2`, matching the expected result of a difference against a disjoint cube), but the `difference()` operation itself **printed a CGAL assertion error** (`CGAL error: assertion violation! ... SNC_external_structure.h ... difference`) and OpenSCAD still exited 0 and wrote a 16MB STL -- **exactly** the documented failure mode this project's own CGAL-warning `echo()` describes for `tumbling_cubes`/`intertwine`/`islamic_star`/`rhombille`/`cairo_pentagonal`. The **same** script with `relief_mode="etched"` (same `pattern_repeat`/`smoothness`) rendered **clean**, and a reduced `pattern_repeat=4`/`smoothness=24` **raised** run also rendered **clean**, but a run at settings matching the shipped defaults (`pattern_repeat=16`, `smoothness=60`, raised) **also aborted**. This one-configuration-family result already crosses the line into "known to abort" (see Global Constraints above) -- it is not a full sweep (Task 1's own CGAL-sweep step is not optional on the strength of this alone), but it is stronger and more specific evidence than Cairo's own initial smoke test had (Cairo's first smoke test was clean; this one was not).

### Relief Mode Decision

**Recommendation: `relief_mode`-DEPENDENT geometry -- alternate 2 heights around the 6-pentagon rosette in `"raised"` mode (matching the "kis" family's own alternating-heights convention), flatten to one uniform height in `"etched"` mode.**

Reasoning, following the exact decision framework `cairo_pentagonal`'s own plan used, but reaching the opposite conclusion for the opposite reason the task's own briefing invited scrutiny of: the "kis" family's raised/etched split exists because each of *their* tile cells is itself a multi-triangle fan (a kis-operation result) with an obvious sub-structure to vary height across. `cairo_pentagonal`/`rhombille` do **not** get this split because a single Cairo pentagon or rhombille rhombus is one flat convex face with no natural sub-fan.

`floret_pentagonal`'s situation is structurally different from both: **each rosette genuinely is a 6-way fan around a shared hub**, directly analogous to the "kis" family's own N-way fans around a shared centroid (`tetrakis_square`'s 4-triangle fan, `kisrhombille`'s 4-triangle-per-rhombus fans, `triakis_triangular`'s 3-triangle fans) -- just with pentagons instead of triangles as the fan blades, and a hub vertex instead of a face centroid at the fan's center. Since `6` is even (unlike `triakis_triangular`'s odd 3-fan, which uses 3 distinct heights instead of alternation), a clean 2-height alternation (`k` even -> high, `k` odd -> low, using `_FP_PLACEMENTS`' own `k` index, which is consistent across every hub instance since all hubs share the identical 6-orientation set) produces a true alternating pinwheel-blade look, the same visual effect `tetrakis_square`/`kisrhombille`'s own alternation produces for their 4-fans. This was implemented and verified in Step 7 above (`[1.0, 0.45, 1.0, 0.45, 1.0, 0.45]` in tile-orientation order, using the *same* low-height constant `0.45`... actually, per this project's own-constant convention (see Global Constraints), this pattern gets its **own** low-height constant even though it happens to match `tetrakis_square`'s numeric value -- see `_FP_Z_LO` in Task 1).

`"etched"` mode flattens every pentagon in the rosette to the tile's full height `1.0` (matching the "kis" family's own etched behavior: "a completely separate flat-panel VNF with only a thin engraved groove between the fan triangles, not an inverted copy of the raised relief" -- README.md's own wording for the kis family, quoted here because it applies verbatim to this pattern's own etched mode too), giving the requested "engraved into stone or glass" look (TODO.md) as a clean pentagon mosaic with incised grooves, rather than either an alternating-height bump pattern turned upside-down (which would look like a confusing mix of raised and sunken facets, not a clean engraving) or a flat panel that quietly discards the rosette's own defining structure.

## Task 1: `_floret_pentagonal_tile()` -- geometry, wiring, tests, docs

**Files:**
- Modify: `modules/decoration.scad` (add `_FP_P0`..`_FP_P5`, `_FP_PLACEMENTS`, `_FP_GAP`, `_FP_Z_HI`, `_FP_Z_LO`, `_fp_pentagon()`, `_floret_pentagonal_tile(relief_mode)`; extend `PATTERN_TYPES`; extend `_decoration_texture()`; extend the CGAL-warning `echo()` "known to abort" pattern list in `decorated_solid()`)
- Create: `tests/test_decoration_floret_pentagonal.scad`
- Modify: `tests/test_decoration_pattern_types.scad` (extend `EXPECTED_PATTERN_TYPES` and `EXPECTED_VNF_PATTERN_TYPES`)
- Modify: `tests/test_decoration_etched_groove.scad` (add `"floret_pentagonal"` to the kis-style "different VNF per relief mode" category -- read the file fresh to confirm its exact current shape before editing, per the Global Constraints note above)
- Modify: `tests/test_decoration_tile_aspect.scad` (extend the plain-formula VNF-tile `for` loop's pattern list)
- Modify: `.github/workflows/test.yml` (add `"floret_pentagonal"` to every pattern-type loop; add it to the "known to abort" reduced-value combo list and re-pin the shipped-defaults check if the sweep confirms the defaults are unsafe)
- Modify: `planter.scad` (Customizer dropdown comment for `pattern_type`)
- Modify: `README.md` (parameter table, interlocking-patterns enumeration, CGAL section)
- Modify: `docs/gallery.md` (new subsection + regenerated images via `docs/images/render.sh`)
- Modify: `TODO.md` (check off the Floret pentagonal line)

**Interfaces:**
- Consumes: `_tile_from_islands(islands)`, `_UNIT_TILE` -- both existing, defined in `modules/decoration.scad`'s "Shared plateau-tile builder" section.
- Produces: `_floret_pentagonal_tile(relief_mode)` (takes `relief_mode`, unlike `_rhombille_tile()`/`_cairo_pentagonal_tile()` -- matches the "kis" family's `_foo_tile(relief_mode)` shape, per the Relief Mode Decision above). `_decoration_texture(pattern_type, relief_mode)` gains one more branch: `pattern_type == "floret_pentagonal" ? _floret_pentagonal_tile(relief_mode) :`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_decoration_floret_pentagonal.scad`, following `tests/test_decoration_cairo_pentagonal.scad`'s structure but adapted for a `relief_mode`-dependent tile (compare against how the existing "kis" family test files, e.g. `tests/test_decoration_tetrakis_square.scad`, structure their raised-vs-etched checks -- read one of those fresh before writing this file, since this pattern's raised/etched split needs the same kind of "different VNF, different Z-levels, still both valid" assertions those files already have, not Cairo's "identical VNF in both modes" assertion):

```openscad
// tests/test_decoration_floret_pentagonal.scad
//
// "floret_pentagonal" is a custom VNF tile (the floret pentagonal tiling,
// Wikipedia "V3^4.6" -- 6-pentagon pinwheel rosettes, dual of the snub
// trihexagonal tiling), not a BOSL2 texture name, so it needs a real-render
// check: a tile whose points leave the unit square, whose edges don't line
// up across the tile boundary, or whose walls are wound backwards only fails
// when the geometry is actually evaluated.
//
// Unlike cairo_pentagonal/rhombille, this pattern's raised and etched tiles
// are genuinely DIFFERENT VNFs (alternating heights around the rosette vs. a
// flat uniform-height mosaic) -- matching the "kis" family's own signature,
// not the uniform-height patterns' signature. See this pattern's plan
// document's "Relief Mode Decision" for the reasoning.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("floret_pentagonal", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"floret_pentagonal\"");

_tex_raised = _decoration_texture("floret_pentagonal", "raised");
_tex_etched = _decoration_texture("floret_pentagonal", "etched");
assert(is_list(_tex_raised) && len(_tex_raised) == 2,
    "_decoration_texture(\"floret_pentagonal\", \"raised\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex_raised), "_decoration_texture(\"floret_pentagonal\", \"raised\") must be a valid VNF");
assert(is_vnf(_tex_etched), "_decoration_texture(\"floret_pentagonal\", \"etched\") must be a valid VNF");

// Raised and etched must be DIFFERENT VNFs here -- the opposite of
// cairo_pentagonal/rhombille, matching the "kis" family instead: this
// pattern's 6-pentagon rosette has a real sub-structure (heights alternate
// around it) that etched mode flattens away, per the plan's Relief Mode
// Decision.
assert(_tex_raised != _tex_etched,
    "floret_pentagonal's raised and etched tiles must differ -- this pattern alternates heights around the rosette like the \"kis\" family, unlike cairo_pentagonal/rhombille");

// A VNF texture tile's footprint must lie inside the unit square with Z in
// [0,1]; BOSL2 rejects anything else at render time.
_bounds = pointlist_bounds(_tex_raised[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("floret_pentagonal tile must fit in the unit cube, got bounds ", _bounds));
assert(approx(_bounds[0][0], 0) && approx(_bounds[0][1], 0) &&
       approx(_bounds[1][0], 1) && approx(_bounds[1][1], 1),
    str("floret_pentagonal tile should reach every edge of the unit square exactly, got bounds ", _bounds));

// VNF tiles take no `style` (that's a heightfield-triangulation setting), and
// _decoration_style() must reach that answer from the resolved texture rather
// than from a pattern_type-specific branch.
assert(_decoration_style("floret_pentagonal", "raised") == undef,
    "floret_pentagonal is a VNF tile and must not carry a style override");
assert(_decoration_style("floret_pentagonal", "etched") == undef,
    "floret_pentagonal is a VNF tile and must not carry a style override when etched");

// Raised mode alternates 2 heights around each 6-pentagon rosette (this
// pattern's own low-height constant, distinct from tetrakis_square's/
// kisrhombille's even though it happens to share the same numeric value --
// see modules/decoration.scad's convention note on _FP_GAP/_FP_Z_LO).
// Etched mode flattens every pentagon to the tile's full height.
assert(_FP_Z_HI == 1, str("floret_pentagonal's high rosette height must be 1, got ", _FP_Z_HI));
_zs_raised = unique([for (p = _tex_raised[0]) p[2]]);
_zs_etched = unique([for (p = _tex_etched[0]) p[2]]);
assert(_zs_raised == [0, _FP_Z_LO, 1],
    str("floret_pentagonal raised VNF must use exactly 3 Z levels (ground, low, high), got ", _zs_raised));
assert(_zs_etched == [0, 1],
    str("floret_pentagonal etched VNF must use exactly 2 Z levels (ground, uniform full height), got ", _zs_etched));

// The invariant the whole tile design rests on: every vertex the tile leaves
// on one edge needs a twin at the same position on the opposite edge, or
// repeats don't stitch and the surface leaks. Rendering without an error is a
// weak proxy for this -- BOSL2 only enforces it for vertices sitting on
// *open* edges, and a near-miss (an edge resampled at a slightly different
// point, an off-by-epsilon coordinate) can still render while producing a
// subtly non-tiling mesh. So compare the two edges directly. Checked on both
// relief-mode tiles since they're genuinely different VNFs.
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (tex = [_tex_raised, _tex_etched]) {
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(tex, axis, 0);
        hi = _tile_edge_profile(tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        // The shipped VNF (post-_FP_GAP groove shrink) has 18 points on the
        // x=0/x=1 edges and 10 points on the y=0/y=1 edges -- see
        // tests/test_decoration_floret_pentagonal.scad's own comment. (The
        // plan's Geometry Derivation, Step 6, found 5/3 for the PRE-groove
        // polygon corners -- a different, smaller count that does not apply
        // to this post-offset() VNF.) Either way, well beyond the 2 tile
        // corners alone, so more than 2 is what proves a pentagon genuinely
        // spans the seam, not just touches at a corner.
        assert(len(lo) > 2,
            str("floret_pentagonal tile has only ", len(lo), " vertices on its ", name,
                "=0 edge -- no pentagon spans the seam"));
        assert(len(lo) == len(hi),
            str("floret_pentagonal tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("floret_pentagonal tile ", name, " edge vertices don't line up: ", mismatched));
    }
}

difference() {
    decorated_solid("floret_pentagonal", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}

difference() {
    decorated_solid("floret_pentagonal", "vertical", "etched", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
openscad -o /tmp/test.csg tests/test_decoration_floret_pentagonal.scad
```
Expected: FAIL -- `"floret_pentagonal"` is not yet in `PATTERN_TYPES` (ERROR: Assertion failed at the `in_list` check).

- [ ] **Step 3: Add the tile geometry to `modules/decoration.scad`**

Insert a new section immediately after the existing `_cairo_pentagonal_tile()` function (right before the `"--- Kisrhombille"` comment block), so the two most recently added tiles sit next to each other in file order:

```openscad
// --- Floret pentagonal (dual of the snub trihexagonal tiling) --------------
//
// Wikipedia "V3^4.6": rosettes of 6 congruent, irregular pentagons pinwheel
// around a shared hub point where all 6 meet (four 120-degree angles and one
// 60-degree angle per pentagon, the 60-degree angle always at the hub).
// Unlike cairo_pentagonal/rhombille, each rosette IS a multi-facet fan around
// a shared point -- structurally the same shape as the "kis" family's own
// N-way fans, just with pentagons instead of triangles and a hub vertex
// instead of a face centroid -- so this pattern DOES take a relief_mode
// parameter and alternates 2 heights around the rosette in "raised" mode,
// like tetrakis_square/kisrhombille's own even-fan alternation. See this
// pattern's plan document (docs/superpowers/plans/2026-09-20-floret-pentagonal-pattern.md)
// for the full derivation and the computational verification this
// construction is based on (a from-scratch snub-trihexagonal-tiling
// construction verified over a 150-vertex patch, its face-centroid dual
// verified the same way, an exact-Fraction lattice-covering/closure proof
// including a wider 4x4-tile-patch confirmation, plus a live OpenSCAD/BOSL2
// smoke test of this exact code path) -- do not re-derive the lattice by
// hand; it was verified, not guessed.
//
// The hexagon-center lattice underlying this tiling is a plain 60-degree
// TRIANGULAR lattice (two generators, equal length, 60 degrees apart) --
// the SAME shape of lattice tumbling_cubes/rhombille/kisrhombille already
// use for their own hexagon centers (_TC_V/_TC_CENTERS), which is why this
// pattern needs no shear and no new aspect-correction mechanism: like
// tumbling_cubes' _TC_V, the rotation + sqrt(3)-family anisotropic scale
// that normalizes this lattice to _UNIT_TILE space is baked directly into
// the pentagon vertex coordinates below, not applied at render time. The 5
// hub positions below are exactly _TC_CENTERS' own 5 positions -- verified,
// not assumed by analogy.
//
// _FP_P0.._FP_P5 are the tiling's 6 pentagon orientations (the full rosette
// around one hub), already normalized into unit-tile space, each listed
// with its shared hub vertex (0,0) first. All 6 have area exactly 1/12, are
// convex, and wind CCW.
_FP_P0 = [[0,0], [2/7,-4/21], [1/2,-1/6], [4/7,-1/21], [3/7,1/21]];
_FP_P1 = [[0,0], [3/7,1/21], [1/2,1/6], [5/14,11/42], [1/7,5/21]];
_FP_P2 = [[-2/7,4/21], [0,0], [1/7,5/21], [0,1/3], [-3/14,13/42]];
_FP_P3 = [[-4/7,1/21], [-3/7,-1/21], [0,0], [-2/7,4/21], [-1/2,1/6]];
_FP_P4 = [[-1/2,-1/6], [-5/14,-11/42], [-1/7,-5/21], [0,0], [-3/7,-1/21]];
_FP_P5 = [[-1/7,-5/21], [0,-1/3], [3/14,-13/42], [2/7,-4/21], [0,0]];
_FP_PENTS = [_FP_P0, _FP_P1, _FP_P2, _FP_P3, _FP_P4, _FP_P5];

// Which (hub, orientation) copies have any overlap with the unit square --
// exhaustively searched over the 5 canonical hub positions (_TC_CENTERS'
// own (0,0)/(1,0)/(0,1)/(1,1)/(0.5,0.5)) plus 2 extra copies of the
// (0.5,0.5) hub shifted +-1 in x (needed for full coverage -- see the plan's
// Geometry Derivation, Step 6, for why the naive 5-hub-only search came up
// 1/84 short of full unit-square area until this was found). Each entry is
// [hub_x, hub_y, k]: pentagon _FP_PENTS[k] translated so its hub sits at
// (hub_x, hub_y). Exactly these 18 placements' clipped areas sum to exactly
// 1.0, and their union was verified to equal the unit square exactly, with
// zero overlap among them.
_FP_PLACEMENTS = [
    [-1/2, 1/2, 0], [0, 1, 0], [0, 1, 5],
    [0, 0, 0], [0, 0, 1], [0, 0, 2],
    [1/2, 1/2, 0], [1/2, 1/2, 1], [1/2, 1/2, 2],
    [1/2, 1/2, 3], [1/2, 1/2, 4], [1/2, 1/2, 5],
    [1, 1, 3], [1, 1, 4], [1, 1, 5],
    [1, 0, 2], [1, 0, 3], [3/2, 1/2, 3],
];

function _fp_pentagon(m, n, k) = [for (p = _FP_PENTS[k]) [p[0] + m, p[1] + n]];

_FP_GAP  = 0.05; // engraved groove width, in tile fractions -- own constant,
                 // same scale as _KIS_GAP/_TC_GAP/_RH_GAP/_CP_GAP but never
                 // shared with them
_FP_Z_HI = 1.0;  // every rosette's "high" pentagons reach the tile's full height
_FP_Z_LO = 0.45; // the rosette's alternating "low" pentagons -- own constant,
                 // even though it numerically matches tetrakis_square's own
                 // low height, per this file's per-pattern-constant convention

// Raised mode alternates high/low by placement orientation k (even -> high,
// odd -> low) -- consistent across every hub instance, since every hub
// shares the identical 6-orientation set. Etched mode flattens every
// pentagon to the tile's full height, like the "kis" family's own etched
// mode -- see this pattern's plan document's "Relief Mode Decision".
function _floret_pentagonal_tile(relief_mode) =
    _tile_from_islands([
        for (pl = _FP_PLACEMENTS)
            let (poly = _fp_pentagon(pl[0], pl[1], pl[2]),
                 r = offset(poly, delta = -_FP_GAP / 2, closed = true),
                 z = (relief_mode == "etched") ? _FP_Z_HI
                     : ((pl[2] % 2 == 0) ? _FP_Z_HI : _FP_Z_LO))
            if (len(r) >= 3) [[r], z]
    ]);
```

- [ ] **Step 4: Wire it into `PATTERN_TYPES` and `_decoration_texture()`**

In `PATTERN_TYPES`, append `"floret_pentagonal"` after `"cairo_pentagonal"`:

```openscad
PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                 "bricks", "checkers", "dots", "cubes", "tri_grid",
                 "teardrop", "tumbling_cubes", "intertwine", "islamic_star",
                 "tetrakis_square", "kisrhombille", "triakis_triangular",
                 "rhombille", "cairo_pentagonal", "floret_pentagonal"];
```

Update the file's opening comment block above `PATTERN_TYPES` (currently documents "the nine custom VNF tiles") to say "the ten custom VNF tiles" and add `floret_pentagonal` to the named list -- and, since this pattern joins the "kis" family in taking a `relief_mode` parameter rather than the uniform-height group, update that comment's own grouping language (it currently groups patterns into "six interlocking patterns ... both genuinely cross the tile boundary like the other four" and "three 'kis' family patterns") to describe `floret_pentagonal` accurately: it's a *seventh* interlocking pattern that crosses the tile boundary (confirm this directly -- Step 6's 18-placement covering set, several of which have small clipped-corner areas, strongly implies pentagons straddle the tile seam, matching every other interlocking pattern in this file) **and** takes a `relief_mode` parameter like the kis family, so it belongs to both groups' description, not cleanly to just one -- word this precisely rather than force-fitting it into either existing sentence unchanged.

In `_decoration_texture()`, add one more branch, right after the `cairo_pentagonal` line:

```openscad
    pattern_type == "rhombille"          ? _rhombille_tile() :
    pattern_type == "cairo_pentagonal"   ? _cairo_pentagonal_tile() :
    pattern_type == "floret_pentagonal"  ? _floret_pentagonal_tile(relief_mode) :
    pattern_type;
```

- [ ] **Step 5: Extend the CGAL-warning pattern list in `decorated_solid()`**

Add `"floret_pentagonal"` directly to the "known to abort" bucket (the `if` branch currently listing `"tumbling_cubes", "intertwine", "islamic_star", "rhombille", "cairo_pentagonal"`), per the Global Constraints section above -- this plan's own smoke test already reproduced a real CGAL abort for this pattern, so it does not start in the milder "measured clean everywhere" bucket the way `cairo_pentagonal`'s own plan initially did.

Update the comment above that `echo()` bucket to add `floret_pentagonal` to the named list and note it has the largest per-tile island count of the group (18, vs. Cairo's 8).

- [ ] **Step 6: Run the new test and the full pattern-types test**

```bash
openscad -o /tmp/test_floret_pentagonal.csg tests/test_decoration_floret_pentagonal.scad
openscad -o /tmp/test_floret_pentagonal.stl tests/test_decoration_floret_pentagonal.scad 2>&1 | tee /tmp/floret_render.log
grep -i "CGAL error" /tmp/floret_render.log
```
Expected: the assertions in Step 1's test file PASS. The render step is **expected to potentially show a `CGAL error`** for the `"raised"` `difference()` block, per this plan's own Geometry Derivation smoke test -- if it does, that is *consistent* with this pattern's "known to abort" bucket placement (Step 5) and is not itself a test failure requiring a code fix; if `.stl` export still completes (exit 0, as this plan's own smoke test observed), note the specific values that did/didn't abort in this run for Step 9's sweep. If the `"etched"` block also aborts at these values, investigate before proceeding -- this plan's own smoke test found `"etched"` clean at `pattern_repeat=12`/`smoothness=50`, so an abort there at the same values would be a real discrepancy to chase down, not an expected result.

Update `tests/test_decoration_pattern_types.scad`:

```openscad
EXPECTED_PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                          "bricks", "checkers", "dots", "cubes", "tri_grid",
                          "teardrop", "tumbling_cubes", "intertwine",
                          "islamic_star", "tetrakis_square", "kisrhombille",
                          "triakis_triangular", "rhombille", "cairo_pentagonal",
                          "floret_pentagonal"];

EXPECTED_VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine",
                              "islamic_star", "tetrakis_square", "kisrhombille",
                              "triakis_triangular", "rhombille",
                              "cairo_pentagonal", "floret_pentagonal"];
```

Also update that file's header comment to mention `floret_pentagonal` joins the list as a tenth VNF pattern, and -- since (per Step 4 above) this one straddles both the "uniform height" and "kis-style relief_mode" groupings -- word the note precisely rather than reusing either existing pattern's exact phrasing unchanged.

Re-run `tests/test_decoration_pattern_types.scad` and confirm it still passes with the extended lists.

Read `tests/test_decoration_etched_groove.scad` fresh (its exact current structure, since it was last touched for `cairo_pentagonal`) and add `"floret_pentagonal"` to its "different VNF per relief mode" category (currently `KIS_PATTERN_TYPES = ["tetrakis_square", "kisrhombille", "triakis_triangular"]`) -- if that category's existing per-pattern assertions (e.g. checking Z-level counts, or checking raised != etched) are written generically enough to apply unchanged, simply add the name to the list; if any of those assertions assume a triangle-fan-specific detail that doesn't hold for a pentagon-rosette fan, add a small parallel block instead, following whatever precedent that file's own kis-family handling sets. Re-run that file and confirm it passes.

Update `tests/test_decoration_tile_aspect.scad`'s VNF-tile-pattern `for` loop:

```openscad
for (pt = ["teardrop", "tumbling_cubes", "intertwine", "islamic_star", "rhombille",
           "cairo_pentagonal", "floret_pentagonal", "tetrakis_square", "kisrhombille",
           "triakis_triangular", "diamonds", "pyramids", "checkers"]) {
```

Re-run that file and confirm it still passes (this pattern uses the plain square-tile vertical-reps formula, same as every other custom VNF tile -- no new aspect-correction category needed, per the Global Constraints section above). Note: since `_floret_pentagonal_tile()` takes a `relief_mode` argument, check how this loop currently calls `_decoration_texture(pt, "raised")` (or similar) for each pattern and confirm it already passes a `relief_mode` positionally compatible with every pattern in the list (it should, since `_decoration_texture()`'s own signature already takes `relief_mode` for every pattern type) -- this is a read-and-confirm step, not expected to require a code change to the test file's calling convention itself.

- [ ] **Step 7: `planter.scad` Customizer dropdown comment**

Find `pattern_type`'s Customizer dropdown declaration/comment in `planter.scad` (currently ends `..."rhombille", "cairo_pentagonal"]`, at/around line 48) and add `"floret_pentagonal"` to it, in the same position (end of list, after `"cairo_pentagonal"`). This is the exact step a prior PR review caught missing twice already -- do not skip it a third time.

- [ ] **Step 8: CGAL sweep -- determine the real safe values**

Following the exact methodology `cairo_pentagonal`'s own plan (Step 8) used: render the full assembly (`tests/test_planter_integration.scad`, matching `.github/workflows/test.yml`'s own invocation pattern) with `pattern_type="floret_pentagonal"` across a sweep of `pattern_repeat` values (at least: 3 through 16, matching the range Cairo's own sweep covered) crossed with `smoothness` values (at least 24 and the shipped default 60), in **both** `relief_mode="raised"` and `"etched"`. This pattern is already known (per this plan's own smoke test) to abort at `pattern_repeat=12`/`smoothness=50` (raised) and near the shipped defaults (`pattern_repeat=16`/`smoothness=60`, raised) -- do not assume any single value is safe without checking it directly, and do not assume `"etched"` shares `"raised"`'s failure points (this plan's own smoke test found the opposite at one data point: raised aborted, etched at the same settings did not).

```bash
for reps in $(seq 3 16); do
  for smooth in 24 60; do
    for relief in raised etched; do
      openscad -D 'pattern_type="floret_pentagonal"' -D "relief_mode=\"$relief\"" \
               -D "pattern_repeat=$reps" -D "smoothness=$smooth" \
               -o /tmp/fp_${reps}_${smooth}_${relief}.stl tests/test_planter_integration.scad \
               2>&1 | tee /tmp/fp_${reps}_${smooth}_${relief}.log
      grep -i "CGAL error" /tmp/fp_${reps}_${smooth}_${relief}.log && echo "ABORT: reps=$reps smooth=$smooth relief=$relief"
    done
  done
done
```

Do this on the real CI runner if at all possible, not local-only -- README.md and this repo's git history both document that CGAL fragility has previously differed between a local macOS build and GitHub Actions' Ubuntu build despite an identical reported OpenSCAD version (`intertwine`'s and `rhombille`'s own CGAL notes in README.md give the exact precedent and why it matters -- `intertwine`'s reduced CI value of 3 passed locally but aborted on the real Ubuntu runner).

Following `rhombille`'s/`cairo_pentagonal`'s own documented reasoning for picking a CI reduced value: do **not** pick an isolated clean value sandwiched between two aborts (the exact mistake `intertwine`'s first CI value made) -- pick a value with a tested-clean margin on both sides among the values actually swept. Record the specific clean and failing values found, following the exact narrative style README.md's own `rhombille`/`cairo_pentagonal` paragraphs use (name specific values, not a vague range).

- [ ] **Step 9: `.github/workflows/test.yml`**

Add `"floret_pentagonal"` to every loop that enumerates all pattern types:
- The per-tile CGAL-forcing loop (currently ending `...rhombille cairo_pentagonal; do`, around line 75-76) -- append `floret_pentagonal` (this exercises `tests/test_decoration_floret_pentagonal.scad` from Step 1/6 above).
- The single-pattern texture-build loop (around line 97) -- append `floret_pentagonal`.
- The full-assembly reduced-value loop (the `for combo in "ridges 4" ... "cairo_pentagonal 8"; do` list, around line 318-319) -- append `"floret_pentagonal <value>"` using whatever reduced `pattern_repeat` value Step 8's sweep found clean in **both** relief modes at `smoothness=24` (this loop's fixed smoothness), with a comment following the exact reasoning-and-comment style the `rhombille`/`cairo_pentagonal` entries immediately above it already use (explain *why* that specific value was chosen -- clean neighbors on both sides, not an isolated clean value between two aborts -- and whether it was re-verified against a real CI run, following the `intertwine`/`rhombille` precedent for that distinction).
- Since this plan's own smoke test found the shipped defaults (`pattern_repeat=16`, `smoothness=60`) **unsafe in `"raised"` mode**: add a default-settings pin the same way the `for relief in raised etched; do run_assembly_combo "rhombille" ...`/`"cairo_pentagonal"` block (around line 367-368) already does for the other fragile patterns **only if Step 8's sweep finds an alternate default-adjacent combination that IS clean** -- if the shipped defaults themselves remain unsafe after the sweep, this is a real open finding to flag prominently in this step's own PR (do not silently ship known-unsafe defaults; either the default `pattern_repeat`/`smoothness` needs reconsidering for this pattern specifically, or the docs need to say plainly that the out-of-the-box experience for this one pattern is not guaranteed clean, unlike every other pattern in this file).
- The invalid-`pattern_type` negative-check list (around line 452/481) -- append `floret_pentagonal` (this list must match `PATTERN_TYPES` so the assertion-message check stays accurate).

Run the equivalent of this workflow's own test script locally (or push and watch the real run, per Step 8's own CGAL-sweep step) and confirm zero `FAIL` lines.

- [ ] **Step 10: Documentation -- README.md**

- Add `"floret_pentagonal"` to the `pattern_type` parameter's valid-values list (the same line documenting `..."cairo_pentagonal"`, around line 77).
- Extend the "N of the pattern_type values are interlocking" sentence (currently names `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`, `"rhombille"`, `"cairo_pentagonal"` explicitly, around line 137) to also name `"floret_pentagonal"` and update the count from six to seven -- confirm first (per Step 4's note above) that this pattern's pentagons genuinely do straddle the tile boundary (the 18-placement covering set with several small corner-clipped pieces is strong evidence of this, but confirm directly against the shipped tile before writing the claim, the same way this project's history shows this class of claim has gone stale before).
- Add `"floret_pentagonal"`'s entry to the CGAL-fragility section (around line 141-149) per Step 8's actual findings, following the exact structure and level of detail `rhombille`'s/`cairo_pentagonal`'s own paragraphs there use (specific clean values, specific failing values, and whether re-verified against a real CI run or only measured locally) -- and, since this plan's own smoke test already found the shipped defaults unsafe in `"raised"` mode, make sure this section states plainly whether that remains true after Step 8's full sweep, rather than only discussing the reduced CI value the way some earlier entries do.
- Since this pattern takes a `relief_mode` parameter with genuinely different raised/etched geometry, also add it by name to the "kis" family paragraph (around line 135) that currently only names `"tetrakis_square"`, `"kisrhombille"`, `"triakis_triangular"` for this behavior -- word this carefully: `floret_pentagonal` shares the kis family's *relief-mode-dependent-geometry* behavior but is a separately-named pattern, not a fourth "kis" pattern in the family's own etymological sense (it isn't a Conway kis-operation tiling), so don't just append it to a sentence that says "the kis family" without a clarifying phrase.

- [ ] **Step 11: Documentation -- gallery**

Add a new subsection to `docs/gallery.md`, immediately after the existing `### cairo_pentagonal` subsection, matching its exact structure:

```markdown
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
```

Also add `floret_pentagonal` to the gallery's Table of Contents list (immediately after the `cairo_pentagonal` entry) and to the "Pattern Comparison" section's interlocking-patterns list and its raised/etched-behavior groupings if either exists there (check the same sentences README.md's own interlocking-patterns list and kis-family paragraph mirror, and keep the files' wording consistent).

Regenerate images using `docs/images/render.sh` (this script reads `PATTERN_TYPES` directly out of `modules/decoration.scad`, per its own comment -- confirm this is still true when you read it fresh, since the `prismatic_pentagonal` plan's own Global Constraints noted this fact as of its own writing) -- confirm it completes cleanly and `git status` shows exactly the 2 new images plus doc edits, no unexpected changes to unrelated images. If rendering this pattern at the script's own chosen `pattern_repeat`/`smoothness` values trips the CGAL abort found in this plan's own smoke test, use Step 8's sweep results to pick render-safe values for the gallery images specifically (the gallery doesn't need to use the shipped defaults, just values known to render a correct image).

- [ ] **Step 12: `TODO.md`**

Check off the Floret pentagonal line in the tessellation backlog:

```markdown
    - [x] Floret pentagonal tiling ("V3^4.6", pinwheel-like pentagon clusters) -- batch 3
```

- [ ] **Step 13: Commit**

```bash
git add modules/decoration.scad tests/test_decoration_floret_pentagonal.scad \
        tests/test_decoration_pattern_types.scad tests/test_decoration_etched_groove.scad \
        tests/test_decoration_tile_aspect.scad .github/workflows/test.yml \
        planter.scad README.md docs/gallery.md docs/images TODO.md
git commit -m "Add floret_pentagonal pattern_type: the floret pentagonal tiling, verified computationally"
```

## Self-Review Notes

- **Spec coverage:** the Geometry Derivation section covers the from-scratch primal-tiling construction and verification, the dual-pentagon construction and verification, the exact translation lattice and the explicit rectangular-vs-oblique check the task required, the exact affine transform (rotation + anisotropic scale, no shear, with the reasoning for why no shear is needed spelled out against the `prismatic_pentagonal` precedent), the exact pentagon coordinates and placement list, a description of every verification run (Python/shapely/sympy at 4 separate stages, an exact-`Fraction` closure proof, a 4x4-tile wider-patch check, and a live OpenSCAD/BOSL2 smoke test with an honest report of a real CGAL abort found), and the Relief Mode Decision with reasoning that directly engages the task's own prompt to consider alternating heights for this pattern's rosette sub-structure -- all points the task's "What to produce" section required for a full plan.
- **No placeholders:** every constant (`_FP_P0`..`_FP_P5`, `_FP_PLACEMENTS`, `_FP_GAP`, `_FP_Z_HI`, `_FP_Z_LO`) is a literal exact value derived and verified in the Geometry Derivation section, not a TBD. The two genuinely open items (the exact CGAL sweep results, and whether the shipped defaults need reconsidering) are honest dependencies on Task 1 Step 8's real measurement, matching how `cairo_pentagonal`'s own plan handled the same kind of measurement-dependent step -- the difference here is this plan already found and reported one real abort, rather than starting from a clean slate.
- **Type consistency:** `_floret_pentagonal_tile(relief_mode)` takes one argument, matching the "kis" family's `_foo_tile(relief_mode)` shape, not `_rhombille_tile()`/`_cairo_pentagonal_tile()`'s no-argument shape -- checked consistently throughout Task 1's wiring steps and the test file, and the Global Constraints section states explicitly why this pattern goes in `tests/test_decoration_etched_groove.scad`'s kis-style category rather than its uniform-height `VNF_PATTERN_TYPES` list.
- **Honesty about CGAL findings:** unlike a plan that would understate an inconvenient smoke-test result to look more "ready to ship," this plan documents the exact CGAL abort found (Geometry Derivation, Step 7), places the pattern directly in the "known to abort" bucket rather than the milder one, and explicitly flags in Step 9 that the shipped defaults may need reconsidering rather than assuming Task 1's sweep will conveniently find them safe.
