// modules/decoration.scad
include <../lib/BOSL2/std.scad>

// PATTERN_TYPES doubles as the Customizer's valid-value list and the lookup
// table for _decoration_texture(). Most entries are literal BOSL2 texture
// names (see the texture() catalog in lib/BOSL2/skin.scad) and map to
// themselves; the exceptions are "none" (no texture at all), "ridges" (an
// alias for BOSL2's "ribs"), and the four interlocking patterns --
// "teardrop", "tumbling_cubes", "intertwine", "islamic_star" -- which are not
// BOSL2 textures at all but custom VNF tiles built below. So
// _decoration_texture() returns
// either a string or a VNF, and callers must not assume a string. The mapping
// is also relief-mode dependent -- see _decoration_etched_texture().
PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                 "bricks", "checkers", "dots", "cubes", "tri_grid",
                 "teardrop", "tumbling_cubes", "intertwine", "islamic_star"];

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
// such a solid is union()ed with any other textured solid -- another teardrop,
// a "dots" solid, anything carrying a texture. Unioning with plain untextured
// geometry is fine. Keep a teardrop solid as the only textured solid per render
// when forcing CGAL evaluation.
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

// --- Shared plateau-tile builder --------------------------------------------
//
// The three interlocking patterns below (tumbling_cubes, intertwine,
// islamic_star) all have the same shape: flat-topped "islands" of various
// heights standing on a flat z=0 ground, separated by a narrow groove. Rather
// than hand-rolling each outline the way _teardrop_tile() does, they are
// described as 2D regions plus a height and assembled here.
//
// Every island is defined over the *infinite* tiling and then clipped to the
// unit square, so an island that straddles a tile edge stays straddling and its
// two halves meet up across the seam. That is what makes the patterns
// interlock rather than sit in visible boxes.
_UNIT_TILE = [[0,0],[1,0],[1,1],[0,1]];

// Region booleans and offset() compute intersections in floating point, so the
// piece of an island cut off at x=1 and the piece its translate leaves at x=0
// land on y values that agree to ~1e-16 but not bit-for-bit. Quantising to 1e-9
// (well under BOSL2's EPSILON, and ~1e-7 mm at planter scale) makes them
// identical, which both the twin-vertex invariant and BOSL2's own tile
// stitching depend on.
function _tile_q(v) = round(v * 1e9) / 1e9;
function _tile_quantize(vnf) =
    [[for (p = vnf[0]) [_tile_q(p[0]), _tile_q(p[1]), p[2]]], vnf[1]];

// A segment lying flat along a tile edge is shared with the neighbouring tile:
// the two tiles' islands join there, so there is no wall to build.
function _tile_on_edge(a, b) =
    (approx(a[0], 0) && approx(b[0], 0)) || (approx(a[0], 1) && approx(b[0], 1)) ||
    (approx(a[1], 0) && approx(b[1], 0)) || (approx(a[1], 1) && approx(b[1], 1));

// One vertical quad per non-shared segment, wound so a CCW path (BOSL2's
// convention for a region's outer path) faces outward and a CW path (a hole)
// faces inward.
function _tile_walls(path, z) =
    let (n = len(path))
    [for (i = [0:n-1]) let (a = path[i], b = path[(i+1) % n])
        if (!_tile_on_edge(a, b))
            [[[a[0], a[1], 0], [b[0], b[1], 0], [b[0], b[1], z], [a[0], a[1], z]],
             [[0, 1, 2, 3]]]];

// islands: list of [region, height]. reverse=true is "normals up" here for the
// same measured reason _teardrop_tile() documents.
function _tile_from_islands(islands) =
    let (
        all     = [for (il = islands) [intersection(force_region(il[0]), [_UNIT_TILE]), il[1]]],
        clipped = [for (c = all) if (len(c[0]) > 0) c],
        ground  = difference([_UNIT_TILE], union([for (c = clipped) c[0]]))
    )
    vnf_merge_points(_tile_quantize(vnf_join(concat(
        [vnf_from_region(ground, reverse = true)],
        [for (c = clipped) vnf_from_region(c[0], transform = up(c[1]), reverse = true)],
        // region_parts() is the only thing that guarantees a winding: the
        // region booleans above hand back paths in whatever direction fell
        // out of the clip, and a wall built on a backwards path faces into
        // the island instead of out of it (BOSL2 reports it as "faces
        // reverse across edge", OpenSCAD as an unclosed mesh). region_parts()
        // normalises to clockwise outers and counter-clockwise holes; reverse
        // flips that to the outward-facing convention _tile_walls() expects.
        [for (c = clipped) for (part = region_parts(c[0])) for (p = part)
            each _tile_walls(reverse(p), c[1])]))));

