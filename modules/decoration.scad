// modules/decoration.scad
include <../lib/BOSL2/std.scad>

// "ridges" is the one pattern_type that doesn't share its name with the
// underlying BOSL2 texture; every other valid pattern_type IS a real BOSL2
// texture name (see lib/BOSL2/shapes3d.scad's cyl() for the full catalog),
// so PATTERN_TYPES doubles as both the Customizer's valid-value list and
// the lookup table.
PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                 "bricks", "checkers", "dots", "cubes", "tri_grid"];

function _decoration_texture(pattern_type) =
    pattern_type == "ridges" ? "ribs" : pattern_type;

module decorated_solid(pattern_type, pattern_orientation, relief_mode, pattern_depth,
                        pattern_repeat, r1, r2, height, wall_thickness, fn=50) {
    assert(in_list(pattern_type, PATTERN_TYPES),
        str("pattern_type must be one of ", PATTERN_TYPES, ", got \"", pattern_type, "\""));
    if (pattern_type == "none") {
        cylinder(h = height, r1 = r1, r2 = r2, $fn = fn);
    } else {
        assert(pattern_depth < wall_thickness * 0.7,
            str("pattern_depth (", pattern_depth, ") must be < 70% of wall_thickness (", wall_thickness, ")"));
        tex = _decoration_texture(pattern_type);
        rot = (pattern_orientation == "horizontal") ? 90 : 0;
        cyl(h = height, r1 = r1, r2 = r2, anchor = BOTTOM, $fn = fn,
            texture = tex,
            tex_reps = [pattern_repeat, pattern_repeat],
            tex_depth = pattern_depth,
            tex_inset = (relief_mode == "etched"),
            tex_rot = rot);
    }
}
