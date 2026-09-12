// tests/test_bosl2_texture_smoke.scad
//
// Available BOSL2 texture names (found in lib/BOSL2/skin.scad, texture()
// function docs, since this BOSL2 checkout has no separate textures.scad):
//   "bricks", "bricks_vnf", "checkers", "cones", "cubes", "diamonds",
//   "diamonds_vnf", "dots", "hex_grid", "hills", "pyramids", "pyramids_vnf",
//   "ribs", "rough", "tri_grid", "trunc_diamonds", "trunc_pyramids_vnf",
//   "trunc_pyramids", "trunc_ribs_vnf", "trunc_ribs", "wave_ribs"
// Task 5 (decoration module) depends on these exact strings.
include <../lib/BOSL2/std.scad>

// Confirms this OpenSCAD version can build a textured cylinder using BOSL2.
cyl(h=20, r1=10, r2=8, texture="ribs", tex_size=[10,10], tex_depth=1, $fn=64);
