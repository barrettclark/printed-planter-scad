// modules/decoration.scad
include <../lib/BOSL2/std.scad>

// PATTERN_TYPES doubles as the Customizer's valid-value list and the lookup
// table for _decoration_texture(). Most entries are literal BOSL2 texture
// names (see the texture() catalog in lib/BOSL2/skin.scad) and map to
// themselves; the exceptions are "none" (no texture at all), "ridges" (an
// alias for BOSL2's "ribs"), and the eleven custom VNF tiles built below --
// the eight interlocking patterns ("teardrop", "tumbling_cubes",
// "intertwine", "islamic_star", "rhombille", "cairo_pentagonal",
// "floret_pentagonal", "deltoidal_trihexagonal" -- rhombille is the plain
// rhombille tiling tumbling_cubes' own isometric illusion is built from,
// cairo_pentagonal is the Cairo pentagonal tiling, floret_pentagonal is the
// floret pentagonal tiling, and deltoidal_trihexagonal is the deltoidal
// trihexagonal tiling (kite motif); all genuinely cross the tile boundary
// like the other seven) and the three "kis" family patterns
// ("tetrakis_square", "kisrhombille", "triakis_triangular") -- which are not
// BOSL2 textures at all. "floret_pentagonal" straddles those two groups: it
// interlocks across the seam like the first group, but its 6-pentagon
// rosette is a fan with real sub-structure, so like the "kis" family (and
// unlike every other interlocking pattern here, including
// "deltoidal_trihexagonal") its tile geometry depends on relief_mode. So
// _decoration_texture() returns
// either a string or a VNF, and callers must not assume a string. The mapping
// is also relief-mode dependent -- see _decoration_etched_texture().
PATTERN_TYPES = ["none", "ridges", "diamonds", "hex_grid", "pyramids",
                 "bricks", "checkers", "dots", "cubes", "tri_grid",
                 "teardrop", "tumbling_cubes", "intertwine", "islamic_star",
                 "tetrakis_square", "kisrhombille", "triakis_triangular",
                 "rhombille", "cairo_pentagonal", "floret_pentagonal",
                 "deltoidal_trihexagonal"];

// RELIEF_MODES is a SEPARATE list from PATTERN_TYPES on purpose:
// PATTERN_TYPES lists pattern NAMES (what _decoration_texture() looks up),
// and "alternating" is not a pattern name -- adding it to PATTERN_TYPES
// would make pattern_type="alternating" look like a valid Customizer
// selection and fall through to an unresolved texture.
RELIEF_MODES = ["raised", "etched", "alternating"];

// The 8 Phase-1 patterns whose islands-building loop tags group_id/alt_key
// and can feed _tile_alternating_from_islands(). teardrop and intertwine are
// both excluded (different reasons -- see this plan's Global Constraints);
// deltoidal_trihexagonal has no relief_mode split at all; the four BOSL2-
// native heightfield patterns (dots/cubes/checkers/bricks) and the five
// flat-top/V-groove patterns (ridges/pyramids/diamonds/hex_grid/tri_grid)
// are Phase 2 or out of scope.
ALTERNATING_PATTERNS = ["tumbling_cubes", "islamic_star", "tetrakis_square",
                        "kisrhombille", "triakis_triangular", "rhombille",
                        "cairo_pentagonal", "floret_pentagonal"];

// Excluded from the square-tile correction: "none" has no texture at all;
// "ridges" is a directional stripe pattern with no discrete shape to square;
// "bricks" is intentionally rectangular, like real bricks.
_ASPECT_EXCLUDED_PATTERNS = ["none", "ridges", "bricks"];

// BOSL2's own documentation (lib/BOSL2/skin.scad texture catalog comments)
// says these three need an additional sqrt(3) Y-scale for correct aspect:
// "cubes" for a true isometric-cube look, "hex_grid"/"tri_grid" so their
// V-groove border width is uniform on every side of the hexagon/triangle
// (regular hexagons/triangles, not stretched ones).
_ASPECT_SQRT3_PATTERNS = ["cubes", "hex_grid", "tri_grid"];

// decorated_solid() used to pass the same pattern_repeat for both the horizontal
// (circumferential) and vertical tex_reps, which only produces square tiles
// by coincidence: the wall's average circumference (~440mm at defaults) is
// nothing like its height (~138mm). This derives the vertical repeat count
// from the real geometry instead, so tiles come out approximately square
// (only approximately, since the wall is a cone: BOSL2 scales each texture
// strip to the LOCAL radius, so a single vertical_reps can only be exact at
// one radius -- see README.md's "Decoration" section for the residual
// taper effect this leaves).
//
// The custom VNF tiles (teardrop, tumbling_cubes, intertwine, islamic_star,
// tetrakis_square, kisrhombille, triakis_triangular, rhombille,
// cairo_pentagonal, floret_pentagonal, deltoidal_trihexagonal) are built on
// _UNIT_TILE, confirmed
// elsewhere in this file to be exactly the unit square with no intrinsic
// distortion, so they use the plain formula like every BOSL2 catalog texture
// without a documented sqrt(3) requirement.
function _square_tile_vertical_reps(pattern_type, pattern_orientation, pattern_repeat, r1, r2, height) =
    in_list(pattern_type, _ASPECT_EXCLUDED_PATTERNS) ? pattern_repeat :
    let(
        avg_circumference = PI * (r1 + r2),
        is_sqrt3 = in_list(pattern_type, _ASPECT_SQRT3_PATTERNS),
        // BOSL2 rotates the TILE'S OWN CONTENT by 90 degrees for tex_rot=90
        // (this project's "horizontal" pattern_orientation) -- see
        // lib/BOSL2/skin.scad's _get_texture(), which applies zrot(90,...)
        // for VNF textures (cubes/hex_grid/tri_grid all return VNF data) or
        // an equivalent transpose for heightfields. tex_reps' own axes stay
        // tied to the SURFACE (circumferential, vertical) regardless of
        // tex_rot -- BOSL2 does not swap tex_reps' meaning. So a texture
        // whose intrinsic Y needs to be sqrt(3) times its intrinsic X has
        // that requirement land on the surface's vertical axis normally,
        // but on the surface's circumferential axis once rotated -- and
        // since tex_reps[0] (circumferential) stays pinned to the
        // user-facing pattern_repeat either way, the correction flips from
        // dividing vertical_reps by sqrt(3) to multiplying it.
        aspect_correction = !is_sqrt3 ? 1
            : (pattern_orientation == "horizontal") ? (1 / sqrt(3)) : sqrt(3)
    )
    max(1, round(pattern_repeat * height / (avg_circumference * aspect_correction)));

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
// The patterns below (tumbling_cubes, rhombille, cairo_pentagonal,
// floret_pentagonal, intertwine, islamic_star, deltoidal_trihexagonal,
// and the "kis" family: tetrakis_square, kisrhombille,
// triakis_triangular) all have the same shape: flat-topped "islands" of
// various heights standing on a flat z=0 ground, separated by a narrow
// groove. Rather than hand-rolling each outline the way _teardrop_tile()
// does, they are described as 2D regions plus a height and assembled here.
//
// Every island is defined over the *infinite* tiling and then clipped to the
// unit square, so an island that straddles a tile edge stays straddling and
// its two halves meet up across the seam. That is what makes tumbling_cubes/
// rhombille/cairo_pentagonal/floret_pentagonal/intertwine/islamic_star's
// motifs interlock
// rather than sit in visible boxes -- see README.md for the definition this
// project uses for "interlocking". The "kis" family does NOT rely on this:
// _kis_shrunk_fan() shrinks every fan triangle away from all its own edges,
// including ones that land on the tile boundary, so its islands never
// straddle the seam at all; its own continuity across tiles comes from the
// fan pattern repeating identically, not from a literal split island.
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
// faces inward. ground_z defaults to 0 (every existing raised-mode caller's
// own implicit floor); the alternating builder's "low" islands (z=0) sit
// BELOW a ground_z=0.5 nominal wall, so they are pits, not bumps, and the
// material is on the opposite side of the wall. Substituting ground_z for
// the old literal 0s is not enough: the quad's normal, (p1-p0) x (p2-p1),
// stays to the RIGHT of the path direction either way, which faces out of a
// bump but INTO the solid for a pit. The z < ground_z branch therefore
// traverses the segment backwards (b then a) as well, putting the normal on
// the left, i.e. into the pit. Measured: without the swap BOSL2 rejects the
// tile with "VNF has 5 open paths on an edge".
function _tile_walls(path, z, ground_z = 0) =
    let (n = len(path))
    [for (i = [0:n-1]) let (a = path[i], b = path[(i+1) % n])
        if (!_tile_on_edge(a, b))
            (z >= ground_z)
                ? [[[a[0], a[1], ground_z], [b[0], b[1], ground_z], [b[0], b[1], z], [a[0], a[1], z]],
                   [[0, 1, 2, 3]]]
                : [[[b[0], b[1], z], [a[0], a[1], z], [a[0], a[1], ground_z], [b[0], b[1], ground_z]],
                   [[0, 1, 2, 3]]]];

