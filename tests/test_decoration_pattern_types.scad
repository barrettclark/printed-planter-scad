// tests/test_decoration_pattern_types.scad
//
// Renders decorated_solid() with every entry in modules/decoration.scad's
// PATTERN_TYPES list. A typo in that list, or in _decoration_texture()'s
// mapping, would otherwise only surface when a user actually selected the
// broken value -- this exercises all of them up front.
include <../modules/decoration.scad>

for (i = [0 : len(PATTERN_TYPES) - 1]) {
    translate([i * 200, 0, 0])
        decorated_solid(PATTERN_TYPES[i], "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
}
