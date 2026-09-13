// tests/test_insert_presets.scad
//
// Verifies the INSERT_PRESET_NAMES / _insert_preset_dims() lookup table in
// planter.scad returns the exact documented [top_d, bottom_d, height]
// values, and that an unsupported preset name fails loudly with the list of
// accepted values (mirrors tests/test_decoration_invalid_pattern_type.scad).
include <../planter.scad>

assert(_insert_preset_dims("small") == [100, 75, 85],
    str("small preset mismatch: ", _insert_preset_dims("small")));
assert(_insert_preset_dims("medium") == [130, 100, 120],
    str("medium preset mismatch: ", _insert_preset_dims("medium")));
assert(_insert_preset_dims("large") == [180, 125, 160],
    str("large preset mismatch: ", _insert_preset_dims("large")));

echo(_insert_preset_dims("bogus"));
