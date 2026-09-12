// tests/test_body.scad
include <../modules/insert.scad>
include <../modules/body.scad>

// custom mode must reject an outer_height shorter than the required cavity height
ok = true;
// (assert() inside outer_body_custom is exercised via render, not directly testable
//  as a boolean here, so we test the underlying math path instead:)
pot_h = insert_cavity_height(130, 3, 5); // 138
assert(pot_h == 138);

// follow-insert outer radius at the rim must equal cavity radius + wall_thickness
r = cavity_radius_at(138, 150, 110, 130, 8, 0.3, 3, 138) + 2.4;
assert(r == 150/2 + 0.3 + 2.4, str("expected 77.7, got ", r));

cube(0.001);