// islands: list of [region, height]. reverse=true is "normals up" here for the
// same measured reason _teardrop_tile() documents. ground_z (default 0) is
// the Z of the background/ground plane AND every wall's lower edge -- see
// _tile_walls()'s own comment for why this needed a real conditional, not
// just a parameter rename, once alternating mode introduced islands below
// their own ground plane.
function _tile_from_islands(islands, ground_z = 0) =
    let (
        all     = [for (il = islands) [intersection(force_region(il[0]), [_UNIT_TILE]), il[1]]],
        clipped = [for (c = all) if (len(c[0]) > 0) c],
        ground  = difference([_UNIT_TILE], union([for (c = clipped) c[0]]))
    )
    vnf_merge_points(_tile_quantize(vnf_join(concat(
        [vnf_from_region(ground, transform = up(ground_z), reverse = true)],
        [for (c = clipped) vnf_from_region(c[0], transform = up(c[1]), reverse = true)],
        // region_parts() is the only thing that guarantees a winding: the
        // region booleans above hand back paths in whatever direction fell
        // out of the clip, and a wall built on a backwards path faces into
        // the island instead of out of it (BOSL2 reports it as "faces
        // reverse across edge", OpenSCAD as an unclosed mesh). region_parts()
        // normalises to clockwise outers and counter-clockwise holes; reverse
        // flips that to the outward-facing convention _tile_walls() expects.
        [for (c = clipped) for (part = region_parts(c[0])) for (p = part)
            each _tile_walls(reverse(p), c[1], ground_z)]))));

// --- Shared outline-etch tile builder (two-tier groove via edge classification) ---
//
// The "etched" mode redesign (docs/superpowers/specs/2026-09-20-relief-mode-
// redesign-design.md) needs a true outline engrave: a flat panel at z=1, cut
// by a PRIMARY groove (full depth, z=0) where two DIFFERENT motifs meet, and
// a thinner/shallower SECONDARY groove (z=_OUTLINE_INNER_Z) where two
// sub-regions of the SAME motif meet (a fan's own internal facet seams).
// This is NOT "union each motif's sub-regions and trace the result" -- most
// of this project's motifs tile the plane with ZERO gap between one motif
// instance and its neighbour (verified: cairo_pentagonal's 8 placements,
// floret_pentagonal's 18, islamic_star's star+4 crosses, tumbling_cubes'/
// rhombille's hexagon rosettes all sum to EXACTLY the unit tile's own area
// before any gap-shrink), so unioning a group's own sub-regions finds that
// group's silhouette in isolation, but its boundary against a NEIGHBOURING
// motif instance is a real shared edge, not the union's own outer boundary.
// Unioning ALL groups together just returns the whole unit tile (no gap
// anywhere), whose only boundary is the tile edge itself -- already
// suppressed by _tile_on_edge() -- producing NO primary groove at all for
// almost every pattern. The correct model is edge classification over the
// full planar arrangement of every pre-shrink sub-region, tagged by which
// motif instance (group) it belongs to.

function _tile_q2(v) = [_tile_q(v[0]), _tile_q(v[1])];

// Builds a deduplicated list of physical placement positions from a base
// lattice-point list, replicated across a 3x3 block of neighbouring unit
// tiles. Every per-pattern motif_groups builder below uses this: feeding
// _tile_outline_from_islands() only the placements that overlap THIS unit
// tile leaves some of a motif's own edges without their true neighbour (see
// this plan's own "Why a 3x3 supertile" research note) -- that neighbour's
// sub-region may belong to a placement the tile-covering list never needed.
// Positions are quantized before dedup so periodic-image duplicates collapse
// exactly (e.g. tumbling_cubes' corner hexagon at (0,0), reached both
// directly and via a (1,0)-placement shifted by dx=-1, must collapse to one
// physical hexagon, not two).
function _outline_supertile_points(base_points) =
    unique([for (dx = [-1, 0, 1]) for (dy = [-1, 0, 1]) for (p = base_points)
        [_tile_q(p[0] + dx), _tile_q(p[1] + dy)]]);

// Canonical (order-independent) key for an edge between two points, so the
// same physical edge traversed from either sub-region's own winding order
// (which, for two tiling neighbours, run in OPPOSITE directions along their
// shared edge) hashes identically. Returned FLAT ([x1,y1,x2,y2], not
// [[x1,y1],[x2,y2]]) purely for speed: _outline_match_runs() sorts and then
// repeatedly compares these keys, and OpenSCAD compares a flat 4-vector
// markedly faster than a nested one -- measured 4.0s -> 3.0s over
// kisrhombille's 900 edges, for byte-identical output. Both orderings are
// lexicographic, so the canonical choice below is unaffected.
function _outline_edge_key(a, b) =
    let (qa = _tile_q2(a), qb = _tile_q2(b))
    (qa[0] < qb[0] || (qa[0] == qb[0] && qa[1] < qb[1]))
        ? [qa[0], qa[1], qb[0], qb[1]] : [qb[0], qb[1], qa[0], qa[1]];

