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

// Raised must NOT be flat: at least two distinct heights, or the pinwheel
// reads as a flat honeycomb (same reasoning tumbling_cubes' own test applies
// to _TC_Z). Etched is no longer a flattened fan -- it is a flat panel cut by
// a two-tier groove, checked further down.
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
        // Etched is no longer a shrunk fan: its panel covers the whole unit
        // tile and reaches x=0/x=1 by design, so the _KIS_GAP/2 standoff
        // below is a raised-mode invariant only.
        if (axis == 0 && relief == "raised") {
            _raised_near_lo = min([for (p = _tex[0]) if (p[2] > EPSILON) abs(p[axis] - 0)]);
            _raised_near_hi = min([for (p = _tex[0]) if (p[2] > EPSILON) abs(p[axis] - 1)]);
            assert(approx(_raised_near_lo, _KIS_GAP / 2),
                str("kisrhombille (", relief, ") closest fan vertex to ", name, "=0 is ",
                    _raised_near_lo, " away, expected _KIS_GAP/2 (", _KIS_GAP / 2, ")"));
            assert(approx(_raised_near_hi, _KIS_GAP / 2),
                str("kisrhombille (", relief, ") closest fan vertex to ", name, "=1 is ",
                    _raised_near_hi, " away, expected _KIS_GAP/2 (", _KIS_GAP / 2, ")"));
        } else if (axis == 1) {
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

// "alternating": alt_key is the fan-triangle's local index (0..3) within its
// own 4-triangle fan, matching the same pinwheel parity the raised heights
// already use ([1.0, 0.4, 1.0, 0.4] -- indices 0 and 2 are the "high" ones).
// group_id must stay unique per fan (a composite (center, k) key) so the
// etched outline builder can tell "same rhombus's own internal seam" apart
// from "boundary between two different rhombi" -- group_id and alt_key
// genuinely differ here, the one case in this whole plan where they do.
_tex_alt = _decoration_texture("kisrhombille", "alternating");
assert(is_vnf(_tex_alt), "_decoration_texture(\"kisrhombille\", \"alternating\") must be a valid VNF");
_alt_zs = unique([for (p = _tex_alt[0]) p[2]]);
assert(_alt_zs == [0, 0.5, 1],
    str("kisrhombille alternating VNF must use exactly Z levels {0, 0.5, 1}, got ", _alt_zs));
assert(_tex_alt != _decoration_texture("kisrhombille", "raised"),
    "kisrhombille alternating tile must differ from raised");
assert(_tex_alt != _decoration_texture("kisrhombille", "etched"),
    "kisrhombille alternating tile must differ from etched");

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex_alt, axis, 0);
    hi = _tile_edge_profile(_tex_alt, axis, 1);
    name = (axis == 0) ? "x" : "y";
    assert(len(lo) == len(hi),
        str("kisrhombille alternating tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("kisrhombille alternating tile ", name, " edge vertices don't line up (including Z): ", mismatched));
}

// Etched must now be a genuinely different (flat panel + two-tier groove)
// VNF from before this plan -- Z levels 1 (panel), 0.5 (secondary/internal
// fan-seam groove), 0 (primary groove -- but kisrhombille's own fans are
// grouped by (center, k), so EVERY internal edge is same-group/secondary;
// primary edges only appear between different rhombi/hexagons, which do
// exist here -- e.g. between two rhombi of the same hexagon share a spoke,
// which is a DIFFERENT group -- so both tiers must appear).
_tex_etched_new = _decoration_texture("kisrhombille", "etched");
_etched_zs_new = unique([for (p = _tex_etched_new[0]) p[2]]);
assert(_etched_zs_new == [0, 0.5, 1],
    str("kisrhombille etched VNF must use exactly Z levels {0, 0.5, 1} (two-tier groove), got ", _etched_zs_new));

difference() {
    decorated_solid("kisrhombille", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
difference() {
    decorated_solid("kisrhombille", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
