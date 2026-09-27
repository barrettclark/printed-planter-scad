// tests/test_decoration_islamic_star.scad
//
// "islamic_star" is a custom VNF tile (the khatim tiling: an eight-point star
// with a four-point cross filling the gap), not a BOSL2 texture name, so it
// needs a real-render check: a tile whose points leave the unit square, whose
// edges don't line up across the tile boundary, or whose walls are wound
// backwards only fails when the geometry is actually evaluated.
//
// The difference() against a disjoint cube is not decoration: exporting a
// single top-level 3D object to .stl does NOT push it through CGAL (OpenSCAD
// 2021.01 writes the polyset straight out), so a self-intersecting or
// non-manifold texture would slip through. A boolean against anything forces
// the CGAL_Nef_Polyhedron conversion that actually validates the mesh.
include <../modules/decoration.scad>

assert(in_list("islamic_star", PATTERN_TYPES), "PATTERN_TYPES must contain \"islamic_star\"");

_tex = _decoration_texture("islamic_star", "raised");
assert(is_list(_tex) && len(_tex) == 2,
    "_decoration_texture(\"islamic_star\") must be a VNF ([points, faces]), not a texture name");
assert(is_vnf(_tex), "_decoration_texture(\"islamic_star\") must be a valid VNF");

_bounds = pointlist_bounds(_tex[0]);
assert(min(_bounds[0]) >= -EPSILON && max(_bounds[1]) <= 1 + EPSILON,
    str("islamic_star tile must fit in the unit cube, got bounds ", _bounds));

assert(_decoration_style("islamic_star", "raised") == undef,
    "islamic_star is a VNF tile and must not carry a style override");
assert(_decoration_style("islamic_star", "etched") == undef,
    "islamic_star is a VNF tile and must not carry a style override when etched");

// The star must dominate: it is the motif, the cross is the filler.
assert(_IS_Z_STAR == 1 && _IS_Z_CROSS > 0 && _IS_Z_CROSS < _IS_Z_STAR,
    str("islamic_star: star must stand at z=1 above the cross, got ",
        _IS_Z_STAR, " and ", _IS_Z_CROSS));

// The two shapes tile the plane exactly -- that is the whole reason this pair
// works, and it is the thing a fumbled radius would silently break (the render
// would still succeed, just with overlaps or gaps). Their areas must add up to
// the unit cell, and they must share the tips where they meet.
_star_area  = polygon_area(_is_star([0.5, 0.5]));
_cross_area = polygon_area(_is_cross([0, 0]));
assert(approx(_star_area + _cross_area, 1),
    str("khatim star + cross must tile the unit cell exactly, got ",
        _star_area, " + ", _cross_area, " = ", _star_area + _cross_area));
// The star's axis-direction tips land on the tile edge midpoints, where the
// neighbouring tile's star and two crosses meet them at 90 degrees each.
assert(approx(_IS_R, 0.5), str("islamic_star tip radius must be 0.5, got ", _IS_R));
assert(in_list([0.5, 0], [for (p = _is_star([0, 0])) [_tile_q(p[0]), _tile_q(p[1])]]),
    "islamic_star: the star's +x tip must sit exactly half a tile from its centre");
assert(in_list([0.5, 0], [for (p = _is_cross([0, 0])) [_tile_q(p[0]), _tile_q(p[1])]]),
    "islamic_star: the cross's +x tip must meet the star's tip half a tile out");

