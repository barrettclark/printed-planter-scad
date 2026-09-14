// tests/test_decoration_teardrop.scad
//
// "teardrop" is the first pattern_type that maps to a custom VNF tile rather
// than a BOSL2 texture name, so it needs its own real-render check: an invalid
// tile (points outside the unit square, edges that don't line up across the
// tile boundary, a non-manifold result) only surfaces when the geometry is
// actually evaluated.
//
// One solid, not one per relief_mode: unlike every other pattern_type, the
// teardrop tile's raised geometry crosses the tile's y edges, so a textured
// cylinder gets scalloped (non-circular) end caps. Putting a second *textured*
// solid in the same file -- another teardrop, or any other texture -- trips a
// CGAL assertion inside OpenSCAD 2021.01's union; see the note in
// modules/decoration.scad. relief_mode="etched" is covered by the per-pattern
// and full-assembly loops in .github/workflows/test.yml, which evaluate one
// solid at a time.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("teardrop", PATTERN_TYPES), "PATTERN_TYPES must contain \"teardrop\"");

_tex = _decoration_texture("teardrop");
assert(is_list(_tex) && len(_tex) == 2,
    "_decoration_texture(\"teardrop\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex), "_decoration_texture(\"teardrop\") must be a valid VNF");

// A VNF texture tile's footprint must lie inside the unit square with Z in
// [0,1]; BOSL2 rejects anything else at render time.
_bounds = pointlist_bounds(_tex[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("teardrop tile must fit in the unit cube, got bounds ", _bounds));

// VNF tiles take no `style` (that's a heightfield-triangulation setting).
assert(_decoration_style("teardrop") == undef,
    "teardrop is a VNF tile and must not carry a style override");

// The invariant the whole tile design rests on: every vertex the tile leaves on
// one edge needs a twin at the same position on the opposite edge, or repeats
// don't stitch and the surface leaks. Rendering without an error is a weak
// proxy for this -- BOSL2 only enforces it for vertices sitting on *open*
// edges, and a near-miss (an edge resampled at a slightly different point, an
// off-by-epsilon coordinate) can still render while producing a subtly
// non-tiling mesh. So compare the two edges directly.
//
// Tasks 3 and 4 add more custom VNF tiles; _tile_edge_profile() and the two
// loops below are meant to be lifted into those tests verbatim.
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex, axis, 0);
    hi = _tile_edge_profile(_tex, axis, 1);
    name = (axis == 0) ? "x" : "y";
    assert(len(lo) > 0,
        str("teardrop tile has no vertices on its ", name, "=0 edge"));
    assert(len(lo) == len(hi),
        str("teardrop tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("teardrop tile ", name, " edge vertices don't line up: ", mismatched));
}

difference() {
    decorated_solid("teardrop", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
