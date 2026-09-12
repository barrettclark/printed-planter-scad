// tests/test_insert.scad
include <../modules/insert.scad>

// pot_height = insert_height + floor_thickness + bottom_margin
h = insert_cavity_height(130, 3, 5);
assert(h == 138, str("expected pot_height 138, got ", h));

// At the very top (z = pot_height), radius must equal the tight ledge fit.
r_top = cavity_radius_at(138, 150, 110, 130, 8, 0.3, 3, 138);
assert(r_top == 150/2 + 0.3, str("expected ledge radius 75.3, got ", r_top));

// At the bottom of the cavity (z = floor_thickness), radius must equal the
// loose clearance-zone fit around the insert's bottom.
r_bottom = cavity_radius_at(3, 150, 110, 130, 8, 0.3, 3, 138);
assert(r_bottom == 110/2 + 3, str("expected clearance radius 58, got ", r_bottom));

cube(0.001);
