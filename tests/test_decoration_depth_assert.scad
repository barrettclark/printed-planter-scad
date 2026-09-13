// tests/test_decoration_depth_assert.scad
include <../modules/decoration.scad>
// pattern_depth (3) is not < 70% of wall_thickness (3) — must fail.
decorated_solid("ridges", "vertical", "raised", 3, 12, 75, 60, 100, 3);
