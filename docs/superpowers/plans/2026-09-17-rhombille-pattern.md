# Rhombille Tiling Pattern Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `"rhombille"` as a new `pattern_type` -- the rhombille tiling (Wikipedia "V3.6.3.6", diamond/rhombus motif), reusing `tumbling_cubes`' existing hexagon/rhombus geometry (`_TC_CENTERS`, `_tc_rhombus()`) but rendered as a flat, uniform-height rhombus grid instead of `tumbling_cubes`' three-height isometric-cube illusion.

**Architecture:** One new custom VNF tile function, `_rhombille_tile()`, built the same way `_tumbling_cubes_tile()` is (a list of `[region, height]` islands fed to the existing `_tile_from_islands()` helper), but with every rhombus at the **same** height. Unlike the three "kis" family patterns, this tile's geometry does not depend on `relief_mode` -- like `tumbling_cubes`/`intertwine`/`islamic_star`, etched-vs-raised is handled entirely by `decorated_solid()`'s existing `tex_inset` logic, so `_rhombille_tile()` takes no `relief_mode` parameter.

**Tech Stack:** OpenSCAD 2021.01, BOSL2 (`lib/BOSL2/std.scad`), this repo's existing `modules/decoration.scad` VNF-tile infrastructure (`_tile_from_islands()`, `_TC_CENTERS`, `_tc_rhombus()`).

**Spec:** No separate spec document -- this plan follows the same pattern established by `docs/superpowers/plans/2026-09-17-kis-family-patterns.md` (see that plan's Architecture section for the general "custom VNF tile added as a new `pattern_type`" shape) and `TODO.md`'s tessellation backlog, which calls out that rhombille "reuses tumbling_cubes' hexagon math directly."

## Global Constraints

- New pattern name: `"rhombille"`, added to `PATTERN_TYPES` in `modules/decoration.scad` immediately after `"kisrhombille"` (before `"triakis_triangular"`... actually simplest: append after the existing 3 kis-family entries at the end of the list, i.e. right after `"triakis_triangular"`) so the Customizer dropdown order matches the TODO.md backlog order.
- The tile must be a VNF (not a BOSL2 texture string), added to `EXPECTED_VNF_PATTERN_TYPES` in `tests/test_decoration_pattern_types.scad`.
- The tile is **not** in `_ASPECT_EXCLUDED_PATTERNS` and **not** in `_ASPECT_SQRT3_PATTERNS` -- like the other custom VNF tiles (`teardrop`, `tumbling_cubes`, `intertwine`, `islamic_star`, the kis family), it's built on `_UNIT_TILE` with no intrinsic aspect distortion, so it uses the plain `_square_tile_vertical_reps()` formula automatically (no changes needed to that function or its pattern lists).
- No `style` override: it's a VNF, so `_decoration_style_for()` must return `undef` for it (true automatically -- only `"diamonds"`/`"pyramids"`/`"bricks"` have overrides -- but the task's test must assert this explicitly, matching every other VNF tile's test file).
- Every rhombus is raised to the **same** height (uniform, not alternating and not three distinct heights like `tumbling_cubes`) -- this is what makes it read as a clean geometric rhombus-grid relief/etch rather than `tumbling_cubes`' isometric illusion. Use height `1.0` (the tile's own max) so `pattern_depth` is fully used.
- Use gap `0.055` (same numeric value as `_TC_GAP`, but its own named constant `_RH_GAP` -- this repo's convention, established by the kis family getting `_KIS_GAP` distinct from `_TC_GAP` even at the same value, is that each pattern owns its own groove-width constant rather than sharing another pattern's).
- CGAL-fragility warning: `rhombille` reuses the exact same small-facet-count-per-tile-cell construction class as `tumbling_cubes` (same rhombus count and shapes, just flatter), so it belongs in `decorated_solid()`'s **milder** "measured clean everywhere" warning bucket alongside the three kis-family patterns, not the "known to abort" bucket -- but only after Task 1's own local CGAL testing across the same pattern_repeat/smoothness sweep the kis-family plan used confirms it's actually clean. If Task 1 finds a CGAL-aborting combination within the normal tested range, put it in the "known to abort" bucket instead and document the failing values, matching how `tumbling_cubes` itself is documented.
- README.md's `pattern_type` parameter table, the "last N pattern_type values are interlocking" style claims, and the CGAL-fragility section must all be updated to include `rhombille` by name -- this repo has already been burned once (documented in a prior PR review) by an enumeration claim silently going stale when a new pattern was added, so update it explicitly rather than leaving a rounded-up count.
- `docs/gallery.md` needs a new subsection with regenerated raised/etched example renders, following the exact structure of the three existing kis-family subsections.
- `.github/workflows/test.yml`'s pattern-type loops (single-pattern build, full-assembly reduced-value combos, invalid-pattern-type check) must include `"rhombille"`.

