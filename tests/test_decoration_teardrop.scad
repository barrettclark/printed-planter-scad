// tests/test_decoration_teardrop.scad
//
// "teardrop" is the first pattern_type that maps to a custom VNF tile rather
// than a BOSL2 texture name, so it needs its own real-render check: an invalid
// tile (points outside the unit square, edges that don't line up across the
// tile boundary, a non-manifold result) only surfaces when the geometry is
// actually evaluated.
//
// One solid, not one per relief_mode: unlike every other pattern_type, the
// teardrop tile's raised geometry crosses the tile's y edges, so a textured
// cylinder gets scalloped (non-circular) end caps. Two such solids in one file
// trip a CGAL assertion inside OpenSCAD 2021.01's union -- see the note in
// modules/decoration.scad. relief_mode="etched" is covered by the per-pattern
// and full-assembly loops in .github/workflows/test.yml, which evaluate one
// solid at a time.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("teardrop", PATTERN_TYPES), "PATTERN_TYPES must contain \"teardrop\"");

_tex = _decoration_texture("teardrop");
assert(is_list(_tex) && len(_tex) == 2,
    "_decoration_texture(\"teardrop\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex), "_decoration_texture(\"teardrop\") must be a valid VNF");

// A VNF texture tile's footprint must lie inside the unit square with Z in
// [0,1]; BOSL2 rejects anything else at render time.
_bounds = pointlist_bounds(_tex[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("teardrop tile must fit in the unit cube, got bounds ", _bounds));

// VNF tiles take no `style` (that's a heightfield-triangulation setting).
assert(_decoration_style("teardrop") == undef,
    "teardrop is a VNF tile and must not carry a style override");

difference() {
    decorated_solid("teardrop", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
