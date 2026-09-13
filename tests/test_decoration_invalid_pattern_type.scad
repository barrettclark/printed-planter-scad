// tests/test_decoration_invalid_pattern_type.scad
//
// An unsupported pattern_type must fail loudly with the list of accepted
// values, not silently pass through to BOSL2's cyl() with a cryptic error.
include <../modules/decoration.scad>

decorated_solid("bogus", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