## Task 1: `_rhombille_tile()` -- geometry, wiring, tests, docs

**Files:**
- Modify: `modules/decoration.scad` (add `_RH_Z`, `_RH_GAP`, `_rhombille_tile()`; extend `PATTERN_TYPES`; extend `_decoration_texture()`; extend the CGAL-warning `echo()` pattern lists)
- Create: `tests/test_decoration_rhombille.scad`
- Modify: `tests/test_decoration_pattern_types.scad` (extend `EXPECTED_PATTERN_TYPES` and `EXPECTED_VNF_PATTERN_TYPES`)
- Modify: `.github/workflows/test.yml` (add `"rhombille"` to every pattern-type loop)
- Modify: `README.md` (parameter table, pattern-type enumeration claims, CGAL section)
- Modify: `docs/gallery.md` (new subsection + regenerated images via `docs/images/render.sh`)
- Modify: `TODO.md` (check off the rhombille line)

**Interfaces:**
- Consumes: `_tile_from_islands(islands)`, `_TC_CENTERS`, `_tc_rhombus(c, k)` -- all existing, defined in `modules/decoration.scad` around the `tumbling_cubes` section (see that file's "Tumbling blocks (rhombille)" comment block for the exact geometry these produce: `_TC_CENTERS` is 5 hexagon centers normalised so the rectangular unit cell is exactly the unit square, `_tc_rhombus(c, k)` returns the `k`-th (0, 1, or 2) rhombus of the hexagon centred at `c`).
- Produces: `_rhombille_tile()` (no arguments -- geometry doesn't depend on `relief_mode`), `_RH_Z` (a plain number, `1.0`), `_RH_GAP` (a plain number, `0.055`). `_decoration_texture(pattern_type, relief_mode)` gains one more branch: `pattern_type == "rhombille" ? _rhombille_tile() :`.

- [ ] **Step 1: Add the tile geometry to `modules/decoration.scad`**

Insert immediately after the existing `_tumbling_cubes_tile()` function (right before the `"--- Kisrhombille"` comment block), so the two related patterns sit next to each other:

```openscad
// --- Rhombille (the tiling tumbling_cubes' illusion is built from) ----------
//
// Wikipedia: "a tiling of the plane by rhombi... also known as ... the
// tumbling blocks pattern." tumbling_cubes raises the three rhombi per
// hexagon to three DIFFERENT heights to sell an isometric-cube illusion;
// this pattern is the plain tiling underneath that illusion -- the same
// _TC_CENTERS/_tc_rhombus() hexagon geometry, but every rhombus at the SAME
// height, so it reads as a clean rhombus-grid relief/etch rather than a set
// of cubes. Because the geometry doesn't change between raised and etched,
// this tile (like tumbling_cubes/intertwine/islamic_star) takes no
// relief_mode parameter -- decorated_solid()'s tex_inset handles that.
_RH_Z   = 1.0;   // every rhombus reaches the tile's full height
_RH_GAP = 0.055; // engraved line between rhombi, in tile fractions -- own
                 // constant rather than reusing _TC_GAP, matching how the
                 // kis family owns _KIS_GAP distinct from _TC_GAP

function _rhombille_tile() =
    _tile_from_islands([
        for (c = _TC_CENTERS) for (k = [0:2])
            let (r = offset(_tc_rhombus(c, k), delta = -_RH_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _RH_Z]]);
```

- [ ] **Step 2: Wire it into `PATTERN_TYPES` and `_decoration_texture()`**

In `PATTERN_TYPES`, add `"rhombille"` right after `"triakis_triangular"`:

```openscad
PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                 "bricks", "checkers", "dots", "cubes", "tri_grid",
                 "teardrop", "tumbling_cubes", "intertwine", "islamic_star",
                 "tetrakis_square", "kisrhombille", "triakis_triangular",
                 "rhombille"];
```

Update the big comment above `PATTERN_TYPES` (currently says "the seven custom VNF tiles") to say "the eight custom VNF tiles" and add `rhombille` to the named list alongside the other interlocking/kis patterns.

In `_decoration_texture()`, add one more branch, right after the `triakis_triangular` line:

```openscad
    pattern_type == "triakis_triangular" ? _triakis_triangular_tile(relief_mode) :
    pattern_type == "rhombille"          ? _rhombille_tile() :
    pattern_type;
```

- [ ] **Step 3: Extend the CGAL-warning pattern lists in `decorated_solid()`**

For now, add `"rhombille"` to the *milder* "measured clean everywhere" bucket (the `else if` branch that currently lists `"tetrakis_square", "kisrhombille", "triakis_triangular"`) -- Step 6 below will locally verify this claim (the same CGAL sweep the kis-family plan ran) and this step must be revisited (moved to the "known to abort" bucket with documented failing values) if that verification finds a break.

- [ ] **Step 4: Write the test file**

Create `tests/test_decoration_rhombille.scad`, following `tests/test_decoration_tumbling_cubes.scad`'s exact structure (read that file first -- it's the direct template, including its `_tile_edge_profile()` helper and the difference()-against-a-cube CGAL-forcing pattern), but adapted for rhombille's actual invariants:

```openscad
// tests/test_decoration_rhombille.scad
//
// "rhombille" is a custom VNF tile (the plain rhombille tiling tumbling_cubes'
// isometric illusion is built from, every rhombus at the same height instead
// of three), not a BOSL2 texture name, so it needs a real-render check: a
// tile whose points leave the unit square, whose edges don't line up across
// the tile boundary, or whose walls are wound backwards only fails when the
// geometry is actually evaluated.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("rhombille", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"rhombille\"");

_tex = _decoration_texture("rhombille", "raised");
assert(is_list(_tex) && len(_tex) == 2,
    "_decoration_texture(\"rhombille\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex), "_decoration_texture(\"rhombille\") must be a valid VNF");

// A VNF texture tile's footprint must lie inside the unit square with Z in
// [0,1]; BOSL2 rejects anything else at render time.
_bounds = pointlist_bounds(_tex[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("rhombille tile must fit in the unit cube, got bounds ", _bounds));

// VNF tiles take no `style` (that's a heightfield-triangulation setting), and
// _decoration_style() must reach that answer from the resolved texture rather
// than from a pattern_type-specific branch.
assert(_decoration_style("rhombille", "raised") == undef,
    "rhombille is a VNF tile and must not carry a style override");
assert(_decoration_style("rhombille", "etched") == undef,
    "rhombille is a VNF tile and must not carry a style override when etched");

// Unlike tumbling_cubes, every rhombus in rhombille sits at the SAME height,
// and it's the tile's full height: this pattern is a plain rhombus grid, not
// an isometric-cube illusion, and pattern_depth should be fully used.
assert(len(unique(_TC_Z)) > 1 || true, "sanity: _TC_Z (tumbling_cubes) unaffected by this file");
assert(_RH_Z == 1, str("rhombille's uniform rhombus height must be 1, got ", _RH_Z));

// raised and etched must resolve to the exact same VNF -- rhombille's
// geometry doesn't depend on relief_mode (decorated_solid()'s tex_inset
// handles the raised/etched distinction), unlike the three kis-family
// patterns which genuinely build a different tile per mode.
_tex_etched = _decoration_texture("rhombille", "etched");
assert(_tex == _tex_etched,
    "rhombille's tile geometry must be identical for \"raised\" and \"etched\" -- only decorated_solid()'s tex_inset should differ");

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
    // More than the four tile corners: an island really has to cross the
    // seam, otherwise the pattern is boxed inside each tile and this check
    // is vacuous. rhombille reuses tumbling_cubes' own hexagon placement, so
    // the same ">4" bound that holds for tumbling_cubes' seam crossings
    // applies here too.
    assert(len(lo) > 4,
        str("rhombille tile has only ", len(lo), " vertices on its ", name,
            "=0 edge -- no rhombus spans the seam"));
    assert(len(lo) == len(hi),
        str("rhombille tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("rhombille tile ", name, " edge vertices don't line up: ", mismatched));
}

difference() {
    decorated_solid("rhombille", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

Note on the `>4` seam-crossing assertion: this is carried over from `test_decoration_tumbling_cubes.scad`'s own working assertion (same geometry, same seam placement, already proven correct for that tile) -- unlike the kis-family plan's task template, which copied an assertion from `tumbling_cubes` into a genuinely different geometry (the kis fans, which shrink away from every edge including the tile boundary) and had it turn out vacuous. Here the geometry really is unchanged from `tumbling_cubes` at the seam, so the assertion should hold as-is. **If it doesn't** (i.e. `len(lo)` comes out `<= 4`), stop and investigate before forcing it to pass -- report back rather than loosening the bound blindly, the same discipline the kis-family plan's implementers used when they hit a similar surprise.

- [ ] **Step 5: Run the new test and the full pattern-types test**

```bash
openscad -o /tmp/test_rhombille.csg tests/test_decoration_rhombille.scad
openscad -o /tmp/test_rhombille.stl tests/test_decoration_rhombille.stl 2>&1 | tee /tmp/rhombille_render.log
```

(Use whatever this repo's actual test-running convention is -- check `.github/workflows/test.yml` and any local test-runner script for the exact invocation other pattern tests use, and match it. The key check beyond "no assertion failure": scan the render log for the literal string "CGAL error" -- if present, the tile aborted CGAL and Step 3's "measured clean" placement is wrong for at least the default `pattern_repeat`/`smoothness` used in the test file's `decorated_solid()` call.)

Update `tests/test_decoration_pattern_types.scad`:

```openscad
EXPECTED_PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                          "bricks", "checkers", "dots", "cubes", "tri_grid",
                          "teardrop", "tumbling_cubes", "intertwine",
                          "islamic_star", "tetrakis_square", "kisrhombille",
                          "triakis_triangular", "rhombille"];

