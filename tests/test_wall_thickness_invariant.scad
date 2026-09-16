// tests/test_wall_thickness_invariant.scad
//
// Regression test for the outer_body_follow wall-thickness bug: uniform
// sampling could straddle the cavity's ledge peak, letting the wall thin
// below wall_thickness (or vanish entirely at high body_clearance).
//
// Correct check: difference(cavity, outer_body) must render EMPTY -- if any
// part of the cavity pokes through the outer wall, the difference is
// non-empty. OpenSCAD prints "Current top level object is empty." to
// stderr/stdout when the top-level result truly is empty; that string's
// presence is the pass signal.
//
// This file has one active combo (selected below) since each combo must be
// run/checked independently via the openscad CLI. See the report for the
// exact commands and their PASS/FAIL output for all 3 combos.
//
// Combo selector: 0 = shipped defaults, 1 = larger body_clearance (6),
// 2 = alternate insert dimensions.
combo = 0;

include <../modules/insert.scad>
include <../modules/body.scad>

params = [
    // [insert_top_d, insert_bottom_d, insert_height, ledge_engagement_height,
    //  fit_clearance, body_clearance, bottom_margin, floor_thickness, wall_thickness]
    [150, 110, 130, 8, 0.3, 3, 5, 3, 3],   // 0: shipped defaults
    [150, 110, 130, 8, 0.3, 6, 5, 3, 3],   // 1: larger body_clearance
    [180, 90,  100, 10, 0.5, 4, 6, 4, 2.5] // 2: alternate insert dimensions
];

p = params[combo];

// Not varied across combos -- this invariant is about radial wall thickness,
// which the ramp doesn't change at either endpoint, only the shape between
// them (see modules/insert.scad). Same value must reach both calls below,
// since insert_cavity and outer_body_follow are meant to be mirror shapes.
ledge_ramp_height = 2;

// overshoot=0: insert_cavity's default overshoot pokes the cavity above
// pot_height (intentional in the real assembly, to punch through the rim of
// a taller outer body) which would make this difference falsely non-empty
// above pot_height where outer_body_follow's solid ends. Capping overshoot
// at 0 keeps both solids' z-domains aligned at [floor_thickness/0, pot_height]
// so the check is purely about radial wall thickness.
difference() {
    insert_cavity(p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], overshoot=0, fn=80,
        ledge_ramp_height=ledge_ramp_height);
    outer_body_follow(p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], fn=80,
        ledge_ramp_height=ledge_ramp_height);
}
