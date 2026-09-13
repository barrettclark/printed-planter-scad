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
                          "bricks", "checkers", "dots", "cubes", "tri_grid"];

assert(PATTERN_TYPES == EXPECTED_PATTERN_TYPES,
    str("PATTERN_TYPES changed -- expected ", EXPECTED_PATTERN_TYPES, ", got ", PATTERN_TYPES));

// Rendering without error only proves each name produces *some* geometry --
// it wouldn't catch _decoration_texture() accidentally mapping one pattern
// to a different (but still valid) BOSL2 texture. "ridges" is the sole
// alias (-> "ribs"); every other pattern_type must map to itself.
for (pt = PATTERN_TYPES) {
    if (pt != "none") {
        expected_tex = (pt == "ridges") ? "ribs" : pt;
        assert(_decoration_texture(pt) == expected_tex,
            str("_decoration_texture(\"", pt, "\") should be \"", expected_tex,
                "\", got \"", _decoration_texture(pt), "\""));
    }
}

// Rendering without error also wouldn't catch a regression that dropped or
// changed one of the three explicit style overrides -- BOSL2 would still
// accept an undef/wrong style and produce *some* valid-looking geometry
// (silently the wrong shape, e.g. "pyramids" reverting to mini-diamonds
// under BOSL2's default style), not an error. Pin the three overrides and
// confirm every other pattern_type has no override at all.
EXPECTED_STYLES = [
    ["diamonds", "concave"],
    ["pyramids", "convex"],
    ["bricks",   "convex"],
];
for (pair = EXPECTED_STYLES) {
    assert(_decoration_style(pair[0]) == pair[1],
        str("_decoration_style(\"", pair[0], "\") should be \"", pair[1],
            "\", got ", _decoration_style(pair[0])));
}
_styled_types = [for (pair = EXPECTED_STYLES) pair[0]];
for (pt = PATTERN_TYPES) {
    if (!in_list(pt, _styled_types)) {
        assert(_decoration_style(pt) == undef,
            str("_decoration_style(\"", pt, "\") should be undef, got ", _decoration_style(pt)));
    }
}

for (i = [0 : len(PATTERN_TYPES) - 1]) {
    translate([i * 200, 0, 0])
        decorated_solid(PATTERN_TYPES[i], "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
}
