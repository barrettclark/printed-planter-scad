// tests/test_decoration_kisrhombille.scad
//
// "kisrhombille" is a custom VNF tile (tumbling_cubes' own rhombille rhombi,
// each kis-fanned into 4 triangles from its own center), not a BOSL2 texture
// name, so it needs a real-render check the same way tumbling_cubes/
// tetrakis_square do -- a tile whose edges don't line up across the tile
// boundary only fails when the geometry is actually evaluated.
include <../modules/decoration.scad>

assert(in_list("kisrhombille", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"kisrhombille\"");

// Raised and etched are genuinely different VNFs for this pattern (unlike
// the 4 pre-existing custom patterns, which reuse one VNF via tex_inset) --
// confirm both build and are real VNFs.
for (relief = ["raised", "etched"]) {
    _tex = _decoration_texture("kisrhombille", relief);
    assert(is_list(_tex) && len(_tex) == 2,
        str("_decoration_texture(\"kisrhombille\", \"", relief, "\") must be a VNF, not a texture name"));
    assert(is_vnf(_tex),
        str("_decoration_texture(\"kisrhombille\", \"", relief, "\") must be a valid VNF"));

    _bounds = pointlist_bounds(_tex[0]);
    assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
        str("kisrhombille (", relief, ") tile must fit in the unit cube, got bounds ", _bounds));

    assert(_decoration_style("kisrhombille", relief) == undef,
        str("kisrhombille is a VNF tile and must not carry a style override (", relief, ")"));
}

// Etched must be flat: every triangle in every fan at the same height. Raised
// must NOT be flat: at least two distinct heights, or the pinwheel reads as
// a flat honeycomb (same reasoning tumbling_cubes' own test applies to _TC_Z).
_etched_tex = _decoration_texture("kisrhombille", "etched");
_etched_zs = unique([for (p = _etched_tex[0]) p[2]]);
// z=0 (the ground/border) is always present in a _tile_from_islands() VNF;
// the fans' own top height is whatever else appears.
assert(len(_etched_zs) <= 2,
    str("kisrhombille etched must be flat (one fan height plus the z=0 ground), got heights ", _etched_zs));

_raised_tex = _decoration_texture("kisrhombille", "raised");
_raised_zs = unique([for (p = _raised_tex[0]) p[2]]);
assert(len(_raised_zs) >= 3,
    str("kisrhombille raised must have at least two distinct fan heights plus the ground, got ", _raised_zs));

// The invariant the whole tile design rests on: every vertex the tile leaves
// on one edge needs a twin at the same position on the opposite edge, or
// repeats don't stitch (same check as tests/test_decoration_tumbling_cubes.scad).
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (relief = ["raised", "etched"]) {
    _tex = _decoration_texture("kisrhombille", relief);
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(_tex, axis, 0);
        hi = _tile_edge_profile(_tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        // The two axes are NOT symmetric here, per the existing _TC_V/
        // _tc_rhombus() comment in modules/decoration.scad: x=0/x=1 run
        // through the corner hexagons' centres and cut exactly one rhombus
        // each, along that rhombus's own short diagonal -- itself one edge
        // of a kis-fan triangle, so _kis_shrunk_fan()'s inward shrink pulls
        // that triangle off x=0/x=1 entirely; only the flat z=0 ground's own
        // 2 corners land there, making a `len(lo)` count trivially always 2
        // and unable to catch a construction regression. y=0/y=1, by
        // contrast, cut the vertical hexagon edges at x=+-1/2, a transversal
        // cut through a fan triangle's interior that genuinely fragments
        // and leaves real crossing vertices, so `> 4` there still works.
        // For axis=0, check the real invariant instead: the closest raised
        // fan vertex to each edge sits exactly _KIS_GAP/2 away, the groove
        // half-width every internal fan line uses.
        if (axis == 0) {
            _raised_near_lo = min([for (p = _tex[0]) if (p[2] > EPSILON) abs(p[axis] - 0)]);
            _raised_near_hi = min([for (p = _tex[0]) if (p[2] > EPSILON) abs(p[axis] - 1)]);
            assert(approx(_raised_near_lo, _KIS_GAP / 2),
                str("kisrhombille (", relief, ") closest fan vertex to ", name, "=0 is ",
                    _raised_near_lo, " away, expected _KIS_GAP/2 (", _KIS_GAP / 2, ")"));
            assert(approx(_raised_near_hi, _KIS_GAP / 2),
                str("kisrhombille (", relief, ") closest fan vertex to ", name, "=1 is ",
                    _raised_near_hi, " away, expected _KIS_GAP/2 (", _KIS_GAP / 2, ")"));
        } else {
            assert(len(lo) > 4,
                str("kisrhombille tile has only ", len(lo), " vertices on its ", name,
                    "=0 edge -- no rhombus fan spans the seam"));
        }
        assert(len(lo) == len(hi),
            str("kisrhombille tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("kisrhombille tile ", name, " edge vertices don't line up: ", mismatched));
    }
}

difference() {
    decorated_solid("kisrhombille", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
