// modules/insert.scad
function _lerp(a, b, t) = a + (b - a) * t;

function insert_cavity_height(insert_height, floor_thickness, bottom_margin) =
    insert_height + floor_thickness + bottom_margin;

// Above ledge_bottom_z, the cavity narrows from the loose body clearance to
// the tight rim-seat clearance over ledge_ramp_height rather than as an
// instant step -- a hard step there is an internal shelf/undercut that the
// nozzle has to travel across, which is what produces stringing right at
// the rim (see docs/gallery.md and the "Fit" Customizer section).
// ledge_ramp_height=0 recovers the original instant step exactly, since the
// third branch is then only reachable at z == ledge_bottom_z, already
// handled by the second branch.
function cavity_radius_at(z, insert_top_d, insert_bottom_d, insert_height,
                           ledge_engagement_height, fit_clearance, body_clearance,
                           pot_height, ledge_ramp_height) =
    let(
        insert_bottom_z = pot_height - insert_height,
        ledge_bottom_z  = pot_height - ledge_engagement_height,
        ledge_ramp_z    = ledge_bottom_z + ledge_ramp_height
    )
    z <= insert_bottom_z ? insert_bottom_d/2 + body_clearance :
    z <= ledge_bottom_z  ? _lerp(insert_bottom_d/2, insert_top_d/2,
                                  (z - insert_bottom_z) / (ledge_bottom_z - insert_bottom_z))
                            + body_clearance :
    z <= ledge_ramp_z    ? _lerp(insert_top_d/2 + body_clearance, insert_top_d/2 + fit_clearance,
                                  (z - ledge_bottom_z) / ledge_ramp_height) :
    insert_top_d/2 + fit_clearance;

module insert_cavity(insert_top_d, insert_bottom_d, insert_height,
                      ledge_engagement_height, fit_clearance, body_clearance,
                      bottom_margin, floor_thickness, ledge_ramp_height, overshoot=20, fn=50) {
    pot_height = insert_cavity_height(insert_height, floor_thickness, bottom_margin);
    ledge_bottom_z = pot_height - ledge_engagement_height;
    ledge_ramp_z = ledge_bottom_z + ledge_ramp_height;
    r_bottom      = cavity_radius_at(floor_thickness, insert_top_d, insert_bottom_d,
                                      insert_height, ledge_engagement_height,
                                      fit_clearance, body_clearance, pot_height, ledge_ramp_height);
    r_ledge_lower = cavity_radius_at(ledge_bottom_z, insert_top_d, insert_bottom_d,
                                      insert_height, ledge_engagement_height,
                                      fit_clearance, body_clearance, pot_height, ledge_ramp_height);
    r_ledge_upper = insert_top_d/2 + fit_clearance;

    pts = [
        [0, floor_thickness],
        [r_bottom, floor_thickness],
        [r_bottom, pot_height - insert_height],
        [r_ledge_lower, ledge_bottom_z],
        [r_ledge_upper, ledge_ramp_z],
        [r_ledge_upper, pot_height + overshoot],
        [0, pot_height + overshoot]
    ];
    rotate_extrude($fn=fn) polygon(pts);
}
