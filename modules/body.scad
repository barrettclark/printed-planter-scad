// modules/body.scad
include <insert.scad>

module outer_body_follow(insert_top_d, insert_bottom_d, insert_height,
                          ledge_engagement_height, fit_clearance, body_clearance,
                          bottom_margin, floor_thickness, wall_thickness,
                          ledge_ramp_height, fn=50) {
    pot_height = insert_cavity_height(insert_height, floor_thickness, bottom_margin);
    insert_bottom_z = pot_height - insert_height;
    ledge_bottom_z  = pot_height - ledge_engagement_height;
    ledge_ramp_z    = ledge_bottom_z + ledge_ramp_height;

    // Same breakpoints insert_cavity() uses, each offset outward by wall_thickness.
    // The cavity profile is piecewise linear between these z values, so linear
    // interpolation between exact-breakpoint points here is exact everywhere,
    // not just at sampled points.
    r_floor        = cavity_radius_at(floor_thickness, insert_top_d, insert_bottom_d,
                                       insert_height, ledge_engagement_height, fit_clearance,
                                       body_clearance, pot_height, ledge_ramp_height) + wall_thickness;
    r_insert_bot   = cavity_radius_at(insert_bottom_z, insert_top_d, insert_bottom_d,
                                       insert_height, ledge_engagement_height, fit_clearance,
                                       body_clearance, pot_height, ledge_ramp_height) + wall_thickness;
    r_ledge_lower  = cavity_radius_at(ledge_bottom_z, insert_top_d, insert_bottom_d,
                                       insert_height, ledge_engagement_height, fit_clearance,
                                       body_clearance, pot_height, ledge_ramp_height) + wall_thickness;
    r_ledge_upper  = insert_top_d/2 + fit_clearance + wall_thickness;

    pts = [
        [0, 0],
        [r_floor, 0],
        [r_floor, floor_thickness],
        [r_insert_bot, insert_bottom_z],
        [r_ledge_lower, ledge_bottom_z],
        [r_ledge_upper, ledge_ramp_z],
        [r_ledge_upper, pot_height],
        [0, pot_height]
    ];
    rotate_extrude($fn=fn) polygon(pts);
}

module outer_body_custom(outer_top_d, outer_bottom_d, outer_height, pot_height, fn=50) {
    assert(outer_height >= pot_height,
        str("outer_height (", outer_height, ") must be >= required cavity height (", pot_height, ")"));
    pts = [
        [0, 0],
        [outer_bottom_d/2, 0],
        [outer_top_d/2, outer_height],
        [0, outer_height]
    ];
    rotate_extrude($fn=fn) polygon(pts);
}
