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
// insert_preset can't be set by pre-assignment + include (see
// tests/test_planter_integration.scad's comment on why OpenSCAD flattens
// repeated top-level assignments) -- it must be set with -D on the command
// line, once per preset, e.g.:
//
//   openscad -D 'insert_preset="small"' -o out.csg tests/test_insert_preset_resolved.scad
//
include <../planter.scad>

_expected_by_preset = [
    ["small",  [100, 75, 85]],
    ["medium", [130, 100, 120]],
    ["large",  [180, 125, 160]],
];
_match = [for (e = _expected_by_preset) if (e[0] == insert_preset) e[1]];
assert(len(_match) == 1,
    str("test_insert_preset_resolved.scad must be run with -D 'insert_preset=\"...\"' set to one of small/medium/large, got \"", insert_preset, "\""));
_expected = _match[0];

assert([_resolved_insert_top_d, _resolved_insert_bottom_d, _resolved_insert_height] == _expected,
    str("insert_preset=\"", insert_preset, "\" resolved to [",
        _resolved_insert_top_d, ", ", _resolved_insert_bottom_d, ", ", _resolved_insert_height,
        "], expected ", _expected));
