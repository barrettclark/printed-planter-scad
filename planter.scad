// planter.scad
include <lib/BOSL2/std.scad>
include <modules/insert.scad>
include <modules/insert_presets.scad>
include <modules/body.scad>
include <modules/decoration.scad>
include <modules/base.scad>

// A caller can't override these via pre-assignment + include: OpenSCAD
// flattens repeated top-level assignments to the last one, even under
// is_undef() guards. These are just this file's fixed defaults.

/* [Insert Dimensions] */
insert_preset = "custom"; // ["custom:Custom (set fields below)", "small:Small (100x85 / 75mm bottom)", "medium:Medium (130x120 / 100mm bottom)", "large:Large (180x160 / 125mm bottom)"]
insert_top_d = 150;     // top rim diameter (mm) -- used when insert_preset == "custom"
insert_bottom_d = 110;  // bottom diameter (mm) -- used when insert_preset == "custom"
insert_height = 130;    // insert height (mm) -- used when insert_preset == "custom"

// Internal only -- not a Customizer field. Hidden so the resolved values
// (derived from insert_preset, not user-editable themselves) don't show up
// as bogus extra widgets in the Customizer GUI.
/* [Hidden] */
_resolved_insert_top_d    = (insert_preset == "custom") ? insert_top_d    : _insert_preset_dims(insert_preset)[0];
_resolved_insert_bottom_d = (insert_preset == "custom") ? insert_bottom_d : _insert_preset_dims(insert_preset)[1];
_resolved_insert_height   = (insert_preset == "custom") ? insert_height   : _insert_preset_dims(insert_preset)[2];

/* [Fit] */
ledge_engagement_height = 8; // depth of the rim's tight-fit seat (mm)
fit_clearance = 0.3;         // radial clearance at the rim seat (mm)
body_clearance = 3;          // radial clearance around the tapered insert body (mm)
bottom_margin = 5;           // air gap below the insert's bottom (mm)

/* [Outer Shape] */
outer_mode = "follow"; // ["follow", "custom"]
wall_thickness = 3;     // used in follow mode (mm)
outer_top_d = 172;      // used in custom mode (mm)
outer_bottom_d = 130;   // used in custom mode (mm)
outer_height = 145;     // used in custom mode (mm)

/* [Decoration] */
pattern_type = "ridges";           // ["none", "ridges", "diamonds", "hex_grid", "pyramids", "bricks", "checkers", "dots", "cubes", "tri_grid"]
pattern_orientation = "vertical";  // ["vertical", "horizontal"]
relief_mode = "raised";            // ["raised", "etched"]
pattern_depth = 1.5;    // mm
pattern_repeat = 16;    // tile count around circumference

/* [Base] */
floor_thickness = 3;              // mm
drainage_holes_enabled = false;    // add drainage holes to the solid floor
drainage_hole_count = 6;
drainage_hole_diameter = 4;

/* [Quality] */
smoothness = 80; // $fn used for all revolved geometry

assert(in_list(insert_preset, concat(["custom"], INSERT_PRESET_NAMES)),
    str("insert_preset must be \"custom\" or one of ", INSERT_PRESET_NAMES, ", got \"", insert_preset, "\""));
assert(_resolved_insert_bottom_d < _resolved_insert_top_d,
    "insert_bottom_d must be smaller than insert_top_d (insert tapers inward)");
assert(wall_thickness > 0, "wall_thickness must be > 0");
assert(outer_mode == "follow" || outer_mode == "custom",
    str("outer_mode must be \"follow\" or \"custom\", got \"", outer_mode, "\""));
assert(in_list(pattern_type, PATTERN_TYPES),
    str("pattern_type must be one of ", PATTERN_TYPES, ", got \"", pattern_type, "\""));
// Depends on pattern_type already being valid, so it must come after the
// pattern_type assert above -- otherwise an invalid pattern_type combined
// with an out-of-range pattern_depth would report the depth error first
// and never surface the accepted pattern_type list.
assert(pattern_depth < wall_thickness * 0.7 || pattern_type == "none",
    "pattern_depth must be < 70% of wall_thickness");

pot_height = insert_cavity_height(_resolved_insert_height, floor_thickness, bottom_margin);

assert(outer_mode != "custom" || outer_height >= pot_height,
    str("outer_height (", outer_height, ") must be >= required cavity height (", pot_height, ") in custom mode"));

