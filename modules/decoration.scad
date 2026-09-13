// modules/decoration.scad
include <../lib/BOSL2/std.scad>

// PATTERN_TYPES doubles as the Customizer's valid-value list and the lookup
// table for _decoration_texture(). Most entries are literal BOSL2 texture
// names (see the texture() catalog in lib/BOSL2/skin.scad) and map to
// themselves; the exceptions are "none" (no texture at all), "ridges" (an
// alias for BOSL2's "ribs"), and "teardrop", which is not a BOSL2 texture at
// all but a custom VNF tile built below. So _decoration_texture() returns
// either a string or a VNF, and callers must not assume a string.
PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                 "bricks", "checkers", "dots", "cubes", "tri_grid",
                 "teardrop"];

// --- Interlocking teardrop VNF tile -----------------------------------------
//
// A BOSL2 VNF texture tile is a surface whose XY footprint fills the unit
// square and whose Z runs 0..1; BOSL2 repeats it over the target surface, so
// any vertex the tile leaves on one edge must have a twin at the same position
// on the opposite edge (lib/BOSL2/skin.scad, "Subsection: VNF Textures").
//
// Layout, in unit-tile coordinates: two columns of teardrops half a period out
// of phase, so each column's points nest into the bellies of its neighbours.
//   column A -- point-UP, centred on x=0, so it straddles the tile's left and
//               right edges and is stored as two half-teardrops. Splitting on
//               the teardrop's own axis of symmetry means both halves meet the
//               edge along a straight line whose endpoints (the tip and the
//               bottom of the circle) are exact, matching vertices.
//   column B -- point-DOWN, centred on x=0.5, with its circle centre sitting
//               exactly on y=0 / y=1. Splitting there cuts the outline at the
//               circle's horizontal diameter, again an exact split: the piece
//               below y=1 is the pointed cap, the piece above y=0 is a half
//               disc, and the two chords line up vertex for vertex.
// Everything is a flat-topped extrusion of that outline standing on a flat
// z=0 border, so the tile reads the same way "dots" or "hex_grid" do.
//
// The half-period offset is what forces column B across the tile's y edges,
// and that is unavoidable: if both columns sat wholly inside the tile, the
// largest offset they could take is 1 - (drop height), so drops would have to
// shrink to half the tile height and the pattern would stop interlocking.
// The cost is that a textured cylinder ends up with scalloped rather than
// circular end caps, which OpenSCAD 2021.01 can build and difference() fine
// (the whole planter assembly renders), but which trips a CGAL assertion if
// two such solids are union()ed with each other. Keep teardrop solids one per
// render when forcing CGAL evaluation.
_TD_TIP  = sqrt(2);              // tip height of a unit-radius, 45-degree teardrop
_TD_H    = 1 + _TD_TIP;          // its total height, bottom of circle to tip
_TD_GAP  = 0.08;                 // flat border between drops, in tile fractions
_TD_SY   = (1 - _TD_GAP) / _TD_H;             // teardrop scale along y
_TD_CY   = _TD_SY + _TD_GAP / 2;              // column A's circle centre
// The columns are 0.5 apart and closest at y = _TD_CY/2, the midpoint between
// their circle centres, where symmetry makes both outlines the same width. That
// y is still on the circular part of each drop (|Y| = 0.5525 < sin(45)), so the
// half-width factor is just sqrt(1 - Y^2) = 0.8335 each, 1.667 together. Sizing
// _TD_SX from that leaves the same gap between columns as _TD_SY leaves between
// drops stacked in one column. Derived rather than hardcoded so it tracks
// _TD_GAP.
_TD_NEST = 2 * sqrt(1 - pow(_TD_CY / (2 * _TD_SY), 2));
_TD_SX   = (0.5 - _TD_GAP) / _TD_NEST;        // teardrop scale along x
// One angular step for every arc in the tile, so drop outlines are sampled
// evenly whichever piece they were split into: 135/12 = 11.25 degrees.
_TD_N    = 12;
function _td_seg(ang) = max(1, round(_TD_N * ang / 135));

function _td_arc(cx, cy, a0, a1) =
    let (n = _td_seg(abs(a1 - a0)))
    [for (i = [0:n]) let (a = a0 + (a1 - a0) * i / n)
        [cx + _TD_SX * cos(a), cy + _TD_SY * sin(a)]];

// Column A, right half (x >= 0): CCW from the bottom of the circle to the tip.
function _td_a_right() = concat(_td_arc(0, _TD_CY, -90, 45),
                                [[0, _TD_CY + _TD_SY * _TD_TIP]]);
// Column A, left half (x <= 1): CCW from the tip to the bottom of the circle.
function _td_a_left() = concat([[1, _TD_CY + _TD_SY * _TD_TIP]],
                               _td_arc(1, _TD_CY, 135, 270));
