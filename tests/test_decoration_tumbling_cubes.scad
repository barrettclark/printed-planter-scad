// tests/test_decoration_tumbling_cubes.scad
//
// "tumbling_cubes" is a custom VNF tile (a rhombille tiling raised to three
// heights), not a BOSL2 texture name, so it needs a real-render check: a tile
// whose points leave the unit square, whose edges don't line up across the tile
// boundary, or whose walls are wound backwards only fails when the geometry is
// actually evaluated.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("tumbling_cubes", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"tumbling_cubes\"");

_tex = _decoration_texture("tumbling_cubes", "raised");
assert(is_list(_tex) && len(_tex) == 2,
    "_decoration_texture(\"tumbling_cubes\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex), "_decoration_texture(\"tumbling_cubes\") must be a valid VNF");

// A VNF texture tile's footprint must lie inside the unit square with Z in
// [0,1]; BOSL2 rejects anything else at render time.
_bounds = pointlist_bounds(_tex[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("tumbling_cubes tile must fit in the unit cube, got bounds ", _bounds));

// VNF tiles take no `style` (that's a heightfield-triangulation setting), and
// _decoration_style() must reach that answer from the resolved texture rather
// than from a pattern_type-specific branch.
assert(_decoration_style("tumbling_cubes", "raised") == undef,
    "tumbling_cubes is a VNF tile and must not carry a style override");
assert(_decoration_style("tumbling_cubes", "etched") == undef,
    "tumbling_cubes is a VNF tile and must not carry a style override when etched");

// The three rhombi must sit at three DIFFERENT heights, and one of them at the
// full tile height: equal heights render as a flat honeycomb, and a tile whose
// tallest plateau is below z=1 wastes part of pattern_depth.
assert(len(unique(_TC_Z)) == 3,
    str("tumbling_cubes needs three distinct rhombus heights for the isometric illusion, got ", _TC_Z));
assert(max(_TC_Z) == 1, str("tallest tumbling_cubes rhombus must reach z=1, got ", max(_TC_Z)));

// The invariant the whole tile design rests on: every vertex the tile leaves on
// one edge needs a twin at the same position on the opposite edge, or repeats
// don't stitch and the surface leaks. Rendering without an error is a weak
// proxy for this -- BOSL2 only enforces it for vertices sitting on *open*
// edges, and a near-miss (an edge resampled at a slightly different point, an
// off-by-epsilon coordinate) can still render while producing a subtly
// non-tiling mesh. So compare the two edges directly.
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex, axis, 0);
    hi = _tile_edge_profile(_tex, axis, 1);
    name = (axis == 0) ? "x" : "y";
    // More than the four tile corners: an island really has to cross the seam,
    // otherwise the pattern is boxed inside each tile and this check is vacuous.
    assert(len(lo) > 4,
        str("tumbling_cubes tile has only ", len(lo), " vertices on its ", name,
            "=0 edge -- no rhombus spans the seam"));
    assert(len(lo) == len(hi),
        str("tumbling_cubes tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("tumbling_cubes tile ", name, " edge vertices don't line up: ", mismatched));
}

difference() {
    decorated_solid("tumbling_cubes", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
