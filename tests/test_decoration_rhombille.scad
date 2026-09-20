// tests/test_decoration_rhombille.scad
//
// "rhombille" is a custom VNF tile (the plain rhombille tiling tumbling_cubes'
// isometric illusion is built from, every rhombus at the same height instead
// of three), not a BOSL2 texture name, so it needs a real-render check: a
// tile whose points leave the unit square, whose edges don't line up across
// the tile boundary, or whose walls are wound backwards only fails when the
// geometry is actually evaluated.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("rhombille", PATTERN_TYPES),
    "PATTERN_TYPES must contain \"rhombille\"");

_tex = _decoration_texture("rhombille", "raised");
assert(is_list(_tex) && len(_tex) == 2,
    "_decoration_texture(\"rhombille\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex), "_decoration_texture(\"rhombille\") must be a valid VNF");

// A VNF texture tile's footprint must lie inside the unit square with Z in
// [0,1]; BOSL2 rejects anything else at render time.
_bounds = pointlist_bounds(_tex[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("rhombille tile must fit in the unit cube, got bounds ", _bounds));

// VNF tiles take no `style` (that's a heightfield-triangulation setting), and
// _decoration_style() must reach that answer from the resolved texture rather
// than from a pattern_type-specific branch.
assert(_decoration_style("rhombille", "raised") == undef,
    "rhombille is a VNF tile and must not carry a style override");
assert(_decoration_style("rhombille", "etched") == undef,
    "rhombille is a VNF tile and must not carry a style override when etched");

// Unlike tumbling_cubes, every rhombus in rhombille sits at the SAME height,
// and it's the tile's full height: this pattern is a plain rhombus grid, not
// an isometric-cube illusion, and pattern_depth should be fully used. Check
// the constant AND the actual VNF -- asserting _RH_Z alone would still pass
// if _rhombille_tile() accidentally used tumbling_cubes' own _TC_Z per-rhombus
// heights instead (a real, easy-to-make copy-paste mistake given how directly
// this tile reuses tumbling_cubes' island-building loop).
assert(_RH_Z == 1, str("rhombille's uniform rhombus height must be 1, got ", _RH_Z));
_zs = unique([for (p = _tex[0]) p[2]]);
assert(_zs == [0, 1],
    str("rhombille's VNF must use exactly two Z levels -- ground (0) and every ",
        "rhombus at the tile's full height (1) -- got ", _zs));

// raised and etched must resolve to the exact same VNF -- rhombille's
// geometry doesn't depend on relief_mode (decorated_solid()'s tex_inset
// handles the raised/etched distinction), unlike the three kis-family
// patterns which genuinely build a different tile per mode.
_tex_etched = _decoration_texture("rhombille", "etched");
assert(_tex == _tex_etched,
    "rhombille's tile geometry must be identical for \"raised\" and \"etched\" -- only decorated_solid()'s tex_inset should differ");

// The invariant the whole tile design rests on: every vertex the tile leaves
// on one edge needs a twin at the same position on the opposite edge, or
// repeats don't stitch and the surface leaks. Rendering without an error is a
// weak proxy for this -- BOSL2 only enforces it for vertices sitting on
// *open* edges, and a near-miss (an edge resampled at a slightly different
// point, an off-by-epsilon coordinate) can still render while producing a
// subtly non-tiling mesh. So compare the two edges directly.
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex, axis, 0);
    hi = _tile_edge_profile(_tex, axis, 1);
    name = (axis == 0) ? "x" : "y";
    // More than the four tile corners: an island really has to cross the
    // seam, otherwise the pattern is boxed inside each tile and this check
    // is vacuous. rhombille reuses tumbling_cubes' own hexagon placement, so
    // the same ">4" bound that holds for tumbling_cubes' seam crossings
    // applies here too.
    assert(len(lo) > 4,
        str("rhombille tile has only ", len(lo), " vertices on its ", name,
            "=0 edge -- no rhombus spans the seam"));
    assert(len(lo) == len(hi),
        str("rhombille tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("rhombille tile ", name, " edge vertices don't line up: ", mismatched));
}

difference() {
    decorated_solid("rhombille", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
