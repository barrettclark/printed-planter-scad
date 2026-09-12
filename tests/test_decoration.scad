// tests/test_decoration.scad
include <../modules/decoration.scad>

// "none" must produce plain geometry without needing BOSL2 at all.
decorated_solid("none", "vertical", "raised", 1, 8, 50, 75, 100, 3);
