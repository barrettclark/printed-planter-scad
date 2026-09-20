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

// pattern_repeat=12 (this repo's usual template value for these per-tile
// CGAL-forcing tests) rendered clean locally on macOS but CGAL-aborted on the
// real GitHub Actions Ubuntu runner for this pattern specifically -- the same
// platform-divergence class already documented for "intertwine" in README.md
// (identical reported OpenSCAD 2021.01, different CGAL floating-point
// behavior). A local sweep of pattern_repeat 4 through 32 found every value
// clean on macOS, so local testing alone can't discriminate a safer one here;
// 32 is used instead of 12 as a hedge (a narrower per-island arc, which this
// project's documented CGAL-fragility mechanism -- a flat plateau facet
// chording back inside the wall -- generally makes safer), not a proven fix.
// If this ever fails on CI again, re-measure directly against that run rather
// than trusting another local value.
difference() {
    decorated_solid("cairo_pentagonal", "vertical", "raised", 1.5, 32, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
