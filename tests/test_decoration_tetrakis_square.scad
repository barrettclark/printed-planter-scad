// tests/test_decoration_tetrakis_square.scad
//
// "tetrakis_square" is a custom VNF tile (a unit square kis-fanned into 4
// triangles from its center), not a BOSL2 texture name, so it needs a
// real-render check the same way tumbling_cubes/intertwine/islamic_star do
// -- a tile whose edges don't line up across the tile boundary only fails
// when the geometry is actually evaluated.
include <../modules/decoration.scad>

assert(in_list("tetrakis_square", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"tetrakis_square\"");

// Raised and etched are genuinely different VNFs for this pattern (unlike
// the 4 pre-existing custom patterns, which reuse one VNF via tex_inset) --
// confirm both build and are real VNFs.
for (relief = ["raised", "etched"]) {
    _tex = _decoration_texture("tetrakis_square", relief);
    assert(is_list(_tex) && len(_tex) == 2,
        str("_decoration_texture(\"tetrakis_square\", \"", relief, "\") must be a VNF, not a texture name"));
    assert(is_vnf(_tex),
        str("_decoration_texture(\"tetrakis_square\", \"", relief, "\") must be a valid VNF"));

    _bounds = pointlist_bounds(_tex[0]);
    assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
        str("tetrakis_square (", relief, ") tile must fit in the unit cube, got bounds ", _bounds));

    assert(_decoration_style("tetrakis_square", relief) == undef,
        str("tetrakis_square is a VNF tile and must not carry a style override (", relief, ")"));
}

// Raised must NOT be flat: at least two distinct heights, or the pinwheel
// reads as a flat honeycomb (same reasoning tumbling_cubes' own test applies
// to _TC_Z).
//
// Etched is now a true outline engrave: since tetrakis_square's single fan
// spans the WHOLE unit tile (there is no second motif instance within one
// tile), there is no motif-to-motif boundary and so NO primary (z=0) groove
// tier at all -- only the fan's own internal seams (secondary, z=0.5). This
// is the one pattern in this plan where that's expected, not a bug: see
// _tile_outline_from_islands()'s own comment on this exact case.
_etched_tex = _decoration_texture("tetrakis_square", "etched");
_etched_zs = unique([for (p = _etched_tex[0]) p[2]]);
assert(_etched_zs == [0.5, 1],
    str("tetrakis_square etched VNF must use exactly Z levels {0.5, 1} -- no primary/z=0 ",
        "groove tier, since the whole unit tile is one motif with no sibling instance to ",
        "have a boundary against -- got ", _etched_zs));

_raised_tex = _decoration_texture("tetrakis_square", "raised");
_raised_zs = unique([for (p = _raised_tex[0]) p[2]]);
assert(len(_raised_zs) >= 3,
    str("tetrakis_square raised must have at least two distinct fan heights plus the ground, got ", _raised_zs));

assert(_etched_tex != _raised_tex, "tetrakis_square etched tile must differ from raised");

_tex_alt = _decoration_texture("tetrakis_square", "alternating");
assert(is_vnf(_tex_alt), "_decoration_texture(\"tetrakis_square\", \"alternating\") must be a valid VNF");
_alt_zs = unique([for (p = _tex_alt[0]) p[2]]);
assert(_alt_zs == [0, 0.5, 1],
    str("tetrakis_square alternating VNF must use exactly Z levels {0, 0.5, 1}, got ", _alt_zs));
assert(_tex_alt != _raised_tex && _tex_alt != _etched_tex,
    "tetrakis_square alternating tile must differ from both raised and etched");

// The invariant the whole tile design rests on: every vertex the tile leaves
// on one edge needs a twin at the same position on the opposite edge, or
// repeats don't stitch (same check as tests/test_decoration_tumbling_cubes.scad).
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

// Raised only: its kis-cell is the whole unit tile with every fan triangle
// shrunk by _KIS_GAP away from all four of its own edges, including the ones
// that sit on the tile boundary, so no fan triangle ever touches or crosses
// the seam -- only the flat z=0 ground plane's own corners land exactly on
// each edge. A `len(lo)` count is trivially always 2 here and can't catch a
// construction regression, so instead check the real invariant: the closest
// raised fan vertex to each edge sits exactly _KIS_GAP/2 away from it, which
// is the groove half-width every internal fan line also uses.
//
// Etched no longer shares this invariant: its panel tier is flush with the
// tile boundary (the outline builder's own outer-gap tier is empty for this
// pattern -- see the Z-levels assertion above), so the closest raised vertex
// to each edge is legitimately 0 away, not _KIS_GAP/2. Its edge-stitching is
// instead covered generically below alongside "alternating".
for (relief = ["raised"]) {
    _tex = _decoration_texture("tetrakis_square", relief);
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(_tex, axis, 0);
        hi = _tile_edge_profile(_tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        _raised_near_lo = min([for (p = _tex[0]) if (p[2] > EPSILON) abs(p[axis] - 0)]);
        _raised_near_hi = min([for (p = _tex[0]) if (p[2] > EPSILON) abs(p[axis] - 1)]);
        assert(approx(_raised_near_lo, _KIS_GAP / 2),
            str("tetrakis_square (", relief, ") closest fan vertex to ", name, "=0 is ",
                _raised_near_lo, " away, expected _KIS_GAP/2 (", _KIS_GAP / 2, ")"));
        assert(approx(_raised_near_hi, _KIS_GAP / 2),
            str("tetrakis_square (", relief, ") closest fan vertex to ", name, "=1 is ",
                _raised_near_hi, " away, expected _KIS_GAP/2 (", _KIS_GAP / 2, ")"));
        assert(len(lo) == len(hi),
            str("tetrakis_square (", relief, ") tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("tetrakis_square (", relief, ") tile ", name, " edge vertices don't line up: ", mismatched));
    }
}

for (tex = [_etched_tex, _tex_alt]) {
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(tex, axis, 0);
        hi = _tile_edge_profile(tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        assert(len(lo) == len(hi),
            str("tetrakis_square tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("tetrakis_square tile ", name, " edge vertices don't line up (including Z): ", mismatched));
    }
}

difference() {
    decorated_solid("tetrakis_square", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
