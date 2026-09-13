// modules/decoration.scad
include <../lib/BOSL2/std.scad>

// "ridges" and "none" are the only pattern_type values that don't share
// their name with a BOSL2 texture ("none" means no texture at all); every
// other valid pattern_type IS a real BOSL2 texture name (see the texture()
// catalog documented in lib/BOSL2/skin.scad), so PATTERN_TYPES doubles as
// both the Customizer's valid-value list and the lookup table.
PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                 "bricks", "checkers", "dots", "cubes", "tri_grid"];

function _decoration_texture(pattern_type) =
    pattern_type == "ridges" ? "ribs" : pattern_type;

// "diamonds", "pyramids", and "bricks" are Heightfield textures, whose grid
// samples get triangulated according to a `style` parameter. BOSL2's own
// default style ("min_edge") renders "pyramids" as flat-topped mini-diamonds
// instead of actual pyramids, and its docs call for style="convex" on both
// "pyramids" and "bricks", and style="concave" on "diamonds" for the
// expected pointed-bump look. Every other pattern_type here is a VNF
// texture (pre-triangulated), for which `style` doesn't apply.
function _decoration_style(pattern_type) =
    pattern_type == "diamonds" ? "concave" :
    pattern_type == "pyramids" ? "convex" :
    pattern_type == "bricks"   ? "convex" :
    undef;

module decorated_solid(pattern_type, pattern_orientation, relief_mode, pattern_depth,
                        pattern_repeat, r1, r2, height, wall_thickness, fn=50) {
    assert(in_list(pattern_type, PATTERN_TYPES),
        str("pattern_type must be one of ", PATTERN_TYPES, ", got \"", pattern_type, "\""));
    if (pattern_type == "none") {
        cylinder(h = height, r1 = r1, r2 = r2, $fn = fn);
    } else {
        assert(pattern_depth < wall_thickness * 0.7,
            str("pattern_depth (", pattern_depth, ") must be < 70% of wall_thickness (", wall_thickness, ")"));
        assert(pattern_repeat == round(pattern_repeat) && pattern_repeat > 0,
            str("pattern_repeat must be a positive whole number, got ", pattern_repeat));
        tex = _decoration_texture(pattern_type);
        rot = (pattern_orientation == "horizontal") ? 90 : 0;
        is_etched = (relief_mode == "etched");
        // "dots" is a raised-bump VNF texture; simply insetting it (tex_inset)
        // just shifts the same bump shape below the surface rather than
        // inverting it into a dimple. BOSL2's documented recipe for a real
        // dimple is tex_inset=1 combined with a NEGATIVE tex_depth -- every
        // other texture here inverts correctly with tex_inset alone.
        depth = (pattern_type == "dots" && is_etched) ? -pattern_depth : pattern_depth;
        cyl(h = height, r1 = r1, r2 = r2, anchor = BOTTOM, $fn = fn,
            texture = tex,
            tex_reps = [pattern_repeat, pattern_repeat],
            tex_depth = depth,
            tex_inset = is_etched,
            tex_rot = rot,
            style = _decoration_style(pattern_type));
    }
}
