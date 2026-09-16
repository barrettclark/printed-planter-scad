// tests/test_insert.scad
include <../modules/insert.scad>

// pot_height = insert_height + floor_thickness + bottom_margin
h = insert_cavity_height(130, 3, 5);
assert(h == 138, str("expected pot_height 138, got ", h));

// At the very top (z = pot_height), radius must equal the tight ledge fit.
r_top = cavity_radius_at(138, 150, 110, 130, 8, 0.3, 3, 138, 2);
assert(r_top == 150/2 + 0.3, str("expected ledge radius 75.3, got ", r_top));

// At the bottom of the cavity (z = floor_thickness), radius must equal the
// loose clearance-zone fit around the insert's bottom.
r_bottom = cavity_radius_at(3, 150, 110, 130, 8, 0.3, 3, 138, 2);
assert(r_bottom == 110/2 + 3, str("expected clearance radius 58, got ", r_bottom));

// At the ledge boundary (z = ledge_bottom_z = 130), radius must equal the loose
// (body_clearance) radius, not the tight (fit_clearance) radius. This ensures
// r_ledge_lower != r_ledge_upper for a visible shoulder/step in the polygon.
r_ledge_at_boundary = cavity_radius_at(130, 150, 110, 130, 8, 0.3, 3, 138, 2);
assert(r_ledge_at_boundary == 150/2 + 3, str("expected ledge boundary radius 78, got ", r_ledge_at_boundary));
assert(r_ledge_at_boundary != 150/2 + 0.3, str("r_ledge_lower must differ from r_ledge_upper for step"));

// Midway through the ramp (z = ledge_bottom_z + ledge_ramp_height/2 = 131),
// radius must be exactly halfway between the loose and tight radii -- not
// an instant jump to the tight radius.
r_ledge_mid_ramp = cavity_radius_at(131, 150, 110, 130, 8, 0.3, 3, 138, 2);
assert(r_ledge_mid_ramp == (150/2 + 3 + 150/2 + 0.3) / 2,
    str("expected midpoint ledge radius 76.65, got ", r_ledge_mid_ramp));

// ledge_ramp_height=0 must recover the original instant step exactly (a
// caller can dial the ramp back to nothing without a separate code path).
r_hard_step = cavity_radius_at(130, 150, 110, 130, 8, 0.3, 3, 138, 0);
assert(r_hard_step == 150/2 + 3, str("expected hard-step ledge radius 78, got ", r_hard_step));
r_hard_step_above = cavity_radius_at(130.0001, 150, 110, 130, 8, 0.3, 3, 138, 0);
assert(r_hard_step_above == 150/2 + 0.3,
    str("expected hard-step tight radius immediately above the boundary, got ", r_hard_step_above));

cube(0.001);
