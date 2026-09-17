// tests/test_decoration_pattern_types.scad
//
// Renders decorated_solid() with every entry in modules/decoration.scad's
// PATTERN_TYPES list. A typo in that list, or in _decoration_texture()'s
// mapping, would otherwise only surface when a user actually selected the
// broken value -- this exercises all of them up front.
//
// EXPECTED_PATTERN_TYPES is independent of PATTERN_TYPES on purpose: if
// this test only iterated PATTERN_TYPES directly, silently removing (or
// swapping) one of the documented options would still pass, since the loop
// would just have one fewer thing to render. Asserting the two lists match
// first means a removed/renamed option fails loudly here instead.
include <../modules/decoration.scad>

EXPECTED_PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                          "bricks", "checkers", "dots", "cubes", "tri_grid",
                          "teardrop", "tumbling_cubes", "intertwine",
                          "islamic_star", "tetrakis_square", "kisrhombille",
                          "triakis_triangular"];

// The pattern_types that resolve to a hand-rolled VNF tile instead of a BOSL2
// texture name. Listed explicitly (and pinned below) rather than derived, so a
// pattern that silently stopped being a VNF -- or a new BOSL2 texture name that
// accidentally resolved to one -- fails here. The three "kis"-family patterns
// belong here too in raised mode: they resolve to a hand-rolled VNF just like
// the other four (their etched-vs-raised distinction is checked separately in
// test_decoration_etched_groove.scad).
EXPECTED_VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine",
                              "islamic_star", "tetrakis_square", "kisrhombille",
                              "triakis_triangular"];

assert(PATTERN_TYPES == EXPECTED_PATTERN_TYPES,
    str("PATTERN_TYPES changed -- expected ", EXPECTED_PATTERN_TYPES, ", got ", PATTERN_TYPES));

// Rendering without error only proves each name produces *some* geometry --
// it wouldn't catch _decoration_texture() accidentally mapping one pattern
// to a different (but still valid) BOSL2 texture. In raised mode "ridges" is
// the sole alias (-> "ribs") and the interlocking and "kis" family patterns
// are the VNF tiles (each checked in detail by its own
// test_decoration_<name>.scad); every
// other pattern_type must map to itself. Etched mode's flat-top/V-groove
// routing has its own file, test_decoration_etched_groove.scad.
for (pt = PATTERN_TYPES) {
    if (pt != "none" && !in_list(pt, EXPECTED_VNF_PATTERN_TYPES)) {
        expected_tex = (pt == "ridges") ? "ribs" : pt;
        assert(_decoration_texture(pt, "raised") == expected_tex,
            str("_decoration_texture(\"", pt, "\", \"raised\") should be \"", expected_tex,
                "\", got \"", _decoration_texture(pt, "raised"), "\""));
    }
}
// Deliberately phrased as is_vnf() == in_list(): this catches BOTH a tile that
// stopped being a VNF and a plain texture name that started being one, without
// ever str()-ing a VNF into an assertion message (which dumps the whole mesh).
for (pt = PATTERN_TYPES) {
    if (pt != "none") {
        assert(is_vnf(_decoration_texture(pt, "raised")) ==
                   in_list(pt, EXPECTED_VNF_PATTERN_TYPES),
            str("\"", pt, "\" disagrees with EXPECTED_VNF_PATTERN_TYPES about whether ",
                "_decoration_texture() returns a custom VNF tile"));
    }
}

// Rendering without error also wouldn't catch a regression that dropped or
// changed one of the three explicit style overrides -- BOSL2 would still
// accept an undef/wrong style and produce *some* valid-looking geometry
// (silently the wrong shape, e.g. "pyramids" reverting to mini-diamonds
// under BOSL2's default style), not an error. Pin the three overrides and
// confirm every other pattern_type has no override at all. Etched mode is
// pinned separately in test_decoration_etched_groove.scad, since the etched
// texture (and so the style) differs for ridges/pyramids/diamonds.
EXPECTED_STYLES = [
    ["diamonds", "concave"],
    ["pyramids", "convex"],
    ["bricks",   "convex"],
];
for (pair = EXPECTED_STYLES) {
    assert(_decoration_style(pair[0], "raised") == pair[1],
        str("_decoration_style(\"", pair[0], "\", \"raised\") should be \"", pair[1],
            "\", got ", _decoration_style(pair[0], "raised")));
}
_styled_types = [for (pair = EXPECTED_STYLES) pair[0]];
for (pt = PATTERN_TYPES) {
    if (!in_list(pt, _styled_types)) {
        assert(_decoration_style(pt, "raised") == undef,
            str("_decoration_style(\"", pt, "\", \"raised\") should be undef, got ",
                _decoration_style(pt, "raised")));
    }
}

for (i = [0 : len(PATTERN_TYPES) - 1]) {
    translate([i * 200, 0, 0])
        decorated_solid(PATTERN_TYPES[i], "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
}
