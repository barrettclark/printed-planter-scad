// tests/test_decoration_triakis_triangular.scad
//
// "triakis_triangular" is a custom VNF tile (the unit square split by its
// (0,0)-(1,1) diagonal into two triangles, each kis-fanned into 3
// sub-triangles from its own center), not a BOSL2 texture name, so it needs
// a real-render check the same way tumbling_cubes/tetrakis_square/
// kisrhombille do -- a tile whose edges don't line up across the tile
// boundary only fails when the geometry is actually evaluated.
include <../modules/decoration.scad>

assert(in_list("triakis_triangular", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"triakis_triangular\"");

// Raised and etched are genuinely different VNFs for this pattern (unlike
// the 4 pre-existing custom patterns, which reuse one VNF via tex_inset) --
// confirm both build and are real VNFs.
for (relief = ["raised", "etched"]) {
    _tex = _decoration_texture("triakis_triangular", relief);
    assert(is_list(_tex) && len(_tex) == 2,
        str("_decoration_texture(\"triakis_triangular\", \"", relief, "\") must be a VNF, not a texture name"));
    assert(is_vnf(_tex),
        str("_decoration_texture(\"triakis_triangular\", \"", relief, "\") must be a valid VNF"));

    _bounds = pointlist_bounds(_tex[0]);
    assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
        str("triakis_triangular (", relief, ") tile must fit in the unit cube, got bounds ", _bounds));

    assert(_decoration_style("triakis_triangular", relief) == undef,
        str("triakis_triangular is a VNF tile and must not carry a style override (", relief, ")"));
}

// Etched must be flat: every triangle in both fans at the same height.
// Raised must NOT be flat: at least two distinct heights (this pattern uses
// three per fan, per _triakis_triangular_tile()'s own comment), or the
// pattern reads as a flat honeycomb (same reasoning tumbling_cubes' own test
// applies to _TC_Z).
_etched_tex = _decoration_texture("triakis_triangular", "etched");
_etched_zs = unique([for (p = _etched_tex[0]) p[2]]);
// z=0 (the ground/border) is always present in a _tile_from_islands() VNF;
// the fans' own top height is whatever else appears.
assert(len(_etched_zs) <= 2,
    str("triakis_triangular etched must be flat (one fan height plus the z=0 ground), got heights ", _etched_zs));

_raised_tex = _decoration_texture("triakis_triangular", "raised");
_raised_zs = unique([for (p = _raised_tex[0]) p[2]]);
assert(len(_raised_zs) >= 3,
    str("triakis_triangular raised must have at least two distinct fan heights plus the ground, got ", _raised_zs));

// The invariant the whole tile design rests on: every vertex the tile leaves
// on one edge needs a twin at the same position on the opposite edge, or
// repeats don't stitch (same check as tests/test_decoration_tumbling_cubes.scad).
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (relief = ["raised", "etched"]) {
    _tex = _decoration_texture("triakis_triangular", relief);
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(_tex, axis, 0);
        hi = _tile_edge_profile(_tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        // Per the task brief: "use len(lo) > 2 ... matching Task 1's
        // threshold." Kept as specified even though my own investigation
        // (see task-3-report.md) found it does NOT hold against this
        // pattern's actual built geometry -- every tile-boundary edge here
        // is an own edge of exactly one of _TT_A/_TT_B (y=0 and x=1 belong
        // to _TT_A; x=0 and y=1 belong to _TT_B), and _kis_shrunk_fan()'s
        // per-triangle shrink pulls that triangle off of the seam on all
        // four edges, the same failure mode Task 1 found for
        // tetrakis_square's whole-tile-cell case. Probing the built VNF
        // directly shows only the flat z=0 ground's 2 corners on every
        // edge, never a mid-edge crossing vertex, so `> 2` fails here.
        // Left unresolved for a controller ruling rather than silently
        // "fixed" -- see the report for the full investigation.
        assert(len(lo) > 2,
            str("triakis_triangular (", relief, ") tile has only ", len(lo), " vertices on its ", name,
                "=0 edge -- expected a real fan crossing"));
        assert(len(lo) == len(hi),
            str("triakis_triangular (", relief, ") tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("triakis_triangular (", relief, ") tile ", name, " edge vertices don't line up: ", mismatched));
    }
}

difference() {
    decorated_solid("triakis_triangular", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