// The invariant the whole tile design rests on: every vertex the tile leaves on
// one edge needs a twin at the same position on the opposite edge, or repeats
// don't stitch and the surface leaks. BOSL2 only enforces this for vertices on
// *open* edges, and a near-miss can still render while producing a subtly
// non-tiling mesh, so compare the two edges directly.
function _tile_edge_profile(vnf, axis, at) =
    sort([for (p = vnf[0]) if (abs(p[axis] - at) < EPSILON)
             [for (i = [0:2]) if (i != axis) p[i]]]);

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex, axis, 0);
    hi = _tile_edge_profile(_tex, axis, 1);
    name = (axis == 0) ? "x" : "y";
    // More than the four tile corners: the corner crosses really have to span
    // the seam, otherwise the rosettes sit in visible boxes.
    assert(len(lo) > 4,
        str("islamic_star tile has only ", len(lo), " vertices on its ", name,
            "=0 edge -- no cross spans the seam"));
    assert(len(lo) == len(hi),
        str("islamic_star tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("islamic_star tile ", name, " edge vertices don't line up: ", mismatched));
}

// "alternating" is new: star high, all four crosses low (a visual-judgment
// call per the spec's Decisions section -- confirm this reads well once
// rendered; change high_group below if not). group_id and alt_key coincide
// for this pattern (star = 0, crosses = 1..4) since each group has exactly
// one sub-region -- the natural motif identity IS the natural alternation
// bucket, per the spec's "Per-pattern high_group choice" section.
_tex_alt = _decoration_texture("islamic_star", "alternating");
assert(is_vnf(_tex_alt), "_decoration_texture(\"islamic_star\", \"alternating\") must be a valid VNF");
_alt_zs = unique([for (p = _tex_alt[0]) p[2]]);
// All three Z levels must appear: the star (high, z=1), each cross (low,
// z=0), and the real z=0.5 ground/groove between them -- the star and
// crosses are shrunk by _IS_GAP away from each other for this builder (the
// same groove _islamic_star_alternating_islands() carries over from raised
// mode's own shrink), so the ground plane is genuinely non-empty, not
// degenerate to zero area.
assert(_alt_zs == [0, 0.5, 1],
    str("islamic_star alternating VNF must use exactly Z levels {0, 0.5, 1} (nominal wall at 0.5), got ", _alt_zs));
assert(_tex_alt != _decoration_texture("islamic_star", "raised"),
    "islamic_star alternating tile must differ from raised");
assert(_tex_alt != _decoration_texture("islamic_star", "etched"),
    "islamic_star alternating tile must differ from etched");

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex_alt, axis, 0);
    hi = _tile_edge_profile(_tex_alt, axis, 1);
    name = (axis == 0) ? "x" : "y";
    assert(len(lo) == len(hi),
        str("islamic_star alternating tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("islamic_star alternating tile ", name, " edge vertices don't line up (including Z): ", mismatched));
}

// Etched must now be a genuinely different (flat panel + groove) VNF, not
// the same bump inverted via tex_inset -- this is the whole point of the
// rework. Z levels: 1 (panel), 0 (primary/outer groove, full depth). No
// secondary tier here: every group has exactly one sub-region (star alone,
// each cross alone), so there are no same-group internal edges to groove.
_tex_etched = _decoration_texture("islamic_star", "etched");
assert(is_vnf(_tex_etched), "_decoration_texture(\"islamic_star\", \"etched\") must be a valid VNF");
assert(_tex_etched != _tex, "islamic_star etched tile must differ from raised");
_etched_zs = unique([for (p = _tex_etched[0]) p[2]]);
assert(_etched_zs == [0, 1],
    str("islamic_star etched VNF must use exactly 2 Z levels (ground/primary-groove, panel), got ", _etched_zs));

difference() {
    decorated_solid("islamic_star", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}

// Deliberately NO second/third top-level solid for "alternating"/"etched":
// OpenSCAD unions every top-level object through CGAL on .stl export, and
// islamic_star (already in the "known to abort CGAL for some
// pattern_repeat/smoothness combinations" bucket) aborts that union --
// confirmed directly: "raised" + "alternating" + "etched" together at
// r1=75/r2=60/h=100, $fn=4, pattern_repeat=12 hits the same CGAL
// "precondition violation" (Multiset.h:2308) that tumbling_cubes'/
// rhombille's own multi-solid test files hit for the same reason (see
// those files' own comments) -- not a defect in this task's etched/
// alternating code, each of which is a clean 2-volume manifold alone.
// The etched/alternating tiles stay pinned by the VNF assertions above.

