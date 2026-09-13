// tests/test_insert_preset_resolved.scad
//
// Verifies insert_preset actually overrides the resolved dimensions
// end-to-end through planter.scad's Customizer variables -- not just that
// _insert_preset_dims() the lookup returns the right values in isolation
// (see tests/test_insert_presets.scad), and not just that the full assembly
// renders without error under each preset (the CI variant loop for
// insert_preset) -- a regression that dropped a ternary, e.g.
// `_resolved_insert_top_d = insert_top_d;`, would still render a valid (just
// wrong) planter and pass both of those checks silently.
//
// The "custom" case is checked against whatever insert_top_d/insert_bottom_d/
// insert_height were themselves passed in via -D (see below), rather than a
// hardcoded triple -- CI passes non-default values for this case
// specifically so that a regression which resolved "custom" to the
// defaults, or to one of the named presets, would show up as a mismatch
// instead of silently matching by coincidence (a Copilot review comment on
// PR #6 pointed out the original version of this file never exercised the
// "custom" branch at all).
//
// insert_preset can't be set by pre-assignment + include (see
// tests/test_planter_integration.scad's comment on why OpenSCAD flattens
// repeated top-level assignments) -- it must be set with -D on the command
// line, once per preset, e.g.:
//
//   openscad -D 'insert_preset="small"' -o out.csg tests/test_insert_preset_resolved.scad
//   openscad -D 'insert_preset="custom"' -D 'insert_top_d=140' -D 'insert_bottom_d=90' -D 'insert_height=111' -o out.csg tests/test_insert_preset_resolved.scad
//
include <../planter.scad>

_expected_by_preset = [
    ["small",  [100, 75, 85]],
    ["medium", [130, 100, 120]],
    ["large",  [180, 125, 160]],
    ["custom", [insert_top_d, insert_bottom_d, insert_height]],
];
_match = [for (e = _expected_by_preset) if (e[0] == insert_preset) e[1]];
assert(len(_match) == 1,
    str("test_insert_preset_resolved.scad must be run with -D 'insert_preset=\"...\"' set to one of small/medium/large/custom, got \"", insert_preset, "\""));
_expected = _match[0];
// For the "custom" case, guard against the degenerate pass where CI forgot
// to override insert_top_d/insert_bottom_d/insert_height and they're still
// sitting at planter.scad's defaults (150/110/130) -- that would make this
// assert pass even if the "custom" ternary branch were completely broken
// and fell through to a preset's values instead, as long as it happened to
// fall through to a *different* wrong value than the untouched defaults...
// but to actually catch "always resolves to defaults regardless of preset"
// specifically, the defaults must differ from every preset, which they do
// (150/110/130 isn't small/medium/large) -- this guard instead catches the
// weaker mistake of CI invoking this file without the intended -D overrides.
assert(insert_preset != "custom" || _expected != [150, 110, 130],
    "test_insert_preset_resolved.scad's custom-mode CI invocation must pass -D overrides for insert_top_d/insert_bottom_d/insert_height that differ from planter.scad's defaults (150/110/130), or this test can't distinguish a working custom branch from a broken one that falls through to the defaults");

assert([_resolved_insert_top_d, _resolved_insert_bottom_d, _resolved_insert_height] == _expected,
    str("insert_preset=\"", insert_preset, "\" resolved to [",
        _resolved_insert_top_d, ", ", _resolved_insert_bottom_d, ", ", _resolved_insert_height,
        "], expected ", _expected));