// --- Tumbling blocks (rhombille) --------------------------------------------
//
// The isometric stacked-cube illusion: a hexagon split into three rhombi by
// spokes to alternating vertices, each rhombus raised to a different height so
// one reads as the cube's top and two as its sides.
//
// Tiling: pointy-top hexagons of the rhombille tiling, normalised so the
// rectangular unit cell is exactly the unit square -- hexagons centred on the
// four tile corners and one in the middle. That placement is deliberate: the
// tile edges x=0/x=1 run through the corner hexagons' centres and cut exactly
// one rhombus each, along that rhombus's own short diagonal (an existing
// vertex-to-vertex line), while y=0/y=1 cut the vertical hexagon edges at
// exactly x=+-1/2. Every cut therefore lands on an exact coordinate rather than
// an interpolated one.
_TC_V = [[0, 1/3], [-1/2, 1/6], [-1/2, -1/6], [0, -1/3], [1/2, -1/6], [1/2, 1/6]];
// Heights of the three rhombi, in the order the spokes visit them: left face,
// cube top (the wide diamond), right face. Distinct values are what sells the
// isometric illusion -- equal heights just look like a honeycomb.
_TC_Z = [0.30, 1.0, 0.62];
_TC_GAP = 0.055;            // engraved line between rhombi, in tile fractions
_TC_CENTERS = [[0, 0], [1, 0], [0, 1], [1, 1], [0.5, 0.5]];

function _tc_rhombus(c, k) =
    let (i = 2 * k)
    [c, c + _TC_V[i], c + _TC_V[(i + 1) % 6], c + _TC_V[(i + 2) % 6]];

