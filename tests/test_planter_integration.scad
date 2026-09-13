// tests/test_planter_integration.scad
// Verifies the full assembly compiles cleanly with default Customizer values
// (the real 150/110/130 insert). Note: pre-include variable assignment does
// NOT override planter.scad's defaults here — OpenSCAD flattens repeated
// top-level assignments to the textually last one, so a caller can't set
// these variables before `include`-ing the file. To exercise non-default
// values, use -D on the command line instead, e.g.:
//
//   openscad -D 'drainage_holes_enabled=true' -o out.csg tests/test_planter_integration.scad
//
include <../planter.scad>
