// tests/test_decoration_tile_aspect.scad
include <../modules/decoration.scad>

// Plain square-tile pattern ("dots"): vertical_reps should make each tile
// close to square at the average radius, i.e.
// round(pattern_repeat * height / (PI * (r1 + r2))).
r1 = 61;
r2 = 82.3;
height = 138;
pattern_repeat = 16;
avg_circ = PI * (r1 + r2);

v_dots = _square_tile_vertical_reps("dots", "vertical", pattern_repeat, r1, r2, height);
expected_dots = round(pattern_repeat * height / avg_circ);
assert(v_dots == expected_dots,
    str("expected dots vertical_reps ", expected_dots, ", got ", v_dots));
assert(v_dots == 5, str("expected 5 at documented defaults, got ", v_dots));

// sqrt(3)-corrected pattern ("cubes"): same inputs must give a SMALLER
// vertical_reps than the plain formula, by a factor of sqrt(3) -- fewer,
// taller rows so each cube's height is physically sqrt(3) times its width,
// per BOSL2's own documented requirement for a correctly-proportioned
// "cubes" texture.
v_cubes = _square_tile_vertical_reps("cubes", "vertical", pattern_repeat, r1, r2, height);
expected_cubes = round(pattern_repeat * height / (avg_circ * sqrt(3)));
assert(v_cubes == expected_cubes,
    str("expected cubes vertical_reps ", expected_cubes, ", got ", v_cubes));
assert(v_cubes < v_dots,
    "cubes vertical_reps must be smaller than the plain square-tile count (sqrt(3) correction)");

// hex_grid and tri_grid get the same sqrt(3) treatment as cubes.
v_hex = _square_tile_vertical_reps("hex_grid", "vertical", pattern_repeat, r1, r2, height);
v_tri = _square_tile_vertical_reps("tri_grid", "vertical", pattern_repeat, r1, r2, height);
assert(v_hex == expected_cubes, str("expected hex_grid vertical_reps ", expected_cubes, ", got ", v_hex));
assert(v_tri == expected_cubes, str("expected tri_grid vertical_reps ", expected_cubes, ", got ", v_tri));

// BOSL2 rotates the texture tile's own content by 90 degrees when
// pattern_orientation == "horizontal" (tex_rot=90 in decorated_solid()),
// which swaps which of the tile's own axes lands on the surface's
// circumferential vs. vertical axis. tex_reps itself is never swapped by
// BOSL2 -- tex_reps[0] always means "around" and tex_reps[1] always means
// "along the height" -- so the sqrt(3) correction must flip from a divide
// to a multiply when the tile content is rotated: the correctly-proportioned
// pattern in "horizontal" orientation needs MORE (shorter) vertical cells,
// not fewer (taller) ones, since the "tall" requirement is now satisfied by
// the fixed circumferential axis instead.
v_cubes_horizontal = _square_tile_vertical_reps("cubes", "horizontal", pattern_repeat, r1, r2, height);
expected_cubes_horizontal = round(pattern_repeat * height * sqrt(3) / avg_circ);
assert(v_cubes_horizontal == expected_cubes_horizontal,
    str("expected horizontal cubes vertical_reps ", expected_cubes_horizontal, ", got ", v_cubes_horizontal));
assert(v_cubes_horizontal > v_dots,
    "horizontal-orientation cubes vertical_reps must be larger than the plain square-tile count (inverted sqrt(3) correction)");

// Excluded patterns keep vertical_reps == pattern_repeat regardless of the
// real geometry -- "ridges" is directional, "bricks" is intentionally
// rectangular.
v_ridges = _square_tile_vertical_reps("ridges", "vertical", pattern_repeat, r1, r2, height);
v_bricks = _square_tile_vertical_reps("bricks", "vertical", pattern_repeat, r1, r2, height);
assert(v_ridges == pattern_repeat, str("expected ridges vertical_reps ", pattern_repeat, ", got ", v_ridges));
assert(v_bricks == pattern_repeat, str("expected bricks vertical_reps ", pattern_repeat, ", got ", v_bricks));

// The custom VNF tiles (built on _UNIT_TILE, confirmed unit-square, no
// intrinsic correction) use the plain formula, same as "dots".
for (pt = ["teardrop", "tumbling_cubes", "intertwine", "islamic_star", "rhombille",
           "cairo_pentagonal", "floret_pentagonal", "deltoidal_trihexagonal",
           "tetrakis_square", "kisrhombille",
           "triakis_triangular", "diamonds", "pyramids", "checkers"]) {
    v = _square_tile_vertical_reps(pt, "vertical", pattern_repeat, r1, r2, height);
    assert(v == expected_dots,
        str("expected ", pt, " vertical_reps ", expected_dots, ", got ", v));
}

// Minimum-1 clamp: a tall/thin custom outer shape (height >> circumference)
// must not compute a fractional or zero vertical_reps.
v_tall = _square_tile_vertical_reps("dots", "vertical", 2, 10, 10, 500);
assert(v_tall >= 1, str("expected clamped vertical_reps >= 1, got ", v_tall));
assert(is_int(v_tall), "vertical_reps must be an integer");

cube(0.001);
