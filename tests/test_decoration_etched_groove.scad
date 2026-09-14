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

// The three patterns with a flat-top/V-groove counterpart, and the counterpart
// each one resolves to. "ridges" and "pyramids" go to BOSL2's *_vnf variants
// built through texture() with an explicit narrow border, not to the bare
// "trunc_ribs"/"trunc_pyramids" heightfields: those have a fixed, wide profile
// with no groove-width parameter. All three counterparts are VNFs
// (lib/BOSL2/skin.scad:4095, 4180, 4307), so none of them takes a `style`.
EXPECTED_ETCHED = [
    ["ridges",   texture("trunc_ribs_vnf", gap = 0, border = _ETCH_BORDER)],
    ["pyramids", texture("trunc_pyramids_vnf", border = _ETCH_BORDER)],
    ["diamonds", "trunc_diamonds"],
];

for (row = EXPECTED_ETCHED) {
    assert(_decoration_etched_texture(row[0]) == row[1],
        str("_decoration_etched_texture(\"", row[0], "\") is not the expected counterpart"));
    assert(_decoration_texture(row[0], "etched") == row[1],
        str("_decoration_texture(\"", row[0], "\", \"etched\") is not the expected counterpart"));
    // Every counterpart is a VNF, so none of them may carry a style override.
    assert(_decoration_style(row[0], "etched") == undef,
        str("_decoration_style(\"", row[0], "\", \"etched\") should be undef (VNF counterpart), got ",
            _decoration_style(row[0], "etched")));
}

// "ridges" and "pyramids" specifically must be VNFs now -- if either silently
// reverted to the bare heightfield name the assertions above would still hold
// against a stale EXPECTED_ETCHED, and the whole point of this task is the
// narrow, parameterised groove the heightfields cannot produce.
assert(is_vnf(_decoration_texture("ridges", "etched")),
    "etched \"ridges\" must resolve to a VNF (trunc_ribs_vnf), not a heightfield name");
assert(is_vnf(_decoration_texture("pyramids", "etched")),
    "etched \"pyramids\" must resolve to a VNF (trunc_pyramids_vnf), not a heightfield name");
// A wide groove would defeat the purpose; keep the land dominant.
assert(_ETCH_BORDER > 0 && _ETCH_BORDER <= 0.1,
    str("_ETCH_BORDER should stay a narrow groove (0 < b <= 0.1), got ", _ETCH_BORDER));

// The hand-rolled VNF tiles have no flat-top counterpart either, but unlike the
// patterns below they do not map to their own name -- they map to the tile --
// so they are excluded here and checked on their own further down.
VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine", "islamic_star"];

// Every other pattern_type has no flat-top counterpart and must keep today's
// inset-the-bump behavior: same texture in both modes, and therefore the same
// style in both modes. _decoration_style() resolves the texture itself, so
// etched is a genuinely separate code path for style too -- pin the parity.
_trunc_patterns = [for (row = EXPECTED_ETCHED) row[0]];
for (pt = PATTERN_TYPES) {
    if (pt != "none" && !in_list(pt, VNF_PATTERN_TYPES) && !in_list(pt, _trunc_patterns)) {
        assert(_decoration_etched_texture(pt) == undef,
            str("_decoration_etched_texture(\"", pt, "\") should be undef, got ",
                _decoration_etched_texture(pt)));
        assert(_decoration_texture(pt, "etched") == pt,
            str("_decoration_texture(\"", pt, "\", \"etched\") should fall back to \"", pt,
                "\", got ", _decoration_texture(pt, "etched")));
        assert(_decoration_style(pt, "etched") == _decoration_style(pt, "raised"),
            str("_decoration_style(\"", pt, "\") should not depend on relief_mode: raised gives ",
                _decoration_style(pt, "raised"), ", etched gives ", _decoration_style(pt, "etched")));
    }
}
// The parity assert above compares the two modes against each other, so both
// could be wrong together. Pin one absolutely: "bricks" is the only non-trunc
// pattern with a style override, and losing it silently changes its shape.
assert(_decoration_style("bricks", "etched") == "convex",
    str("_decoration_style(\"bricks\", \"etched\") should be \"convex\", got ",
        _decoration_style("bricks", "etched")));
// The VNF tiles have no flat-top counterpart: etched must keep the raised tile
// (and fall back to insetting it), not silently route somewhere else.
for (pt = VNF_PATTERN_TYPES) {
    assert(in_list(pt, PATTERN_TYPES), str("\"", pt, "\" is not a pattern_type"));
    assert(_decoration_etched_texture(pt) == undef,
        str("_decoration_etched_texture(\"", pt, "\") should be undef, got ",
            _decoration_etched_texture(pt)));
    assert(is_vnf(_decoration_texture(pt, "etched")),
        str("_decoration_texture(\"", pt, "\", \"etched\") should still be the VNF tile"));
    assert(_decoration_texture(pt, "etched") == _decoration_texture(pt, "raised"),
        str("\"", pt, "\" must resolve to the same tile in both relief modes"));
    assert(_decoration_style(pt, "etched") == undef,
        str("_decoration_style(\"", pt, "\", \"etched\") should be undef (VNF tile), got ",
            _decoration_style(pt, "etched")));
}

// Raised mode is untouched: the pre-existing mapping, unchanged.
for (pt = PATTERN_TYPES) {
    if (pt != "none" && !in_list(pt, VNF_PATTERN_TYPES)) {
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
