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

v_dots = _square_tile_vertical_reps("dots", pattern_repeat, r1, r2, height);
expected_dots = round(pattern_repeat * height / avg_circ);
assert(v_dots == expected_dots,
    str("expected dots vertical_reps ", expected_dots, ", got ", v_dots));
assert(v_dots == 5, str("expected 5 at documented defaults, got ", v_dots));

// sqrt(3)-corrected pattern ("cubes"): same inputs must give a SMALLER
// vertical_reps than the plain formula, by a factor of sqrt(3) -- fewer,
// taller rows so each cube's height is physically sqrt(3) times its width,
// per BOSL2's own documented requirement for a correctly-proportioned
// "cubes" texture.
v_cubes = _square_tile_vertical_reps("cubes", pattern_repeat, r1, r2, height);
expected_cubes = round(pattern_repeat * height / (avg_circ * sqrt(3)));
assert(v_cubes == expected_cubes,
    str("expected cubes vertical_reps ", expected_cubes, ", got ", v_cubes));
assert(v_cubes < v_dots,
    "cubes vertical_reps must be smaller than the plain square-tile count (sqrt(3) correction)");

// hex_grid and tri_grid get the same sqrt(3) treatment as cubes.
v_hex = _square_tile_vertical_reps("hex_grid", pattern_repeat, r1, r2, height);
v_tri = _square_tile_vertical_reps("tri_grid", pattern_repeat, r1, r2, height);
assert(v_hex == expected_cubes, str("expected hex_grid vertical_reps ", expected_cubes, ", got ", v_hex));
assert(v_tri == expected_cubes, str("expected tri_grid vertical_reps ", expected_cubes, ", got ", v_tri));

// Excluded patterns keep vertical_reps == pattern_repeat regardless of the
// real geometry -- "ridges" is directional, "bricks" is intentionally
// rectangular.
v_ridges = _square_tile_vertical_reps("ridges", pattern_repeat, r1, r2, height);
v_bricks = _square_tile_vertical_reps("bricks", pattern_repeat, r1, r2, height);
assert(v_ridges == pattern_repeat, str("expected ridges vertical_reps ", pattern_repeat, ", got ", v_ridges));
assert(v_bricks == pattern_repeat, str("expected bricks vertical_reps ", pattern_repeat, ", got ", v_bricks));

// The four custom VNF tiles (built on _UNIT_TILE, confirmed unit-square, no
// intrinsic correction) use the plain formula, same as "dots".
for (pt = ["teardrop", "tumbling_cubes", "intertwine", "islamic_star", "diamonds", "pyramids", "checkers"]) {
    v = _square_tile_vertical_reps(pt, pattern_repeat, r1, r2, height);
    assert(v == expected_dots,
        str("expected ", pt, " vertical_reps ", expected_dots, ", got ", v));
}

// Minimum-1 clamp: a tall/thin custom outer shape (height >> circumference)
// must not compute a fractional or zero vertical_reps.
v_tall = _square_tile_vertical_reps("dots", 2, 10, 10, 500);
assert(v_tall >= 1, str("expected clamped vertical_reps >= 1, got ", v_tall));
assert(is_int(v_tall), "vertical_reps must be an integer");

cube(0.001);
