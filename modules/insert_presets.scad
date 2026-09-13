// modules/insert_presets.scad
//
// Single source of truth for the Customizer's insert_preset dropdown list
// and the dimensions each named preset resolves to (mirrors PATTERN_TYPES
// in modules/decoration.scad). Lives in an included file rather than
// directly under planter.scad's `/* [Insert Dimensions] */` Customizer
// section -- OpenSCAD's Customizer GUI only scans variables declared in the
// top-level file, so anything in an included file never shows up as an
// editable field.
INSERT_PRESET_NAMES = ["small", "medium", "large"];
// [top_d, bottom_d, height]; documented in README.md's insert_preset table.
_INSERT_PRESET_DIMS = [
    [100, 75, 85],
    [130, 100, 120],
    [180, 125, 160],
];
assert(len(INSERT_PRESET_NAMES) == len(_INSERT_PRESET_DIMS),
    "INSERT_PRESET_NAMES and _INSERT_PRESET_DIMS must be the same length");

function _insert_preset_dims(name) =
    let(i = search([name], INSERT_PRESET_NAMES)[0])
    assert(is_num(i), str("insert_preset must be \"custom\" or one of ", INSERT_PRESET_NAMES, ", got \"", name, "\""))
    _INSERT_PRESET_DIMS[i];
