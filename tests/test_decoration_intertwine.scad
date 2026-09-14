// tests/test_decoration_intertwine.scad
//
// "intertwine" is a custom VNF tile (rings on a checkerboard lattice, broken
// where a strand passes under its neighbour), not a BOSL2 texture name, so it
// needs a real-render check: a tile whose points leave the unit square, whose
// edges don't line up across the tile boundary, or whose walls are wound
// backwards only fails when the geometry is actually evaluated. The winding one
// is not hypothetical -- the region booleans that cut the strands hand back
// paths in an unpredictable direction, and the first version of this tile came
// out unclosed because of it.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("intertwine", PATTERN_TYPES), "PATTERN_TYPES must contain \"intertwine\"");

_tex = _decoration_texture("intertwine", "raised");
assert(is_list(_tex) && len(_tex) == 2,
    "_decoration_texture(\"intertwine\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex), "_decoration_texture(\"intertwine\") must be a valid VNF");

_bounds = pointlist_bounds(_tex[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("intertwine tile must fit in the unit cube, got bounds ", _bounds));

assert(_decoration_style("intertwine", "raised") == undef,
    "intertwine is a VNF tile and must not carry a style override");
assert(_decoration_style("intertwine", "etched") == undef,
    "intertwine is a VNF tile and must not carry a style override when etched");

// Ring sizing invariants. Same-class rings sit exactly one tile apart, so an
// outer radius of 0.5 or more would fuse them into a grid of touching circles
// and the pattern would stop reading as separate interlocking rings; a mid
// radius of at most half the diagonal spacing would stop the diagonal
// neighbours crossing at all, which is the whole motif.
assert(_IW_RO < 0.5,
    str("intertwine outer radius must stay under half a tile, got ", _IW_RO));
assert(_IW_RI > 0 && _IW_RI < _IW_RO,
    str("intertwine inner radius must be a positive value below the outer one, got ", _IW_RI));
assert(_IW_RM > norm([0.5, 0.5]) / 2,
    str("intertwine rings must reach their diagonal neighbours (mid radius ", _IW_RM,
        " vs half-spacing ", norm([0.5, 0.5]) / 2, ")"));
// The break must be narrower than half the spacing between a pair's two
// crossings, or cutting one crossing would eat the other and the over/under
// alternation that links the rings would collapse.
assert(_IW_MASK < sqrt(_IW_RM * _IW_RM - 0.125),
    str("intertwine break radius ", _IW_MASK, " reaches the pair's other crossing"));

// Every ring centre listed must actually reach the tile, and every lattice
// point that reaches it must be listed -- a missing one leaves a hole in the
// pattern that only shows up as a visual gap, never as an error.
_IW_LATTICE = [for (i = [-2:2]) for (j = [-2:2]) for (o = [[0.25, 0.25], [0.75, 0.75]])
                  o + [i, j]];
assert(sort(_IW_CENTERS) == sort([for (c = _IW_LATTICE) if (_iw_reaches(c)) c]),
    str("_IW_CENTERS is not exactly the set of lattice rings that reach the tile: ", _IW_CENTERS));

// The invariant the whole tile design rests on: every vertex the tile leaves on
// one edge needs a twin at the same position on the opposite edge, or repeats
// don't stitch and the surface leaks. BOSL2 only enforces this for vertices on
// *open* edges, and a near-miss can still render while producing a subtly
// non-tiling mesh, so compare the two edges directly.
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex, axis, 0);
    hi = _tile_edge_profile(_tex, axis, 1);
    name = (axis == 0) ? "x" : "y";
    // More than the four tile corners: a strand really has to cross the seam.
    // At the obvious lattice phase (rings centred on the tile corners) every
    // strand happens to be broken exactly where the seam falls, so the tile
    // tiles without anything spanning the boundary -- correct-looking but
    // fragile, and it makes this check vacuous. Pin that it isn't the case.
    assert(len(lo) > 4,
        str("intertwine tile has only ", len(lo), " vertices on its ", name,
            "=0 edge -- no strand spans the seam"));
    assert(len(lo) == len(hi),
        str("intertwine tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("intertwine tile ", name, " edge vertices don't line up: ", mismatched));
}

difference() {
    decorated_solid("intertwine", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