// Radial containment check for custom mode: the outer profile's linear taper
// must clear the cavity (plus wall_thickness) everywhere. cavity_radius_at is
// constant below insert_bottom_z, linear between insert_bottom_z and
// ledge_bottom_z, then constant (tight) above ledge_bottom_z, so the
// difference (outer_r - cavity_r) is piecewise linear too -- its minimum on
// each sub-interval falls at an endpoint, giving four breakpoints to check:
// the cavity's own floor (z=floor_thickness), the insert's physical bottom
// (insert_bottom_z), the ledge's loose-side bulge, and the tight-fit rim.
// The cavity is translated up by z_offset in custom mode, so each breakpoint
// lands at (breakpoint + z_offset) in the outer body's own z coordinates.
_insert_bottom_z = pot_height - _resolved_insert_height;
_ledge_bottom_z = pot_height - ledge_engagement_height;
_custom_z_offset = outer_height - pot_height;
_outer_r_at = function (z) outer_bottom_d/2 + (outer_top_d/2 - outer_bottom_d/2) * (z / outer_height);
_custom_breakpoints = [
    [floor_thickness, "the cavity floor"],
    [_insert_bottom_z, "the insert's bottom"],
    [_ledge_bottom_z, "the ledge bulge"],
    [pot_height, "the rim"],
];
for (bp = _custom_breakpoints) {
    _z = bp[0];
    _label = bp[1];
    _r_cavity = cavity_radius_at(_z, _resolved_insert_top_d, _resolved_insert_bottom_d, _resolved_insert_height,
        ledge_engagement_height, fit_clearance, body_clearance, pot_height);
    _z_outer = _z + _custom_z_offset;
    assert(outer_mode != "custom" || _outer_r_at(_z_outer) >= _r_cavity + wall_thickness,
        str("custom outer profile is too thin at ", _label, " (z=", _z_outer,
            "): has radius ", _outer_r_at(_z_outer), ", needs >= ", _r_cavity + wall_thickness));
}

module planter() {
    difference() {
        // outer body (plain or decorated) --------------------------------
        if (pattern_type == "none") {
            if (outer_mode == "custom") {
                outer_body_custom(outer_top_d, outer_bottom_d, outer_height, pot_height, fn=smoothness);
            } else {
                outer_body_follow(_resolved_insert_top_d, _resolved_insert_bottom_d, _resolved_insert_height,
                    ledge_engagement_height, fit_clearance, body_clearance,
                    bottom_margin, floor_thickness, wall_thickness, fn=smoothness);
            }
        } else {
            // decorated_solid only supports a straight r1/r2 cone. cavity_radius_at()
            // bulges out at ledge_bottom_z before narrowing for the rim seat, so
            // anchoring the cone at just the two z-endpoints undershoots that bulge
            // and punches a hole through the wall (seen in a preview render).
            // Extrapolate through the true peak instead so the cone envelopes it.
            ledge_bottom_z = pot_height - ledge_engagement_height;
            r_bottom = (outer_mode == "custom") ? outer_bottom_d/2
                    : cavity_radius_at(floor_thickness, _resolved_insert_top_d, _resolved_insert_bottom_d, _resolved_insert_height,
                        ledge_engagement_height, fit_clearance, body_clearance, pot_height) + wall_thickness;
            r_at_ledge = cavity_radius_at(ledge_bottom_z, _resolved_insert_top_d, _resolved_insert_bottom_d, _resolved_insert_height,
                        ledge_engagement_height, fit_clearance, body_clearance, pot_height) + wall_thickness;
            r_at_pot_top = cavity_radius_at(pot_height, _resolved_insert_top_d, _resolved_insert_bottom_d, _resolved_insert_height,
                        ledge_engagement_height, fit_clearance, body_clearance, pot_height) + wall_thickness;
            // peak = whichever of the ledge bulge or the rim itself needs more room
            z_peak = (r_at_ledge >= r_at_pot_top) ? ledge_bottom_z : pot_height;
            r_peak = max(r_at_ledge, r_at_pot_top);
            r_top = (outer_mode == "custom") ? outer_top_d/2
                    : (z_peak <= floor_thickness ? r_peak
                        : r_bottom + (r_peak - r_bottom) * (pot_height - floor_thickness) / (z_peak - floor_thickness));
            h = (outer_mode == "custom") ? outer_height : pot_height;
            decorated_solid(pattern_type, pattern_orientation, relief_mode, pattern_depth,
                pattern_repeat, r_bottom, r_top, h, wall_thickness, fn=smoothness);
        }

        // cavity -----------------------------------------------------------
        z_offset = (outer_mode == "custom") ? (outer_height - pot_height) : 0;
        translate([0, 0, z_offset])
            insert_cavity(_resolved_insert_top_d, _resolved_insert_bottom_d, _resolved_insert_height,
                ledge_engagement_height, fit_clearance, body_clearance,
                bottom_margin, floor_thickness, fn=smoothness);

        // drainage -----------------------------------------------------------
        if (drainage_holes_enabled) {
            r_bottom_cavity = cavity_radius_at(floor_thickness, _resolved_insert_top_d, _resolved_insert_bottom_d,
                _resolved_insert_height, ledge_engagement_height, fit_clearance, body_clearance, pot_height);
            // Extend hole length by z_offset (rather than translating the whole
            // call) so the hole still starts below the true exterior bottom
            // face at z=0 -- translating up by z_offset would detach the hole
            // from that face, creating a new blind pocket from the other end.
            drainage_holes(drainage_hole_count, drainage_hole_diameter,
                r_bottom_cavity * 0.6, floor_thickness + z_offset);
        }
    }
}

planter();
