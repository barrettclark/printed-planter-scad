// modules/insert.scad
function _lerp(a, b, t) = a + (b - a) * t;

function insert_cavity_height(insert_height, floor_thickness, bottom_margin) =
    insert_height + floor_thickness + bottom_margin;

function cavity_radius_at(z, insert_top_d, insert_bottom_d, insert_height,
                           ledge_engagement_height, fit_clearance, body_clearance,
                           pot_height) =
    let(
        insert_bottom_z = pot_height - insert_height,
        ledge_bottom_z  = pot_height - ledge_engagement_height
    )
    z <= insert_bottom_z ? insert_bottom_d/2 + body_clearance :
    z <  ledge_bottom_z  ? _lerp(insert_bottom_d/2, insert_top_d/2,
                                  (z - insert_bottom_z) / (ledge_bottom_z - insert_bottom_z))
                            + body_clearance :
    insert_top_d/2 + fit_clearance;

module insert_cavity(insert_top_d, insert_bottom_d, insert_height,
                      ledge_engagement_height, fit_clearance, body_clearance,
                      bottom_margin, floor_thickness, overshoot=20, fn=50) {
    pot_height = insert_cavity_height(insert_height, floor_thickness, bottom_margin);
    ledge_bottom_z = pot_height - ledge_engagement_height;
    r_bottom      = cavity_radius_at(floor_thickness, insert_top_d, insert_bottom_d,
                                      insert_height, ledge_engagement_height,
                                      fit_clearance, body_clearance, pot_height);
    r_ledge_lower = cavity_radius_at(ledge_bottom_z, insert_top_d, insert_bottom_d,
                                      insert_height, ledge_engagement_height,
                                      fit_clearance, body_clearance, pot_height);
    r_ledge_upper = insert_top_d/2 + fit_clearance;

    pts = [
        [0, floor_thickness],
        [r_bottom, floor_thickness],
        [r_bottom, pot_height - insert_height],
        [r_ledge_lower, ledge_bottom_z],
        [r_ledge_upper, ledge_bottom_z],
        [r_ledge_upper, pot_height + overshoot],
        [0, pot_height + overshoot]
    ];
    rotate_extrude($fn=fn) polygon(pts);
}