// Column B below y=1: CCW from the left end of the chord, round the point, to
// the right end.
function _td_b_upper() = concat(_td_arc(0.5, 1, 180, 225),
                                [[0.5, 1 - _TD_SY * _TD_TIP]],
                                _td_arc(0.5, 1, 315, 360));
// Column B above y=0: CCW half disc, right end of the chord to left end.
function _td_b_lower() = _td_arc(0.5, 0, 0, 180);

// The z=0 border is a single simply-connected polygon: walk the unit square
// counter-clockwise and detour clockwise around each drop where it meets an
// edge. No drop is fully interior, so there are no holes to punch.
function _td_border() = concat(
    [[0, 0]], reverse(_td_b_lower()),
    [[1, 0]], reverse(_td_a_left()),
    [[1, 1]], reverse(_td_b_upper()),
    [[0, 1]], reverse(_td_a_right()));

// Side wall standing on an open outline: quads wind so a CCW outline faces out.
function _td_wall(path) =
    let (n = len(path))
    [concat(path3d(path, 0), path3d(path, 1)),
     [for (i = [0:n-2]) [i, i+1, i+1+n, i+n]]];

// reverse=true despite vnf_from_region() documenting reverse=false as "normals
// UP": measured against the actual face winding it comes out the other way, and
// getting this backwards leaves the walls fighting the flats, which BOSL2
// rejects with "VNF has N open paths on an edge".
function _teardrop_tile() =
    let (drops = [_td_a_right(), _td_a_left(), _td_b_upper(), _td_b_lower()])
    vnf_merge_points(vnf_join(concat(
        [vnf_from_region([_td_border()], reverse = true)],
        [for (d = drops) vnf_from_region([d], transform = up(1), reverse = true)],
        [for (d = drops) _td_wall(d)])));

function _decoration_texture(pattern_type) =
    pattern_type == "ridges"   ? "ribs" :
    pattern_type == "teardrop" ? _teardrop_tile() :
    pattern_type;

// "diamonds", "pyramids", and "bricks" are Heightfield textures, whose grid
// samples get triangulated according to a `style` parameter. BOSL2's own
// default style ("min_edge") renders "pyramids" as flat-topped mini-diamonds
// instead of actual pyramids, and its docs call for style="convex" on both
// "pyramids" and "bricks", and style="concave" on "diamonds" for the
// expected pointed-bump look. Every other geometric pattern_type ("hex_grid",
// "checkers", "dots", "cubes", "tri_grid") is a VNF texture (pre-triangulated),
// for which `style` doesn't apply; "ridges" maps to the heightfield "ribs"
// texture but doesn't need a style override, "teardrop" is a custom VNF tile
// (same story -- no style), and "none" has no texture.
function _decoration_style(pattern_type) =
    pattern_type == "diamonds" ? "concave" :
    pattern_type == "pyramids" ? "convex" :
    pattern_type == "bricks"   ? "convex" :
    undef;

module decorated_solid(pattern_type, pattern_orientation, relief_mode, pattern_depth,
                        pattern_repeat, r1, r2, height, wall_thickness, fn=50) {
    assert(in_list(pattern_type, PATTERN_TYPES),
        str("pattern_type must be one of ", PATTERN_TYPES, ", got \"", pattern_type, "\""));
    if (pattern_type == "none") {
        cylinder(h = height, r1 = r1, r2 = r2, $fn = fn);
    } else {
        assert(pattern_depth < wall_thickness * 0.7,
            str("pattern_depth (", pattern_depth, ") must be < 70% of wall_thickness (", wall_thickness, ")"));
        assert(is_int(pattern_repeat) && pattern_repeat > 0,
            str("pattern_repeat must be a positive whole number, got ", pattern_repeat));
        tex = _decoration_texture(pattern_type);
        rot = (pattern_orientation == "horizontal") ? 90 : 0;
        is_etched = (relief_mode == "etched");
        // "dots" is a raised-bump VNF texture; simply insetting it (tex_inset)
        // just shifts the same bump shape below the surface rather than
        // inverting it into a dimple. BOSL2's documented recipe for a real
        // dimple is tex_inset=1 combined with a NEGATIVE tex_depth -- every
        // other texture here inverts correctly with tex_inset alone.
        depth = (pattern_type == "dots" && is_etched) ? -pattern_depth : pattern_depth;
        cyl(h = height, r1 = r1, r2 = r2, anchor = BOTTOM, $fn = fn,
            texture = tex,
            tex_reps = [pattern_repeat, pattern_repeat],
            tex_depth = depth,
            tex_inset = is_etched,
            tex_rot = rot,
            style = _decoration_style(pattern_type));
    }
}
