// tests/test_decoration_invalid_relief_mode.scad
//
// relief_mode was never validated before this plan. Two failure modes:
// a bogus string, and "alternating" on a pattern_type that doesn't support
// it (any of the 13 patterns outside ALTERNATING_PATTERNS).
include <../modules/decoration.scad>

decorated_solid("ridges", "vertical", "bogus", 1.5, 12, 75, 60, 100, 4);
