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

for (i = [0 : len(PATTERN_TYPES) - 1]) {
    translate([i * 200, 0, 0])
        decorated_solid(PATTERN_TYPES[i], "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
}