function _tumbling_cubes_tile() =
    _tile_from_islands([
        for (c = _TC_CENTERS) for (k = [0:2])
            let (r = offset(_tc_rhombus(c, k), delta = -_TC_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _TC_Z[k]]]);

// --- Interlocking rings -----------------------------------------------------
//
// Rings on a checkerboard lattice (tile centres and tile corners), sized so
// each ring overlaps its four diagonal neighbours and nothing else. Where two
// rings cross, one strand is broken with a gap so the other reads as passing
// over it -- the strapwork convention.
//
// The break rule is "each ring passes over at the clockwise-side crossing of
// every pair, under at the counter-clockwise-side one". Because swapping the
// two rings also swaps which crossing is clockwise, the rule is consistent from
// both sides, and it alternates over/under all the way round each ring, so the
// rings are genuinely linked rather than merely overlapping.
//
// Shares teardrop's union limitation: a solid decorated with this tile aborts
// CGAL when union()ed with another textured solid. Keep it the only textured
// solid per render when forcing CGAL evaluation.
_IW_RO = 0.4975;            // outer radius: < 0.5 so same-class rings never touch
_IW_RI = 0.4125;
_IW_RM = (_IW_RO + _IW_RI) / 2;
_IW_GAP = 0.028;            // break width where a strand passes under
_IW_MASK = 0.22;            // radius of the break, < half the crossing spacing
_IW_N = 48;
_IW_NEIGHBORS = [[0.5, 0.5], [-0.5, 0.5], [0.5, -0.5], [-0.5, -0.5]];

// The ring lattice is offset a quarter tile from the tile's own corners. Put a
// ring centre on the corner instead and the crossing where it dives under the
// middle ring lands exactly on the tile edge, so every island stops short of
// the seam: the pattern still tiles (the break is periodic too), but nothing
// actually spans a tile boundary, which is both fragile and untestable. At
// quarter-tile phase the seams cut through solid strand instead.
function _iw_reaches(c) =
    norm([max(0, abs(c[0] - 0.5) - 0.5), max(0, abs(c[1] - 0.5) - 0.5)]) < _IW_RO;
_IW_CENTERS = [for (i = [-1:1]) for (j = [-1:1]) for (o = [[0.25, 0.25], [0.75, 0.75]])
                  let (c = o + [i, j]) if (_iw_reaches(c)) c];

function _iw_ring(c, ro, ri) =
    difference([move(c, circle(r = ro, $fn = _IW_N))],
               [move(c, circle(r = ri, $fn = _IW_N))]);

// The crossing of the two mid-circles that lies counter-clockwise of the c->n
// direction, i.e. the one where c's strand dives under n's.
function _iw_under_at(c, n) =
    let (d = norm(n - c), u = (n - c) / d, h = sqrt(_IW_RM * _IW_RM - d * d / 4))
    (c + n) / 2 + h * [-u[1], u[0]];

function _iw_strand(c) =
    difference(concat(
        [_iw_ring(c, _IW_RO, _IW_RI)],
        [for (o = _IW_NEIGHBORS)
            intersection(_iw_ring(c + o, _IW_RO + _IW_GAP, _IW_RI - _IW_GAP),
                         [move(_iw_under_at(c, c + o), circle(r = _IW_MASK, $fn = _IW_N))])]));

// One island, not five: at a crossing the strand that passes over is *not* cut
// back, so its footprint genuinely overlaps its neighbour's. Handing the
// overlapping strands to _tile_from_islands() separately would bury one
// island's wall inside the other and leave the mesh unclosed, so union them
// into a single region first -- they all sit at the same height anyway.
function _intertwine_tile() =
    _tile_from_islands([[union([for (c = _IW_CENTERS) _iw_strand(c)]), 1.0]]);

// --- Islamic star rosette ---------------------------------------------------
//
// The khatim ("seal of the prophets") tiling: eight-point stars on a square
// lattice with a four-point cross filling each gap. The two shapes tile the
// plane exactly -- star area 0.5858 plus cross area 0.4142 is the unit cell --
// and they share whole edges, so shrinking both by half the groove width leaves
// a uniform incised line between them rather than a ragged one.
//
// The star is the {8/2} octagram (two squares at 45 degrees), tips at radius
// _IS_R and concave vertices at _IS_RIN. With _IS_R = 0.5 the tips land exactly
// on the tile edge midpoints, where they meet the neighbouring tile's star and
// two crosses at 90 degrees each.
_IS_R   = 0.5;
_IS_RIN = _IS_R / (sqrt(2) * cos(22.5));   // 0.76537 * _IS_R
_IS_RX  = _IS_R * (sqrt(2) - 1);           // cross waist, 0.20711 * _IS_R
_IS_GAP = 0.05;
_IS_Z_STAR  = 1.0;
_IS_Z_CROSS = 0.55;
_IS_CROSS_CENTERS = [[0, 0], [1, 0], [0, 1], [1, 1]];

function _is_star(c) =
    [for (i = [0:15]) let (a = 22.5 * i, r = (i % 2 == 0) ? _IS_R : _IS_RIN)
        c + r * [cos(a), sin(a)]];

function _is_cross(c) =
    [for (i = [0:15])
        let (a = 22.5 * i,
             r = (i % 4 == 0) ? _IS_R : (i % 4 == 2) ? _IS_RX : _IS_RIN)
        c + r * [cos(a), sin(a)]];

function _islamic_star_tile() =
    _tile_from_islands(concat(
        [[[offset(_is_star([0.5, 0.5]), delta = -_IS_GAP / 2, closed = true)], _IS_Z_STAR]],
        [for (c = _IS_CROSS_CENTERS)
            [[offset(_is_cross(c), delta = -_IS_GAP / 2, closed = true)], _IS_Z_CROSS]]));

// Half-width of an etched V-groove, as a fraction of one texture tile. Each
// tile contributes this much slope on each side of a shared edge, so the
// finished groove is twice this wide and the flat land is the remaining
// 1 - 2*_ETCH_BORDER of the tile. Kept small on purpose: the point of etched
// mode is a thin incised line, not a chamfered plateau.
_ETCH_BORDER = 0.05;

// Patterns with a flat-top/V-groove counterpart texture in BOSL2, used when
// relief_mode == "etched" so etched reads as engraved lines cut into a flat
// surface rather than a smoothly inverted bump. Insetting one of these (see
// decorated_solid) puts the flat tops at the nominal wall radius and sinks
// only the grooves, which is the laser-engraved look.
//
// The "_vnf" variants rather than the plain "trunc_ribs"/"trunc_pyramids"
// heightfields: those two have a fixed profile with no groove-width parameter
// (trunc_ribs is a hardcoded quarter land to three-quarters flat-bottomed
// channel, trunc_pyramids about a third land to two-thirds slope), which reads
// as fluting and as a heavy chamfer respectively rather than as an incised
// line. The VNF variants take `border=`/`gap=` and can be cut as narrow as we
// like. gap=0 makes the ribs' groove a true V with no flat floor, matching the
// pyramids and diamonds grooves. These return VNFs, so -- like "hex_grid",
// "dots" and "teardrop" -- they take no `style`.
function _decoration_etched_texture(pattern_type) =
    pattern_type == "ridges"   ? texture("trunc_ribs_vnf", gap = 0, border = _ETCH_BORDER) :
    pattern_type == "pyramids" ? texture("trunc_pyramids_vnf", border = _ETCH_BORDER) :
    pattern_type == "diamonds" ? "trunc_diamonds" :
    undef; // no counterpart -- falls back to insetting the raised bump

function _decoration_texture(pattern_type, relief_mode) =
    let (etched_tex = (relief_mode == "etched")
                          ? _decoration_etched_texture(pattern_type) : undef)
    is_def(etched_tex)         ? etched_tex :
    pattern_type == "ridges"         ? "ribs" :
    pattern_type == "teardrop"       ? _teardrop_tile() :
    pattern_type == "tumbling_cubes" ? _tumbling_cubes_tile() :
    pattern_type == "intertwine"     ? _intertwine_tile() :
    pattern_type == "islamic_star"   ? _islamic_star_tile() :
    pattern_type;

// Heightfield textures have their grid samples triangulated according to a
// `style`; VNF textures come pre-triangulated and ignore it. BOSL2's default
// style ("min_edge") renders "pyramids" as flat-topped mini-diamonds instead
// of actual pyramids, and its docs call for style="convex" on "pyramids" and
// "bricks", and style="concave" on "diamonds". "ribs" is a heightfield whose
// docs say the style does not matter, and everything else here -- including
// all three etched counterparts -- is a VNF.
//
// Keyed on the resolved texture rather than on pattern_type so the etched
// variants can't drift out of sync: all three of them are VNFs, so every
// pattern's etched style falls through to undef without needing a second
// relief-mode-specific table to keep in step with the texture table.
//
// Split in two so decorated_solid() can resolve the texture once and style it
// from the result: with four custom VNF tiles now, having _decoration_style()
// rebuild the tile just to compare it against string literals would double the
// tile-construction cost of every render.
function _decoration_style_for(tex) =
    tex == "diamonds" ? "concave" :
    tex == "pyramids" ? "convex" :
    tex == "bricks"   ? "convex" :
    undef;

function _decoration_style(pattern_type, relief_mode) =
    _decoration_style_for(_decoration_texture(pattern_type, relief_mode));

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
        // These three tile large flat plateaus, whose single flat facet can cut
        // back inside the wall and abort the cavity subtraction in CGAL. Which
        // values trip it depends on pattern_repeat and smoothness jointly (see
        // README). OpenSCAD still exits 0 and still writes an STL when it
        // happens, so warn up front rather than let a silently-truncated export
        // look successful.
        if (in_list(pattern_type, ["tumbling_cubes", "intertwine", "islamic_star"]))
            echo(str("WARNING: pattern_type \"", pattern_type, "\" is known to abort CGAL ",
                     "for some pattern_repeat/smoothness combinations, and OpenSCAD still ",
                     "exits 0 and writes a truncated STL when it does. Scan this console for ",
                     "a CGAL assertion before trusting the export; if you see one, nudge ",
                     "pattern_repeat or smoothness. See README.md."));
        tex = _decoration_texture(pattern_type, relief_mode);
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
            // BOSL2 normalises tex_inset=true to exactly 1 (skin.scad:5203),
            // so this is full inset: the texture's high points land on the
            // nominal wall and everything else is cut in.
            tex_inset = is_etched,
            tex_rot = rot,
            style = _decoration_style_for(tex));
    }
}