// motif_groups: a list of groups, each group a list of ORIGINAL (pre-shrink)
// polygon paths belonging to one physical motif instance -- group_id is the
// group's own index into this list. Flattens to one entry per (group, edge):
// [key, group_id, a, b].
function _outline_all_edges(motif_groups) =
    [for (gi = [0:len(motif_groups)-1])
        for (poly = motif_groups[gi])
            for (i = [0:len(poly)-1])
                let (a = poly[i], b = poly[(i+1) % len(poly)])
                [_outline_edge_key(a, b), gi, a, b]];

// An edge whose bounding box doesn't overlap the unit tile at all can't
// contribute anything to this tile's own clipped output, however it
// classifies -- its true match (if any) lies further out than the 3x3
// supertile reached, but since neither it nor its match ever touches
// [0,1]^2, skipping it changes nothing about the final geometry.
function _outline_edge_relevant(a, b) =
    let (lo = [min(a[0], b[0]), min(a[1], b[1])], hi = [max(a[0], b[0]), max(a[1], b[1])])
    lo[0] < 1 + EPSILON && hi[0] > -EPSILON && lo[1] < 1 + EPSILON && hi[1] > -EPSILON;

// A thin quad strip along one edge, extended by width/2 past each endpoint
// so consecutive strips sharing a vertex overlap and leave no uncovered
// wedge at the corner -- offset()'s own closed-path miter handling does this
// implicitly for the old uniform per-island shrink; a per-edge strip has to
// do it explicitly.
function _outline_edge_strip(a, b, width) =
    let (d = b - a, dlen = norm(d))
    let (u = d / dlen, nrm = [-u[1], u[0]], ext = width / 2)
    [a - u * ext + nrm * width / 2, b + u * ext + nrm * width / 2,
     b + u * ext - nrm * width / 2, a - u * ext - nrm * width / 2];

// A strip whose bounding box misses the unit tile entirely cannot survive
// _tile_from_islands()'s own final clip, so unioning it is pure waste -- and
// on a 3x3 supertile roughly eight ninths of every strip list is exactly
// that. It is not a small waste either: union()'s cost grows with the
// ACCUMULATING region's complexity, so the discarded strips inflate the
// price of every later union in the fold as well as their own. Measured on
// kisrhombille (900 edges, 129 primary + 300 secondary strips): dropping
// them takes the whole tile build from 164s to 14s, for a byte-for-byte
// equal vertex set and an identical per-tier face area (only the
// triangulation order changes). Tested on the STRIP's own bounding box
// rather than the source edge's, so the width/2 end extension and
// half-width offset _outline_edge_strip() adds are already accounted for
// and no separate margin has to be guessed.
function _outline_strip_relevant(strip) =
    let (b = pointlist_bounds(strip))
    b[0][0] < 1 + EPSILON && b[1][0] > -EPSILON &&
    b[0][1] < 1 + EPSILON && b[1][1] > -EPSILON;

// Sort-based O(n log n) matching -- see this plan's "Why sort-based
// matching" research note: a naive double loop over ~900 edges (kisrhombille
// at 3x3-supertile scale) did not finish in 180 seconds; this does the
// identical classification in about 3 seconds. Pairs each edge's canonical
// key with its own index, sorts (sort() orders vectors lexicographically),
// then scans for runs of adjacent equal keys. `window`
// bounds each run's lookahead so a single start's work is O(1): a legitimate
// edge in this project's tilings matches at most once (run length 2); a run
// longer than the window is already the "non-manifold" error case below, so
// there's nothing correct to find past it.
function _outline_match_runs(edges) =
    let (
        n = len(edges),
        srt = sort([for (i = [0:n-1]) [edges[i][0], i]]),
        window = 6
    )
    [for (start = [0:n-1])
        if (start == 0 || srt[start][0] != srt[start-1][0])
            let (cap = min(start + window, n))
            [srt[start][0], [for (j = [start:cap-1]) if (srt[j][0] == srt[start][0]) srt[j][1]]]];

_OUTLINE_INNER_Z = 0.5; // secondary (internal-facet) groove floor -- shallower
                        // than the primary groove's full z=0 depth, so the two
                        // tiers read as a clear hierarchy (motif outline
                        // first, internal detail second) rather than a wash
                        // of equally-weighted lines. Shared across every
                        // pattern that uses this builder (like _ETCH_BORDER),
                        // not a per-pattern constant.

// BOSL2's region union() sequentially folds one region into the next, so its
// cost grows with the ACCUMULATING region's own complexity, not just the raw
// piece count -- confirmed a real bottleneck for kisrhombille's own strip
// counts in this plan's own research (see this plan's "Why a 3x3
// supertile..." section, finding 3). Unions small batches first, then
// recurses on the much shorter list of batch results, so any single
// union() call's own input stays small. Used unconditionally below (not
// gated per-pattern) since its own base case (len(regions) <= batch_size)
// is just a plain union(regions) call -- there is no cost to using this in
// place of a bare union() for the smaller-motif-count patterns, where it
// degenerates to the same thing.
function _outline_batched_union(regions, batch_size = 8) =
    len(regions) == 0 ? [] :
    len(regions) == 1 ? regions[0] :
    len(regions) <= batch_size ? union(regions) :
    let (
        n = len(regions),
        batches = [for (i = [0:batch_size:n-1])
            union([for (j = [i:min(i + batch_size, n) - 1]) regions[j]])]
    )
    _outline_batched_union(batches, batch_size);

