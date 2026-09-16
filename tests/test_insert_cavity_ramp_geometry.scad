// tests/test_insert_cavity_ramp_geometry.scad
//
// Geometry-level check that insert_cavity()'s actual rendered boundary --
// not just cavity_radius_at()'s numbers -- follows the ramp. test_insert.scad
// only checks the standalone cavity_radius_at() function; the module's own
// polygon could independently drift from it (e.g. a copy-paste error that
// left insert_cavity()'s [r_ledge_upper, ledge_bottom_z] point unchanged)
// and still pass every purely numeric check.
//
// Renders a thin slab of insert_cavity() at a specific z, and two "violation"
// shapes: one non-empty if the actual radius there is smaller than expected
// (minus a tolerance), one non-empty if larger (plus a tolerance). Their
// union must render EMPTY for the check to pass -- the same "must be empty"
// idiom test_wall_thickness_invariant.scad already uses, forcing a real
// CGAL evaluation via .stl export rather than a .csg compile check.
//
// check: 0 = ledge_ramp_height=0, just above the boundary, expect tight
//            radius immediately (the hard step must still work exactly as
//            before)
//        1 = ledge_ramp_height=2, 0.2mm above the boundary (10% into the
//            ramp), expect the correspondingly-interpolated radius, not
//            the fully tight one -- proves the module actually ramps
//            rather than still jumping straight to tight
//        2 = ledge_ramp_height=2, just past ledge_ramp_z, expect the tight
//            radius (the ramp must have finished narrowing by here)
//
// Sample points are offset from the profile's breakpoints (not placed
// exactly on them): a rotate_extrude polygon has a genuine sharp corner at
// each breakpoint, and slicing a wafer-thin slab exactly there produced a
// degenerate zero-volume CGAL sliver in testing ("Simple: no", 1 facet) --
// a meshing artifact, not a real geometry mismatch. 0.2mm clears that
// reliably while staying well inside the 2mm ramp for check 1.
check = 0;

include <../modules/insert.scad>

insert_top_d = 150;
insert_bottom_d = 110;
insert_height = 130;
ledge_engagement_height = 8;
fit_clearance = 0.3;
body_clearance = 3;
bottom_margin = 5;
floor_thickness = 3;

ledge_ramp_height = (check == 0) ? 0 : 2;

pot_height = insert_cavity_height(insert_height, floor_thickness, bottom_margin); // 138
ledge_bottom_z = pot_height - ledge_engagement_height; // 130
ledge_ramp_z = ledge_bottom_z + ledge_ramp_height;

r_loose = insert_top_d/2 + body_clearance; // 78
r_tight = insert_top_d/2 + fit_clearance;  // 75.3

offset = 0.2;
z_sample = (check == 2) ? ledge_ramp_z + offset : ledge_bottom_z + offset;
// Independently re-derived (not by calling cavity_radius_at()) so this
// checks insert_cavity()'s own polygon against a separately-computed
// expectation, not against the same function it's meant to be verified
// against.
r_expected = (check == 0) ? r_tight :
             (check == 1) ? r_loose - (offset / ledge_ramp_height) * (r_loose - r_tight) :
             r_tight;

tol = 0.05;
slab_h = 0.02;

module cavity_slab(z) {
    intersection() {
        insert_cavity(insert_top_d, insert_bottom_d, insert_height,
            ledge_engagement_height, fit_clearance, body_clearance,
            bottom_margin, floor_thickness, ledge_ramp_height, overshoot=0, fn=180);
        translate([0, 0, z - slab_h/2]) cylinder(h=slab_h, r=500, $fn=8);
    }
}

module expected_slab(z, r) {
    translate([0, 0, z - slab_h/2]) cylinder(h=slab_h, r=r, $fn=180);
}

union() {
    // Non-empty if the actual radius at z_sample is smaller than expected.
    difference() {
        expected_slab(z_sample, r_expected - tol);
        cavity_slab(z_sample);
    }
    // Non-empty if the actual radius at z_sample is larger than expected.
    difference() {
        cavity_slab(z_sample);
        expected_slab(z_sample, r_expected + tol);
    }
}
