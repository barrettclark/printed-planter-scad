// modules/body.scad
include <insert.scad>

module outer_body_follow(insert_top_d, insert_bottom_d, insert_height,
                          ledge_engagement_height, fit_clearance, body_clearance,
                          bottom_margin, floor_thickness, wall_thickness, fn=50) {
    pot_height = insert_cavity_height(insert_height, floor_thickness, bottom_margin);
    steps = 40;
    pts = concat(
        [[0, 0]],
        [ for (i = [0:steps])
            let(
                z  = pot_height * i / steps,
                zc = max(z, floor_thickness),
                r  = cavity_radius_at(zc, insert_top_d, insert_bottom_d, insert_height,
                                       ledge_engagement_height, fit_clearance,
                                       body_clearance, pot_height) + wall_thickness
            )
            [r, z]
        ],
        [[0, pot_height]]
    );
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
