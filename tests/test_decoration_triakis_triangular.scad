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

// Raised must NOT be flat: at least two distinct heights (this pattern uses
// three per fan, per _triakis_triangular_tile()'s own comment), or the
// pattern reads as a flat honeycomb (same reasoning tumbling_cubes' own test
// applies to _TC_Z).
_raised_tex = _decoration_texture("triakis_triangular", "raised");
_raised_zs = unique([for (p = _raised_tex[0]) p[2]]);
assert(len(_raised_zs) >= 3,
    str("triakis_triangular raised must have at least two distinct fan heights plus the ground, got ", _raised_zs));

// Etched is a true outline engrave now: _TT_A and _TT_B ARE two different
// motifs (their shared diagonal is a real primary-tier boundary), so BOTH
// tiers appear here, unlike tetrakis_square.
_etched_tex = _decoration_texture("triakis_triangular", "etched");
_etched_zs = unique([for (p = _etched_tex[0]) p[2]]);
assert(_etched_zs == [0, 0.5, 1],
    str("triakis_triangular etched VNF must use exactly Z levels {0, 0.5, 1} (primary groove ",
        "on the A/B diagonal, secondary on each cell's own 3-triangle fan seams), got ", _etched_zs));
assert(_etched_tex != _raised_tex, "triakis_triangular etched tile must differ from raised");

_tex_alt = _decoration_texture("triakis_triangular", "alternating");
assert(is_vnf(_tex_alt), "_decoration_texture(\"triakis_triangular\", \"alternating\") must be a valid VNF");
_alt_zs = unique([for (p = _tex_alt[0]) p[2]]);
assert(_alt_zs == [0, 0.5, 1],
    str("triakis_triangular alternating VNF must use exactly Z levels {0, 0.5, 1}, got ", _alt_zs));
assert(_tex_alt != _raised_tex && _tex_alt != _etched_tex,
    "triakis_triangular alternating tile must differ from both raised and etched");

// The invariant the whole tile design rests on: every vertex the tile leaves
// on one edge needs a twin at the same position on the opposite edge, or
// repeats don't stitch (same check as tests/test_decoration_tumbling_cubes.scad).
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_raised_tex, axis, 0);
    hi = _tile_edge_profile(_raised_tex, axis, 1);
    name = (axis == 0) ? "x" : "y";
    // Verified directly against the built VNF: every tile-boundary edge
    // here is an own edge of exactly one of _TT_A/_TT_B (y=0 and x=1
    // belong to _TT_A; x=0 and y=1 belong to _TT_B -- the diagonal is
    // internal and shared by neither boundary), never crossed
    // transversally. _kis_shrunk_fan() shrinks each sub-triangle inward
    // on all three of its own edges, including whichever one inherits
    // the tile boundary, so no fan triangle ever touches or crosses the
    // seam -- only the flat z=0 ground's own 2 corners land on each edge.
    // A `len(lo)` count is trivially always 2 here and can't catch a
    // construction regression, so instead check the real invariant: the
    // closest raised fan vertex to each edge sits exactly _KIS_GAP/2
    // away from it, the groove half-width every internal fan line uses.
    _raised_near_lo = min([for (p = _raised_tex[0]) if (p[2] > EPSILON) abs(p[axis] - 0)]);
    _raised_near_hi = min([for (p = _raised_tex[0]) if (p[2] > EPSILON) abs(p[axis] - 1)]);
    assert(approx(_raised_near_lo, _KIS_GAP / 2),
        str("triakis_triangular (raised) closest fan vertex to ", name, "=0 is ",
            _raised_near_lo, " away, expected _KIS_GAP/2 (", _KIS_GAP / 2, ")"));
    assert(approx(_raised_near_hi, _KIS_GAP / 2),
        str("triakis_triangular (raised) closest fan vertex to ", name, "=1 is ",
            _raised_near_hi, " away, expected _KIS_GAP/2 (", _KIS_GAP / 2, ")"));
    assert(len(lo) == len(hi),
        str("triakis_triangular (raised) tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("triakis_triangular (raised) tile ", name, " edge vertices don't line up: ", mismatched));
}

// Same stitching invariant for the two-tier outline builders (etched and
// alternating), including Z this time -- they build via a completely
// different code path than the raised _kis_shrunk_fan() tile above, so the
// edge geometry needs its own check.
for (tex = [_etched_tex, _tex_alt]) {
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(tex, axis, 0);
        hi = _tile_edge_profile(tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        assert(len(lo) == len(hi),
            str("triakis_triangular tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("triakis_triangular tile ", name, " edge vertices don't line up (including Z): ", mismatched));
    }
}

difference() {
    decorated_solid("triakis_triangular", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