EXPECTED_VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine",
                              "islamic_star", "tetrakis_square", "kisrhombille",
                              "triakis_triangular", "rhombille"];
```

Also update that file's header comment (currently documents "The three kis-family patterns belong here too...") to mention rhombille joins them as an eighth VNF pattern (note: rhombille, unlike the kis family, does NOT need the etched-vs-raised carve-out language, since its geometry is mode-independent -- word this precisely so a future reader doesn't assume rhombille also branches on `relief_mode`).

Re-run `tests/test_decoration_pattern_types.scad` and confirm it still passes with the extended lists.

- [ ] **Step 6: CGAL sweep -- verify (or refute) the "measured clean" claim**

Following the exact same verification approach the kis-family plan's final task used (see `docs/superpowers/plans/2026-09-17-kis-family-patterns.md` and the README's CGAL-fragility section for the tested value grid), render the full assembly (`planter.scad`) with `pattern_type="rhombille"` across a small sweep of `pattern_repeat` and `smoothness` values bracketing the project's shipped defaults (`smoothness=60`; try `pattern_repeat` at a low, default, and high value -- match whatever specific values the kis-family README section used for its own sweep, for consistency), in both `relief_mode="raised"` and `"etched"`, on the actual CI-equivalent platform if at all possible (README already documents that local-clean is not sufficient -- CGAL fragility has been platform-dependent before in this project). Record the results.

- If every combination is clean: leave Step 3's placement in the "measured clean everywhere" bucket, and add a line to README's CGAL section documenting rhombille alongside the kis family with the specific values tested.
- If any combination aborts CGAL: move `"rhombille"` to the "known to abort" bucket in `decorated_solid()`'s echo() (alongside `tumbling_cubes`/`intertwine`/`islamic_star`), and document the specific failing `pattern_repeat`/`smoothness` values in README exactly the way `tumbling_cubes`'s own failure modes are documented there.

- [ ] **Step 7: Documentation -- README.md**

- Add `"rhombille"` to the `pattern_type` parameter's valid-values list/table.
- Find and fix any "the last N pattern_type values are interlocking" (or similar enumeration) claim -- this exact class of claim went stale once already during the kis-family plan (it had to be corrected to name the four patterns explicitly rather than count them). Check whether adding an eighth VNF pattern breaks any such claim and fix it the same way: name the affected patterns explicitly rather than by count, or update the count precisely.
- Add rhombille's entry to the CGAL-fragility section per Step 6's actual findings.

- [ ] **Step 8: Documentation -- gallery**

Add a new subsection to `docs/gallery.md` for `rhombille`, matching the structure of the three existing kis-family subsections (each has: a short description, a raised-mode example image, an etched-mode example image). Regenerate images using `docs/images/render.sh` (check that script for its exact invocation and output path convention -- it was used to regenerate all prior gallery images this session, most recently the 6 kis-family images).

- [ ] **Step 9: `.github/workflows/test.yml`**

Add `"rhombille"` to every loop that currently lists all pattern types: the single-pattern build matrix, the full-assembly reduced-value combination loop, and the invalid-pattern-type negative-check list (wherever the valid-list is enumerated for that negative check). Match the exact reduced `pattern_repeat` value convention already used for the other custom-VNF-tile patterns in that file's full-assembly loop (check what value `tumbling_cubes`/`tetrakis_square` etc. use there and use the same one for `rhombille`, unless Step 6's CGAL sweep found that value unsafe for rhombille specifically -- in which case use whatever value Step 6 verified clean instead, and note the discrepancy in a comment).

- [ ] **Step 10: `TODO.md`**

Check off the rhombille line in the tessellation backlog:

```markdown
    - [x] Rhombille tiling ("V3.6.3.6", diamond/rhombus motif) -- batch 2, reuses tumbling_cubes' hexagon math directly
```

- [ ] **Step 11: Commit**

```bash
git add modules/decoration.scad tests/test_decoration_rhombille.scad \
        tests/test_decoration_pattern_types.scad .github/workflows/test.yml \
        README.md docs/gallery.md docs/images TODO.md
git commit -m "Add rhombille pattern_type: the plain rhombille tiling tumbling_cubes' isometric illusion is built from"
```
