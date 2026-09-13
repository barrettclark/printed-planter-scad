// tests/test_body_custom_assert.scad
include <../modules/body.scad>
// outer_height (100) is deliberately shorter than pot_height (138) — must fail.
outer_body_custom(150, 110, 100, 138);