function _tile_outline_from_islands(motif_groups, outer_gap, inner_gap, union_batch_size = 8) =
    let (
        edges = _outline_all_edges(motif_groups),
        runs  = _outline_match_runs(edges),
        bad = [for (r = runs) if (len(r[1]) == 1
                    && !_tile_on_edge(edges[r[1][0]][2], edges[r[1][0]][3])
                    && _outline_edge_relevant(edges[r[1][0]][2], edges[r[1][0]][3])) r],
        overfull = [for (r = runs) if (len(r[1]) > 2) r]
    )
    assert(len(bad) == 0,
        str("_tile_outline_from_islands(): ", len(bad), " sub-region edge(s) are neither ",
            "shared with another sub-region nor on the tile boundary -- motif_groups is ",
            "missing a neighbour (build it over a wider supertile, see ",
            "_outline_supertile_points()) or the pre-shrink geometry has a real gap. ",
            "First: ", edges[bad[0][1][0]][2], " -> ", edges[bad[0][1][0]][3]))
    assert(len(overfull) == 0,
        str("_tile_outline_from_islands(): edge shared by more than 2 sub-regions -- ",
            "motif_groups likely contains overlapping (not edge-to-edge) regions, which this ",
            "builder cannot classify. First: ", edges[overfull[0][1][0]][2], " -> ",
            edges[overfull[0][1][0]][3]))
    let (
        pairs = [for (r = runs) if (len(r[1]) == 2) r],
        primary_regions = [for (r = pairs) if (edges[r[1][0]][1] != edges[r[1][1]][1])
            let (s = _outline_edge_strip(edges[r[1][0]][2], edges[r[1][0]][3], outer_gap))
            if (_outline_strip_relevant(s)) [s]],
        secondary_regions = [for (r = pairs) if (edges[r[1][0]][1] == edges[r[1][1]][1])
            let (s = _outline_edge_strip(edges[r[1][0]][2], edges[r[1][0]][3], inner_gap))
            if (_outline_strip_relevant(s)) [s]],
        primary_region   = len(primary_regions) == 0 ? [] : _outline_batched_union(primary_regions, union_batch_size),
        secondary_union  = len(secondary_regions) == 0 ? [] : _outline_batched_union(secondary_regions, union_batch_size),
        // Primary wins any overlap at a vertex shared by both an outer and
        // an inner edge (a motif's own corner where its outer silhouette
        // meets one of its internal seams).
        secondary_region = (len(secondary_union) == 0) ? [] :
            (len(primary_region) == 0 ? secondary_union
                                       : difference(secondary_union, primary_region)),
        groove_all = concat(len(primary_region) == 0 ? [] : [primary_region],
                             len(secondary_union) == 0 ? [] : [secondary_union]),
        // A pattern whose single motif spans the WHOLE unit tile (e.g.
        // tetrakis_square) has no motif-to-motif boundary at all within one
        // tile -- only its own internal fan seams -- so groove_all can be
        // secondary-only, and there is legitimately no z=0 primary tier
        // anywhere. That is correct, not a bug: don't assert primary_region
        // is non-empty here.
        panel_region = len(groove_all) == 0 ? [_UNIT_TILE]
                                             : difference([_UNIT_TILE], union(groove_all))
    )
    _tile_from_islands(concat(
        [[panel_region, 1]],
        len(secondary_region) == 0 ? [] : [[secondary_region, _OUTLINE_INNER_Z]]));

// --- Shared alternating tile builder (bas-relief: real z=0.5 nominal wall) ---
//
// islands: [[region, height, group_id, alt_key], ...] -- height and
// group_id are UNUSED by this builder (height is ignored in favour of the
// high_group/alt_key decision below; group_id exists only for the outline
// builder's own consumption -- see this plan's Global Constraints). Every
// island renders at z=1 (high, proud of the wall) if its alt_key is in
// high_group, else z=0 (low, genuinely sunk below the z=0.5 ground -- a real
// facet, not flattened onto the ground plane). ground_z=0.5 is the nominal
// wall surface (paired with decorated_solid()'s tex_inset=0.5 for this
// mode) -- NOT _tile_from_islands()'s own default z=0 floor, which has no
// relationship to the nominal wall at all and would sink the entire
// background along with every low island instead of holding it at the
// neutral surface bas-relief needs.
function _tile_alternating_from_islands(islands, high_group, ground_z = 0.5) =
    _tile_from_islands(
        [for (il = islands) [il[0], in_list(il[3], high_group) ? 1 : 0]],
        ground_z);

// --- Shared kis-operation geometry -------------------------------------------
//
// Conway's "kis" operation: fan a convex polygon into one triangle per
// edge, from its centroid, each triangle independently shrunk inward by
// gap/2 (matching tumbling_cubes' own per-facet offset() idiom) so a
// narrow engraved groove separates every fan triangle from its neighbours
// -- including at the tile's own boundary, where the shrink is what lets
// the groove continue seamlessly into the next tile's matching shrink.
// heights: a single value (every triangle in this fan the same height) or
// one value per edge/triangle, in the same edge order as `poly`.
//
// Returns an "islands" list ([region, height] pairs) directly consumable
// by _tile_from_islands() -- callers concat/flatten multiple calls together
// for tilings with more than one cell per unit tile (see kisrhombille).
function _kis_centroid(poly) =
    [for (i = [0:1]) sum([for (p = poly) p[i]]) / len(poly)];

function _kis_shrunk_fan(poly, gap, heights) =
    let (c = _kis_centroid(poly), n = len(poly))
    [for (i = [0:n-1])
        let (tri = [c, poly[i], poly[(i+1) % n]],
             r = offset(tri, delta = -gap/2, closed = true))
        if (len(r) >= 3) [[r], is_list(heights) ? heights[i] : heights]];

// Un-shrunk counterpart to _kis_shrunk_fan(): the fan's ORIGINAL triangles
// (no offset() shrink), needed by the outline builder's edge classifier,
// which must see two neighbouring fans' triangles still sharing an exact
// edge to find the true internal-vs-external classification (Correction 1
// in the spec -- the already-gapped islands list is unusable for this).
function _kis_raw_fan(poly) =
    let (c = _kis_centroid(poly), n = len(poly))
    [for (i = [0:n-1]) [c, poly[i], poly[(i+1) % n]]];

_KIS_GAP = 0.05; // engraved groove width, in tile fractions -- same scale as _TC_GAP/_IS_GAP

// --- Tetrakis square (kis of the square tiling) -----------------------------
//
// Wikipedia: "a square tiling with each square divided into four isosceles
// right triangles from the center point." The whole unit tile IS the one
// square cell here -- kis-fan it directly, no separate base-tiling geometry
// needed (unlike kisrhombille/triakis_triangular below, which kis multiple
// cells per unit tile).
//
// Raised heights alternate around the fan for a pinwheel look (0 and 2 are
// opposite triangles, as are 1 and 3, so this alternates rather than mirrors).
// Etched is one flat height -- see the relief_mode note in this plan's
// Architecture section for why these two modes are genuinely different VNFs
// for this pattern, not one shape read two ways via tex_inset.
function _tetrakis_square_tile(relief_mode) =
    _tile_from_islands(_kis_shrunk_fan(_UNIT_TILE, _KIS_GAP,
        relief_mode == "etched" ? 1.0 : [1.0, 0.45, 1.0, 0.45]));

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

// --- Rhombille (the tiling tumbling_cubes' illusion is built from) ----------
//
// Wikipedia: "a tiling of the plane by rhombi... also known as ... the
// tumbling blocks pattern." tumbling_cubes raises the three rhombi per
// hexagon to three DIFFERENT heights to sell an isometric-cube illusion;
// this pattern is the plain tiling underneath that illusion -- the same
// _TC_CENTERS/_tc_rhombus() hexagon geometry, but every rhombus at the SAME
// height, so it reads as a clean rhombus-grid relief/etch rather than a set
// of cubes. Because the geometry doesn't change between raised and etched,
// this tile (like tumbling_cubes/intertwine/islamic_star) takes no
// relief_mode parameter -- decorated_solid()'s tex_inset handles that.
_RH_Z   = 1.0;   // every rhombus reaches the tile's full height
_RH_GAP = 0.055; // engraved line between rhombi, in tile fractions -- own
                 // constant rather than reusing _TC_GAP, matching how the
                 // kis family owns _KIS_GAP distinct from _TC_GAP

