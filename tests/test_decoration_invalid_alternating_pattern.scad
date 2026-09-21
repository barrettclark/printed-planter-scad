// tests/test_decoration_invalid_alternating_pattern.scad
//
// "alternating" is only supported for the 8 Phase-1 patterns
// (ALTERNATING_PATTERNS). "ridges" is a BOSL2 heightfield pattern with no
// islands list at all, so this must fail loudly, not silently fall back to
// "raised".
include <../modules/decoration.scad>

decorated_solid("ridges", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
