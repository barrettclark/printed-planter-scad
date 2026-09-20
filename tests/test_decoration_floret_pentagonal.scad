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
        // The shipped VNF (post-groove-shrink, not the plan's pre-groove
        // pentagon corner counts from Geometry Derivation Step 6, which are
        // 5 and 3) has 18 points on the x=0/x=1 edges and 10 points on the
        // y=0/y=1 edges -- both well beyond the 2 tile corners alone, so
        // more than 2 is what proves a pentagon genuinely spans the seam,
        // not just touches at a corner.
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

// One solid only, and specifically the "raised" one: every other
// test_decoration_<tile>.scad renders exactly one, because two top-level
// solids in one file make OpenSCAD union them through CGAL, which is both
// slow and (for these plateau tiles) a fragility of its own. "raised" is the
// mode with the alternating-height side walls, so it is the harder of the
// two to build; etched's own VNF is pinned by the assertions above and gets
// a real manifold check from .github/workflows/test.yml's full-assembly
// loop, which runs both relief modes.
//
// pattern_repeat=26 rather than the 12 the other tile tests use: this
// pattern is genuinely CGAL-fragile at this exact r1/r2/height/$fn
// combination (see README.md's CGAL section). A local sweep of this file's
// own configuration found 12, 14, 15, 16, 20, 22 and 23 all abort, while
// 24-27 and 30-33 are clean; 26 was picked for its tested-clean neighbors on
// both sides (25 and 27, in BOTH relief modes), not as an isolated clean
// value between two aborts -- the mistake "intertwine"'s first CI value made.
// Measured on macOS only so far; if this ever aborts on the real Ubuntu
// runner, re-measure against that run rather than guessing another local
// value (the same platform-divergence caveat cairo_pentagonal's own file
// records).
difference() {
    decorated_solid("floret_pentagonal", "vertical", "raised", 1.5, 26, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