function _rhombille_tile() =
    _tile_from_islands([
        for (c = _TC_CENTERS) for (k = [0:2])
            let (r = offset(_tc_rhombus(c, k), delta = -_RH_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _RH_Z]]);

// --- Cairo pentagonal (dual of the snub square tiling) ----------------------
//
// Wikipedia "V3^2.4.3.4": a tessellation by congruent, irregular,
// bilaterally-symmetric convex pentagons -- four long edges and one short
// edge, two non-adjacent right angles. Every pentagon sits at the same
// height here (like rhombille), since -- unlike the "kis" family -- a single
// Cairo pentagon has no natural sub-fan to vary height across; see this
// pattern's plan document (docs/superpowers/plans/2026-09-19-cairo-pentagonal-pattern.md)
// for the full derivation and the computational area/closure verification
// this construction is based on (Python/shapely area-and-overlap checks on a
// 13x13-cell patch, plus a live OpenSCAD/BOSL2 smoke test of this exact code
// path) -- do not re-derive the lattice by hand; it was verified, not guessed.
//
// Starting pentagon (Wikipedia's own "type 4" worked example), rotated 90
// degrees about its own right-angle vertex (3,3) three times to close a
// 4-pentagon pinwheel (the tiling's translational fundamental domain), then
// mapped into unit-tile space by u=(x+y)/12, v=(x-y)/12 -- a pure rotation
// plus uniform scale (verified to send this pinwheel's translation lattice
// vectors (6,6) and (6,-6) exactly onto (1,0) and (0,1)). The 4 resulting
// pentagons below are already in that normalized (u,v) space; each has area
// exactly 1/4 and is wound CW (the normalizing transform reverses the
// original CCW winding -- verified harmless to BOSL2's offset()).
_CP_P0 = [[-1/6,-1/6], [1/6,1/6], [1/2,0], [1/3,-1/3], [0,-1/2]];
_CP_P1 = [[1/3,2/3],   [2/3,1/3], [1/2,0], [1/6,1/6],   [0,1/2]];
_CP_P2 = [[7/6,1/6],   [5/6,-1/6],[1/2,0], [2/3,1/3],   [1,1/2]];
_CP_P3 = [[2/3,-2/3],  [1/3,-1/3],[1/2,0], [5/6,-1/6],  [1,-1/2]];
_CP_PENTS = [_CP_P0, _CP_P1, _CP_P2, _CP_P3];

// Which (lattice-step, pentagon-orientation) copies have any overlap with the
// unit square -- exhaustively searched over lattice steps -2..2 in each
// direction; exactly these 8 do (their clipped areas sum to exactly 1.0, and
// their union was verified to equal the unit square exactly, with zero
// overlap among them). Each entry is [m, n, k]: pentagon _CP_PENTS[k]
// translated by (m, n) in unit-tile lattice steps.
_CP_PLACEMENTS = [[-1,0,2], [0,0,0], [0,0,1], [0,0,2],
                  [0,1,0], [0,1,2], [0,1,3], [1,1,0]];

function _cp_pentagon(m, n, k) = [for (p = _CP_PENTS[k]) [p[0] + m, p[1] + n]];

_CP_GAP = 0.05; // engraved groove width, in tile fractions -- own constant,
                // same scale as _KIS_GAP/_RH_GAP but never shared with them
_CP_Z   = 1.0;  // every pentagon reaches the tile's full height (uniform,
                // like rhombille -- see this pattern's plan document's
                // "Relief Mode Decision" for why no relief_mode split is used)

function _cairo_pentagonal_tile() =
    _tile_from_islands([
        for (pl = _CP_PLACEMENTS)
            let (poly = _cp_pentagon(pl[0], pl[1], pl[2]),
                 r = offset(poly, delta = -_CP_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _CP_Z]
    ]);

// --- Floret pentagonal (dual of the snub trihexagonal tiling) --------------
//
// Wikipedia "V3^4.6": rosettes of 6 congruent, irregular pentagons pinwheel
// around a shared hub point where all 6 meet (four 120-degree angles and one
// 60-degree angle per pentagon, the 60-degree angle always at the hub).
// Unlike cairo_pentagonal/rhombille, each rosette IS a multi-facet fan around
// a shared point -- structurally the same shape as the "kis" family's own
// N-way fans, just with pentagons instead of triangles and a hub vertex
// instead of a face centroid -- so this pattern DOES take a relief_mode
// parameter and alternates 2 heights around the rosette in "raised" mode,
// like tetrakis_square/kisrhombille's own even-fan alternation. See this
// pattern's plan document (docs/superpowers/plans/2026-09-20-floret-pentagonal-pattern.md)
// for the full derivation and the computational verification this
// construction is based on (a from-scratch snub-trihexagonal-tiling
// construction verified over a 150-vertex patch, its face-centroid dual
// verified the same way, an exact-Fraction lattice-covering/closure proof
// including a wider 4x4-tile-patch confirmation, plus a live OpenSCAD/BOSL2
// smoke test of this exact code path) -- do not re-derive the lattice by
// hand; it was verified, not guessed.
//
// The hexagon-center lattice underlying this tiling is a plain 60-degree
// TRIANGULAR lattice (two generators, equal length, 60 degrees apart) --
// the SAME shape of lattice tumbling_cubes/rhombille/kisrhombille already
// use for their own hexagon centers (_TC_V/_TC_CENTERS), which is why this
// pattern needs no shear and no new aspect-correction mechanism: like
// tumbling_cubes' _TC_V, the rotation + sqrt(3)-family anisotropic scale
// that normalizes this lattice to _UNIT_TILE space is baked directly into
// the pentagon vertex coordinates below, not applied at render time. The 5
// hub positions below are exactly _TC_CENTERS' own 5 positions -- verified,
// not assumed by analogy.
//
// _FP_P0.._FP_P5 are the tiling's 6 pentagon orientations (the full rosette
// around one hub), already normalized into unit-tile space, each listed
// with its shared hub vertex (0,0) first. All 6 have area exactly 1/12, are
// convex, and wind CCW.
_FP_P0 = [[0,0], [2/7,-4/21], [1/2,-1/6], [4/7,-1/21], [3/7,1/21]];
_FP_P1 = [[0,0], [3/7,1/21], [1/2,1/6], [5/14,11/42], [1/7,5/21]];
_FP_P2 = [[-2/7,4/21], [0,0], [1/7,5/21], [0,1/3], [-3/14,13/42]];
_FP_P3 = [[-4/7,1/21], [-3/7,-1/21], [0,0], [-2/7,4/21], [-1/2,1/6]];
_FP_P4 = [[-1/2,-1/6], [-5/14,-11/42], [-1/7,-5/21], [0,0], [-3/7,-1/21]];
_FP_P5 = [[-1/7,-5/21], [0,-1/3], [3/14,-13/42], [2/7,-4/21], [0,0]];
_FP_PENTS = [_FP_P0, _FP_P1, _FP_P2, _FP_P3, _FP_P4, _FP_P5];

// Which (hub, orientation) copies have any overlap with the unit square --
// exhaustively searched over the 5 canonical hub positions (_TC_CENTERS'
// own (0,0)/(1,0)/(0,1)/(1,1)/(0.5,0.5)) plus 2 extra copies of the
// (0.5,0.5) hub shifted +-1 in x (needed for full coverage -- see the plan's
// Geometry Derivation, Step 6, for why the naive 5-hub-only search came up
// 1/84 short of full unit-square area until this was found). Each entry is
// [hub_x, hub_y, k]: pentagon _FP_PENTS[k] translated so its hub sits at
// (hub_x, hub_y). Exactly these 18 placements' clipped areas sum to exactly
// 1.0, and their union was verified to equal the unit square exactly, with
// zero overlap among them.
_FP_PLACEMENTS = [
    [-1/2, 1/2, 0], [0, 1, 0], [0, 1, 5],
    [0, 0, 0], [0, 0, 1], [0, 0, 2],
    [1/2, 1/2, 0], [1/2, 1/2, 1], [1/2, 1/2, 2],
    [1/2, 1/2, 3], [1/2, 1/2, 4], [1/2, 1/2, 5],
    [1, 1, 3], [1, 1, 4], [1, 1, 5],
    [1, 0, 2], [1, 0, 3], [3/2, 1/2, 3],
];

function _fp_pentagon(m, n, k) = [for (p = _FP_PENTS[k]) [p[0] + m, p[1] + n]];

_FP_GAP  = 0.05; // engraved groove width, in tile fractions -- own constant,
                 // same scale as _KIS_GAP/_TC_GAP/_RH_GAP/_CP_GAP but never
                 // shared with them
_FP_Z_HI = 1.0;  // every rosette's "high" pentagons reach the tile's full height
_FP_Z_LO = 0.45; // the rosette's alternating "low" pentagons -- own constant,
                 // even though it numerically matches tetrakis_square's own
                 // low height, per this file's per-pattern-constant convention

// Raised mode alternates high/low by placement orientation k (even -> high,
// odd -> low) -- consistent across every hub instance, since every hub
// shares the identical 6-orientation set. Etched mode flattens every
// pentagon to the tile's full height, like the "kis" family's own etched
// mode -- see this pattern's plan document's "Relief Mode Decision".
function _floret_pentagonal_tile(relief_mode) =
    _tile_from_islands([
        for (pl = _FP_PLACEMENTS)
            let (poly = _fp_pentagon(pl[0], pl[1], pl[2]),
                 r = offset(poly, delta = -_FP_GAP / 2, closed = true),
                 z = (relief_mode == "etched") ? _FP_Z_HI
                     : ((pl[2] % 2 == 0) ? _FP_Z_HI : _FP_Z_LO))
            if (len(r) >= 3) [[r], z]
    ]);

// --- Deltoidal trihexagonal (dual of the rhombitrihexagonal tiling) --------
//
// Wikipedia "V3.4.6.4": a tessellation by congruent kite/deltoid
// quadrilaterals -- 2 short edges and 2 long edges (verified: edge-length
// ratio is not 1, so this is a genuine kite, not a rhombus), with a line of
// symmetry through its two "pointy" vertices (the hexagon-centroid hub and
// the triangle-centroid tip). See this pattern's plan document
// (docs/superpowers/plans/2026-09-20-deltoidal-trihexagonal-pattern.md) for
// the full derivation and the computational verification this construction
// is based on (a from-scratch rhombitrihexagonal-tiling construction
// verified over a 34-vertex core patch, its face-centroid dual verified via
// exact-Fraction area/closure/overlap checks including a wider 4x4-tile-patch
// confirmation, plus a live OpenSCAD/BOSL2 smoke test of this exact code
// path) -- do not re-derive the lattice by hand; it was verified, not
// guessed.
//
// The hexagon-vertex lattice underlying this tiling is a plain 60-degree
// TRIANGULAR lattice (two generators, equal length 1+sqrt(3), 60 degrees
// apart) -- the SAME shape of lattice tumbling_cubes/rhombille/kisrhombille/
// floret_pentagonal already use for their own hexagon-related centers, which
// is why this pattern needs no shear and no new aspect-correction mechanism:
// like tumbling_cubes' _TC_V, the rotation (here, trivially 0 degrees --
// this tiling's own G1 generator was chosen along the x-axis from the start)
// + sqrt(3)-family anisotropic scale that normalizes this lattice to
// _UNIT_TILE space is baked directly into the kite vertex coordinates below,
// not applied at render time. NOTE: this is NOT the same primal tiling
// tumbling_cubes/rhombille's own hexagon lattice (_TC_V/_TC_CENTERS) comes
// from -- that lattice is a plain edge-to-edge hexagonal tiling with no
// triangles or squares (checked directly and confirmed not reusable; see
// this pattern's plan document's "What 'rectangular lattice' means here"
// section), so _DT_K0.._DT_K5 below are this pattern's own independent
// derivation, not a reuse of _TC_V.
//
// _DT_K0.._DT_K5 are the tiling's 6 kite orientations (the full rosette
// around one hexagon-centroid hub), already normalized into unit-tile
// space, each listed as [hub, side1, tip, side2] (hub = hexagon centroid,
// shared by all 6; side1/side2 = two different square centroids; tip = a
// triangle centroid). All 6 have area exactly 1/12, are convex, and wind
// CCW.
_DT_K0 = [[0,0], [1/4,1/4], [0,1/3], [-1/4,1/4]];
_DT_K1 = [[0,0], [-1/4,1/4], [-1/2,1/6], [-1/2,0]];
_DT_K2 = [[0,0], [-1/2,0], [-1/2,-1/6], [-1/4,-1/4]];
_DT_K3 = [[0,0], [-1/4,-1/4], [0,-1/3], [1/4,-1/4]];
_DT_K4 = [[0,0], [1/4,-1/4], [1/2,-1/6], [1/2,0]];
_DT_K5 = [[0,0], [1/2,0], [1/2,1/6], [1/4,1/4]];
_DT_KITES = [_DT_K0, _DT_K1, _DT_K2, _DT_K3, _DT_K4, _DT_K5];

// Which (hub, orientation) copies have any overlap with the unit square --
// exhaustively searched over the true hexagon-center lattice
// {m*(1,0) + n*(1/2,1/2) : m,n integer} (NOT an independent-per-axis grid --
// see the plan's Geometry Derivation, Step 5, for the wrong search that found
// spurious extra placements at non-lattice points before this was fixed).
// Each entry is [hub_x, hub_y, k]: kite _DT_KITES[k] translated so its hub
// sits at (hub_x, hub_y). Exactly these 14 placements' clipped areas sum to
// exactly 1 (verified with exact Fraction arithmetic), and their union was
// verified to equal the unit square exactly, with zero overlap among them.
_DT_PLACEMENTS = [
    [0, 1, 3], [0, 1, 4],
    [0, 0, 0], [0, 0, 5],
    [1/2, 1/2, 0], [1/2, 1/2, 1], [1/2, 1/2, 2],
    [1/2, 1/2, 3], [1/2, 1/2, 4], [1/2, 1/2, 5],
    [1, 1, 2], [1, 1, 3],
    [1, 0, 0], [1, 0, 1],
];

function _dt_kite(m, n, k) = [for (p = _DT_KITES[k]) [p[0] + m, p[1] + n]];

_DT_GAP = 0.05; // engraved groove width, in tile fractions -- own constant,
                // same scale as _KIS_GAP/_TC_GAP/_RH_GAP/_CP_GAP/_FP_GAP but
                // never shared with them
_DT_Z   = 1.0;  // every kite reaches the tile's full height (uniform, like
                // rhombille/cairo_pentagonal -- see this pattern's plan
                // document's "Relief Mode Decision" for why: unlike
                // floret_pentagonal's single clean rosette fan, this
                // tiling's kites belong to THREE competing fan types
                // (6-fan/4-fan/3-fan) at once, so no single alternation
                // scheme applies without an arbitrary choice)

function _deltoidal_trihexagonal_tile() =
    _tile_from_islands([
        for (pl = _DT_PLACEMENTS)
            let (poly = _dt_kite(pl[0], pl[1], pl[2]),
                 r = offset(poly, delta = -_DT_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _DT_Z]
    ]);

// --- Kisrhombille (kis of the rhombille tiling) ------------------------------
//
// Wikipedia: kis applied to the rhombille tiling's rhombi ("each rhombus
// divided into" triangles from its own center), equivalently described as
// "an equilateral hexagonal tiling with each hexagon divided into 12
// triangles from the center point" (3 rhombi x 4 triangles each = 12).
// Reuses tumbling_cubes' own hexagon/rhombus geometry directly (_TC_V,
// _tc_rhombus(), _TC_CENTERS) rather than re-deriving it -- same tiling,
// just kis-fanned instead of raised as three flat plateaus.
//
// Raised: each rhombus's own 4-triangle fan alternates heights the same way
// tetrakis_square's does. Flattened with `each` since _kis_shrunk_fan()
// already returns a list of [region, height] islands per rhombus, and we
// need all of them (5 centers x 3 rhombi x up to 4 triangles) concatenated
// into one islands list before clipping to the unit tile. Etched and
// alternating route to the two shared builders instead.
_KISR_OUTER_GAP = 0.05;  // etched primary groove (between different rhombi/
                         // hexagons), own constant
_KISR_INNER_GAP = 0.025; // etched secondary groove (within one rhombus's own
                         // 4-triangle fan) -- thinner than the primary tier

// alt_key = the fan-triangle's own local index (0..3), matching the SAME
// pinwheel parity the raised heights already use ([1.0, 0.4, 1.0, 0.4] --
// indices 0 and 2 are "high"). group_id must be unique PER FAN (composite
// (center, k)), not the local triangle index alone: kisrhombille builds 15
// separate fans (5 hexagon centers x 3 rhombi each), and using just the
// local index as group_id would collide triangle 0 of one fan with triangle
// 0 of every other fan, which the outline builder would then treat as one
// same-motif internal seam instead of the real motif-to-motif boundaries
// between separate rhombi -- silently suppressing grooves that should exist.
_KISR_HIGH_GROUP = [0, 2];

function _kisrhombille_motif_groups() =
    let (centers = _outline_supertile_points(_TC_CENTERS))
    [for (c = centers) for (k = [0:2]) _kis_raw_fan(_tc_rhombus(c, k))];

// _kis_shrunk_fan() already returns [region, height] pairs per triangle in
// winding order (one per edge of the input polygon, i.e. per fan triangle);
// heights=[0,1,2,3] here is a placeholder standing in for "this triangle's
// own local index" so each returned pair's height doubles as alt_key below.
function _kisrhombille_alternating_islands() =
    [for (c = _TC_CENTERS) for (k = [0:2])
        let (fan = _kis_shrunk_fan(_tc_rhombus(c, k), _KIS_GAP, [0, 1, 2, 3]))
        for (ti = [0:len(fan)-1])
            [fan[ti][0], 1, [c[0], c[1], k], fan[ti][1]]];

function _kisrhombille_tile(relief_mode) =
    relief_mode == "etched"
        ? _tile_outline_from_islands(_kisrhombille_motif_groups(), _KISR_OUTER_GAP, _KISR_INNER_GAP)
    : relief_mode == "alternating"
        ? _tile_alternating_from_islands(_kisrhombille_alternating_islands(), _KISR_HIGH_GROUP)
    : _tile_from_islands([
        for (c = _TC_CENTERS) for (k = [0:2])
            each _kis_shrunk_fan(_tc_rhombus(c, k), _KIS_GAP, [1.0, 0.4, 1.0, 0.4])
    ]);

// --- Triakis triangular (kis of the triangular tiling) ----------------------
//
// Wikipedia: "an equilateral triangular tiling with each triangle divided
// into three ... triangles from the center point." The simplest triangular
// tiling that fits the unit tile exactly is the unit square split by one
// diagonal into two right triangles -- like kisrhombille's reuse of
// tumbling_cubes' already-unit-square-normalized hexagons, this trades
// perfect equilateral regularity for an exact, simple unit-square tiling
// (the same precedent _UNIT_TILE's own convention already sets). Each half
// is then kis-fanned into 3 sub-triangles.
//
// Three distinct heights per fan (not just two, unlike tetrakis_square's
// 4-triangle alternation) -- matching tumbling_cubes' own reasoning that
// three DIFFERENT heights read better than any two repeated.
_TT_A = [[0, 0], [1, 0], [1, 1]];
_TT_B = [[0, 0], [1, 1], [0, 1]];

function _triakis_triangular_tile(relief_mode) =
    _tile_from_islands(concat(
        _kis_shrunk_fan(_TT_A, _KIS_GAP, relief_mode == "etched" ? 1.0 : [1.0, 0.4, 0.7]),
        _kis_shrunk_fan(_TT_B, _KIS_GAP, relief_mode == "etched" ? 1.0 : [1.0, 0.4, 0.7])
    ));

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

_IS_OUTER_GAP = 0.05; // etched primary (motif-to-motif) groove width, own
                      // constant -- never shared, matching this file's
                      // per-pattern-constant convention even though it
                      // happens to equal _IS_GAP
_IS_INNER_GAP = 0.03; // etched secondary groove width -- unused in practice
                      // for this pattern (every group here has exactly one
                      // sub-region, so there are no same-group internal
                      // edges to groove), but still required as a parameter

// star=0 (high), the four crosses=1..4 (low) -- group_id and alt_key
// coincide here (each group has one sub-region, so the natural motif
// identity IS the natural alternation bucket).
_IS_HIGH_GROUP = [0];

function _islamic_star_motif_groups() =
    let (
        star_centers  = _outline_supertile_points([[0.5, 0.5]]),
        cross_centers = _outline_supertile_points(_IS_CROSS_CENTERS)
    )
    concat([for (c = star_centers) [_is_star(c)]],
           [for (c = cross_centers) [_is_cross(c)]]);

function _islamic_star_alternating_islands() =
    concat(
        [[[offset(_is_star([0.5, 0.5]), delta = -_IS_GAP / 2, closed = true)], 1, 0, 0]],
        [for (i = [0:3]) let (c = _IS_CROSS_CENTERS[i])
            [[offset(_is_cross(c), delta = -_IS_GAP / 2, closed = true)], 1, i + 1, i + 1]]);

function _islamic_star_tile(relief_mode) =
    relief_mode == "etched"
        ? _tile_outline_from_islands(_islamic_star_motif_groups(), _IS_OUTER_GAP, _IS_INNER_GAP)
    : relief_mode == "alternating"
        ? _tile_alternating_from_islands(_islamic_star_alternating_islands(), _IS_HIGH_GROUP)
    : _tile_from_islands(concat(
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
    pattern_type == "islamic_star"   ? _islamic_star_tile(relief_mode) :
    pattern_type == "tetrakis_square" ? _tetrakis_square_tile(relief_mode) :
    pattern_type == "kisrhombille"    ? _kisrhombille_tile(relief_mode) :
    pattern_type == "triakis_triangular" ? _triakis_triangular_tile(relief_mode) :
    pattern_type == "rhombille"          ? _rhombille_tile() :
    pattern_type == "cairo_pentagonal"   ? _cairo_pentagonal_tile() :
    pattern_type == "floret_pentagonal"  ? _floret_pentagonal_tile(relief_mode) :
    pattern_type == "deltoidal_trihexagonal" ? _deltoidal_trihexagonal_tile() :
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
// from the result: with several custom VNF tiles now, having _decoration_style()
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
    assert(in_list(relief_mode, RELIEF_MODES),
        str("relief_mode must be one of ", RELIEF_MODES, ", got \"", relief_mode, "\""));
    assert(relief_mode != "alternating" || in_list(pattern_type, ALTERNATING_PATTERNS),
        str("relief_mode \"alternating\" is only supported for pattern_type in ",
            ALTERNATING_PATTERNS, ", got \"", pattern_type, "\""));
    if (pattern_type == "none") {
        cylinder(h = height, r1 = r1, r2 = r2, $fn = fn);
    } else {
        assert(pattern_depth < wall_thickness * 0.7,
            str("pattern_depth (", pattern_depth, ") must be < 70% of wall_thickness (", wall_thickness, ")"));
        assert(is_int(pattern_repeat) && pattern_repeat > 0,
            str("pattern_repeat must be a positive whole number, got ", pattern_repeat));
        // "tumbling_cubes"/"intertwine"/"islamic_star" tile large flat plateaus,
        // whose single flat facet can cut back inside the wall and abort the
        // cavity subtraction in CGAL. Which values trip it depends on
        // pattern_repeat and smoothness jointly (see README). OpenSCAD still
        // exits 0 and still writes an STL when it happens, so warn up front
        // rather than let a silently-truncated export look successful.
        // "rhombille" reuses tumbling_cubes' own hexagon/rhombus geometry
        // directly (same large flat plateaus, just one height instead of
        // three) and measured the same class of CGAL fragility -- see
        // README.md for the specific failing/clean values.
        // "cairo_pentagonal" tiles 8 flat pentagon plateaus per unit tile and
        // measured the same fragility in a real sweep (it aborts at
        // pattern_repeat 3, 5, 10 and 11 at smoothness=24, and at
        // smoothness=100 in "etched" at the shipped pattern_repeat=16), so it
        // belongs in this bucket rather than the precautionary one below.
        // "floret_pentagonal" has the largest per-tile island count of the
        // group (18 flat pentagon plateaus per unit tile, vs. Cairo's 8) and
        // measured the widest spread of aborting pattern_repeat values of any
        // pattern here in a real sweep. The shipped defaults themselves (16,
        // smoothness=60) measure clean in both relief modes, but with a
        // thinner margin below them than any other pattern, so CI pins them.
        // See README.md.
        // The three "kis" family patterns share the same small-triangular-facet
        // tile construction and get the same defensive warning as a precaution,
        // but every tested pattern_repeat/smoothness/relief_mode combination for
        // them has measured CGAL-clean, so their message doesn't claim a known
        // failure -- see README.md's CGAL section. "deltoidal_trihexagonal"
        // shares this same mild bucket despite being built from the same class
        // of large flat plateau construction as the "known to abort" patterns
        // above (14 kite islands per unit tile) -- a full sweep of the real
        // assembly across every pattern_repeat 3-16 and every smoothness
        // 24/40/60/80/100 (both relief modes) found zero CGAL aborts anywhere,
        // a genuinely different result from every other large-flat-plateau
        // pattern in this file. See README.md's CGAL section for the full
        // sweep table.
        if (in_list(pattern_type, ["tumbling_cubes", "intertwine", "islamic_star", "rhombille",
                                   "cairo_pentagonal", "floret_pentagonal"]))
            echo(str("WARNING: pattern_type \"", pattern_type, "\" is known to abort CGAL ",
                     "for some pattern_repeat/smoothness combinations, and OpenSCAD still ",
                     "exits 0 and writes a truncated STL when it does. Scan this console for ",
                     "a CGAL assertion before trusting the export; if you see one, nudge ",
                     "pattern_repeat or smoothness. See README.md."));
        else if (in_list(pattern_type, ["tetrakis_square", "kisrhombille", "triakis_triangular",
                                        "deltoidal_trihexagonal"]))
            echo(str("WARNING: pattern_type \"", pattern_type, "\" carries the same precautionary ",
                     "CGAL warning as the other custom VNF tile patterns (small triangular fans or ",
                     "large flat plateau facets, same general class of tile construction), but has ",
                     "measured CGAL-clean at every tested pattern_repeat/smoothness/relief_mode ",
                     "combination. Scan this ",
                     "console for a CGAL assertion anyway before trusting the export -- if you see ",
                     "one, nudge pattern_repeat or smoothness. See README.md."));
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
            tex_reps = [pattern_repeat, _square_tile_vertical_reps(pattern_type, pattern_orientation, pattern_repeat, r1, r2, height)],
            tex_depth = depth,
            // BOSL2 normalises tex_inset=true to exactly 1 (skin.scad:5203),
            // so this is full inset: the texture's high points land on the
            // nominal wall and everything else is cut in.
            tex_inset = (relief_mode == "etched") ? true
                      : (relief_mode == "alternating") ? 0.5
                      : false, // "raised"
            tex_rot = rot,
            style = _decoration_style_for(tex));
    }
}
