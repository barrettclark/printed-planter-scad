// tests/test_decoration_invalid_alternating_pattern.scad
//
// "alternating" is only supported for the patterns in ALTERNATING_PATTERNS,
// which grows as each one is wired. "ridges" is a BOSL2 heightfield pattern
// with no islands list at all, and will never be in that list, so this must
// fail loudly, not silently fall back to "raised".
include <../modules/decoration.scad>

decorated_solid("ridges", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
