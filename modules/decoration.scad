// modules/decoration.scad
include <../lib/BOSL2/std.scad>

function _decoration_texture(pattern_type, pattern_orientation) =
    pattern_type == "ridges"    ? "ribs" :
    pattern_type == "geometric" ? "diamonds" :
    undef;

module decorated_solid(pattern_type, pattern_orientation, relief_mode, pattern_depth,
                        pattern_repeat, r1, r2, height, wall_thickness, fn=50) {
    if (pattern_type == "none") {
        cylinder(h = height, r1 = r1, r2 = r2, $fn = fn);
    } else {
        assert(pattern_depth < wall_thickness * 0.7,
            str("pattern_depth (", pattern_depth, ") must be < 70% of wall_thickness (", wall_thickness, ")"));
        tex = _decoration_texture(pattern_type, pattern_orientation);
        rot = (pattern_orientation == "horizontal") ? 90 : 0;
        cyl(h = height, r1 = r1, r2 = r2, anchor = BOTTOM, $fn = fn,
            texture = tex,
            tex_reps = [pattern_repeat, pattern_repeat],
            tex_depth = pattern_depth,
            tex_inset = (relief_mode == "etched"),
            tex_rot = rot);
    }
}
