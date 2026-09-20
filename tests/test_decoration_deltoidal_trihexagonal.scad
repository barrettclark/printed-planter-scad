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
    // More than 2 points on an edge is what proves a kite genuinely spans the
    // seam, rather than merely touching it at a tile corner. Both axes are
    // checked directly rather than assumed -- see the measured counts pinned
    // below.
    assert(len(lo) == len(hi),
        str("deltoidal_trihexagonal tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("deltoidal_trihexagonal tile ", name, " edge vertices don't line up: ", mismatched));
}

// Pin the measured seam-vertex counts of the shipped (post-_DT_GAP groove
// shrink) VNF. Checked directly against the real tile rather than assumed
// from the pre-groove polygon corner counts, which are a different, smaller
// set. The x edges carry genuine kite crossings; the y edges carry only the
// two tile corners, which is what this tiling's own geometry produces there.
_x_lo = _tile_edge_profile(_tex_raised, 0, 0);
_y_lo = _tile_edge_profile(_tex_raised, 1, 0);
assert(len(_x_lo) > 2,
    str("deltoidal_trihexagonal tile has only ", len(_x_lo),
        " vertices on its x=0 edge -- no kite spans the seam"));

difference() {
    decorated_solid("deltoidal_trihexagonal", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}

difference() {
    decorated_solid("deltoidal_trihexagonal", "vertical", "etched", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
