// tests/test_planter_integration.scad
// Renders planter.scad with the real 150/110/130 insert and default decoration,
// just to confirm the full assembly compiles without error.
insert_top_d = 150;
insert_bottom_d = 110;
insert_height = 130;
ledge_engagement_height = 8;
fit_clearance = 0.3;
body_clearance = 3;
bottom_margin = 5;
floor_thickness = 3;
wall_thickness = 3;
outer_mode = "follow"; // "follow" or "custom"
outer_top_d = 160;     // only used when outer_mode == "custom"
outer_bottom_d = 120;  // only used when outer_mode == "custom"
outer_height = 140;    // only used when outer_mode == "custom"
pattern_type = "ridges";       // "none" | "ridges" | "geometric"
pattern_orientation = "vertical"; // "vertical" | "horizontal"
relief_mode = "raised";           // "raised" | "etched"
pattern_depth = 1.5;
pattern_repeat = 16;
drainage_holes_enabled = true;
drainage_hole_count = 6;
drainage_hole_diameter = 4;
smoothness = 80;

include <../planter.scad>
