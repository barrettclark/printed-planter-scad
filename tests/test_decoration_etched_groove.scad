// tests/test_decoration_etched_groove.scad
//
// relief_mode="etched" used to mean nothing more than tex_inset=true, which
// sinks the *same* raised bump below the surface -- a smooth dimple, not an
// engraving. For the three patterns that have a flat-topped/V-groove
// counterpart in BOSL2, etched now routes to that counterpart instead, so the
// surface stays flat and only the outlines are cut. This file pins that
// routing (and pins that nothing else changed for raised mode, or for the
// patterns with no counterpart).
include <../modules/decoration.scad>

// The three flat-top/V-groove counterparts, and the styles they need.
// trunc_pyramids is a heightfield whose BOSL2 doc comment says "Set
// style=\"convex\"" (lib/BOSL2/skin.scad:4022); trunc_ribs is a heightfield
// whose doc comment says "The style does not matter" (skin.scad:4040); and
// trunc_diamonds is a VNF (skin.scad:4307), so `style` does not apply at all.
EXPECTED_ETCHED = [
    ["ridges",   "trunc_ribs",      undef],
    ["pyramids", "trunc_pyramids",  "convex"],
    ["diamonds", "trunc_diamonds",  undef],
];

for (row = EXPECTED_ETCHED) {
    assert(_decoration_etched_texture(row[0]) == row[1],
        str("_decoration_etched_texture(\"", row[0], "\") should be \"", row[1],
            "\", got ", _decoration_etched_texture(row[0])));
    assert(_decoration_texture(row[0], "etched") == row[1],
        str("_decoration_texture(\"", row[0], "\", \"etched\") should be \"", row[1],
            "\", got ", _decoration_texture(row[0], "etched")));
    assert(_decoration_style(row[0], "etched") == row[2],
        str("_decoration_style(\"", row[0], "\", \"etched\") should be ", row[2],
            ", got ", _decoration_style(row[0], "etched")));
}

// Every other pattern_type has no flat-top counterpart and must keep today's
// inset-the-bump behavior: same texture in both modes.
_trunc_patterns = [for (row = EXPECTED_ETCHED) row[0]];
for (pt = PATTERN_TYPES) {
    if (pt != "none" && pt != "teardrop" && !in_list(pt, _trunc_patterns)) {
        assert(_decoration_etched_texture(pt) == undef,
            str("_decoration_etched_texture(\"", pt, "\") should be undef, got ",
                _decoration_etched_texture(pt)));
        assert(_decoration_texture(pt, "etched") == pt,
            str("_decoration_texture(\"", pt, "\", \"etched\") should fall back to \"", pt,
                "\", got ", _decoration_texture(pt, "etched")));
    }
}
assert(is_vnf(_decoration_texture("teardrop", "etched")),
    "_decoration_texture(\"teardrop\", \"etched\") should still be the VNF tile");

// Raised mode is untouched: the pre-existing mapping, unchanged.
for (pt = PATTERN_TYPES) {
    if (pt != "none" && pt != "teardrop") {
        expected = (pt == "ridges") ? "ribs" : pt;
        assert(_decoration_texture(pt, "raised") == expected,
            str("_decoration_texture(\"", pt, "\", \"raised\") should be \"", expected,
                "\", got ", _decoration_texture(pt, "raised")));
    }
}
assert(_decoration_style("diamonds", "raised") == "concave",
    "raised diamonds must keep style=\"concave\"");
assert(_decoration_style("pyramids", "raised") == "convex",
    "raised pyramids must keep style=\"convex\"");
assert(_decoration_style("bricks", "raised") == "convex",
    "raised bricks must keep style=\"convex\"");

// Real geometry, not just the mapping: a heightfield texture with the wrong
// `style` still renders, but trunc_* + tex_inset is a new code path and an
// unbuildable one would only surface on evaluation. One solid per file section
// is fine here -- none of these is the scallop-capped teardrop tile.
for (i = [0 : len(EXPECTED_ETCHED) - 1]) {
    translate([i * 200, 0, 0])
        decorated_solid(EXPECTED_ETCHED[i][0], "vertical", "etched", 1.5, 12, 75, 60, 100, 4);
}
