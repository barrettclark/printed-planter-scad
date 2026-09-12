# Parametric Decorative Planter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a parametric OpenSCAD generator (`planter.scad`) that produces a decorative outer planter shell sized and fit to a user-specified plastic insert, with configurable ridge/geometric surface decoration (raised or etched), driven entirely by Customizer parameters.

**Architecture:** BOSL2-based OpenSCAD project. The cavity (what the insert sits in) and the outer decorative body are each built as revolved 2D profiles (`rotate_extrude` over a polygon of `[radius, z]` points), then combined via `difference()`. Decoration is applied to the outer body via BOSL2's `cyl()` texture support before the cavity is subtracted. All geometry math lives in pure functions per module so it can be tested with `assert()` independent of rendering.

**Tech Stack:** OpenSCAD 2021.01 (installed at `/opt/homebrew/bin/openscad`), BOSL2 (vendored, pinned copy committed to repo).

**Spec:** `docs/superpowers/specs/2026-09-12-parametric-planter-design.md`

## Erratum (post-implementation)

This plan was written before the vendored BOSL2 copy or its exact API were
available to inspect, and before OpenSCAD's `include`-based variable
override semantics were tested. Two assumptions below turned out to be
wrong; the text is left as originally written for historical accuracy, but
here is what actually happened during implementation:

- **`lib/BOSL2/textures.scad` does not exist** in the vendored BOSL2
  (Task 1, Step 3 and Step 4 reference it). Texture support lives in
  `lib/BOSL2/skin.scad`, which `lib/BOSL2/std.scad` already includes.
  `modules/decoration.scad` includes only `std.scad`.
- **Pre-`include` variable assignment does not override an included file's
  own defaults** in OpenSCAD — the textually-last assignment wins
  regardless of `include` order. This broke Task 6's and Task 8's planned
  test-harness pattern (assign variables in a wrapper, then `include
  <../planter.scad>`, expecting the wrapper's values to take effect). The
  actual test suite instead uses OpenSCAD's `-D 'var=value'` CLI flag,
  which is the real override mechanism, and `tests/test_planter_integration.scad`
  is a bare `include` with no pre-assignments. Task 8's `sed`-editing-a-
  wrapper approach (Step 1 of that task) was never executed as written for
  this reason — see the shipped `.github/workflows/test.yml` for the test
  matrix actually run in CI, which also runs every test file, not the
  subset Task 8's Step 3 loop lists.

## Global Constraints

- Round outer cross-section only (no square/hex outer body) this iteration.
- Floor is always solid; `drainage_holes` is a boolean toggle adding holes to that solid floor (not a separate base style).
- BOSL2 is vendored under `lib/BOSL2/` and committed — not a live git submodule.
- `pattern_depth < wall_thickness * 0.7` must be asserted wherever decoration is applied.
- Customizer parameters live only in `planter.scad` (top-level file); included modules take all values as explicit function/module arguments — no reliance on global variables from included files.
- Never commit without Barrett's explicit go-ahead for that specific commit; never push to GitHub without a separate explicit confirmation.

## Testing Convention (OpenSCAD)

There is no unit-test runner for OpenSCAD. Tests in this plan are `.scad` files under `tests/` that:
1. `include` the module file under test.
2. Call its pure functions and check results with `assert(condition, "message")`.
3. End with a trivial `cube(0.001);` so OpenSCAD has *something* to render (avoids "nothing to render" warnings masking real failures).

Run a test with:
```bash
openscad -o /tmp/test_out.csg tests/test_NAME.scad
```
- **Fail:** non-zero exit code, stderr contains `ERROR: Assertion failed` (or a parse error, if the function/module doesn't exist yet — this is the expected failure for a not-yet-implemented step).
- **Pass:** exit code 0, `/tmp/test_out.csg` created, no `ERROR` in output.

---

### Task 1: Project scaffolding and BOSL2 vendoring

**Files:**
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `lib/BOSL2/` (vendored library, via `git clone` then de-git'd and committed as plain files)
- Create: `tests/test_bosl2_texture_smoke.scad`

**Interfaces:**
- Produces: `lib/BOSL2/std.scad`, `lib/BOSL2/textures.scad` available for `include <lib/BOSL2/std.scad>` from files in the repo root, and `include <../lib/BOSL2/std.scad>` from files in `modules/` or `tests/`.

- [ ] **Step 1: Create `.gitignore`**

```
*.stl
*.3mf
*.csg
*.png
.DS_Store
```

- [ ] **Step 2: Add an MIT `LICENSE` file**

Use standard MIT license text with copyright line `Copyright (c) 2026 Barrett Clark`.

- [ ] **Step 3: Vendor BOSL2**

```bash
mkdir -p /tmp/bosl2-vendor
git clone --depth 1 https://github.com/BelfrySCAD/BOSL2.git /tmp/bosl2-vendor
rm -rf /tmp/bosl2-vendor/.git
mkdir -p lib
cp -R /tmp/bosl2-vendor lib/BOSL2
rm -rf /tmp/bosl2-vendor
```

Record the vendored commit hash in a comment at the top of a new `lib/BOSL2_VERSION.txt` file (one line: the short SHA `git ls-remote --depth 1 https://github.com/BelfrySCAD/BOSL2.git HEAD` returns) so the pinned version is traceable later.

- [ ] **Step 4: Enumerate available texture names**

```bash
grep -oE '"\[?[a-z_]+_(ribs|diamonds|pyramids|grid|hex|dots|bricks|scales)[a-z_]*"' lib/BOSL2/textures.scad | sort -u
```

Write the resulting list of literal texture name strings to a comment block at the top of `tests/test_bosl2_texture_smoke.scad` — Task 5 (decoration module) depends on these exact strings.

- [ ] **Step 5: Write BOSL2 compatibility smoke test**

```openscad
// tests/test_bosl2_texture_smoke.scad
// Available BOSL2 texture names found via grep (fill in from Step 4 output above).
include <../lib/BOSL2/std.scad>

// Confirms this OpenSCAD version can build a textured cylinder using BOSL2.
cyl(h=20, r1=10, r2=8, texture="ribs", tex_size=[10,10], tex_depth=1, $fn=64);
```

- [ ] **Step 6: Run the smoke test and confirm it renders**

```bash
openscad -o /tmp/test_out.csg tests/test_bosl2_texture_smoke.scad
echo "exit: $?"
```
Expected: `exit: 0`, no `ERROR` in output. If the texture name from Step 4 doesn't exist, the error message lists valid names — pick a real one from that list and retry before moving on.

- [ ] **Step 7: Commit**

```bash
git add .gitignore LICENSE lib/BOSL2 lib/BOSL2_VERSION.txt tests/test_bosl2_texture_smoke.scad
git commit -m "Vendor BOSL2 and verify texture rendering compatibility"
```

---

### Task 2: Insert cavity profile module

**Files:**
- Create: `modules/insert.scad`
- Test: `tests/test_insert.scad`

**Interfaces:**
- Produces:
  - `function insert_cavity_height(insert_height, floor_thickness, bottom_margin)` → number (overall pot height required to fit the insert).
  - `function cavity_radius_at(z, insert_top_d, insert_bottom_d, insert_height, ledge_engagement_height, fit_clearance, body_clearance, pot_height)` → number (cavity radius at a given z, using the *lower* (loose) radius at the exact ledge boundary — callers needing the step's upper radius use `insert_top_d/2 + fit_clearance` directly).
  - `module insert_cavity(insert_top_d, insert_bottom_d, insert_height, ledge_engagement_height, fit_clearance, body_clearance, bottom_margin, floor_thickness, overshoot=20, fn=50)` → solid to `difference()` out of the outer body. Open at the top (extends `overshoot` mm above the rim) and flat (r=0 center point) at `z = floor_thickness`.

- [ ] **Step 1: Write the failing test**

```openscad
// tests/test_insert.scad
include <../modules/insert.scad>

// pot_height = insert_height + floor_thickness + bottom_margin
h = insert_cavity_height(130, 3, 5);
assert(h == 138, str("expected pot_height 138, got ", h));

// At the very top (z = pot_height), radius must equal the tight ledge fit.
r_top = cavity_radius_at(138, 150, 110, 130, 8, 0.3, 3, 138);
assert(r_top == 150/2 + 0.3, str("expected ledge radius 75.3, got ", r_top));

// At the bottom of the cavity (z = floor_thickness), radius must equal the
// loose clearance-zone fit around the insert's bottom.
r_bottom = cavity_radius_at(3, 150, 110, 130, 8, 0.3, 3, 138);
assert(r_bottom == 110/2 + 3, str("expected clearance radius 58, got ", r_bottom));

cube(0.001);
```

- [ ] **Step 2: Run test to verify it fails**

```bash
openscad -o /tmp/test_out.csg tests/test_insert.scad
```
Expected: FAIL — parse error, `insert.scad` does not exist yet.

- [ ] **Step 3: Write `modules/insert.scad`**

```openscad
// modules/insert.scad
function _lerp(a, b, t) = a + (b - a) * t;

function insert_cavity_height(insert_height, floor_thickness, bottom_margin) =
    insert_height + floor_thickness + bottom_margin;

function cavity_radius_at(z, insert_top_d, insert_bottom_d, insert_height,
                           ledge_engagement_height, fit_clearance, body_clearance,
                           pot_height) =
    let(
        insert_bottom_z = pot_height - insert_height,
        ledge_bottom_z  = pot_height - ledge_engagement_height
    )
    z <= insert_bottom_z ? insert_bottom_d/2 + body_clearance :
    z <  ledge_bottom_z  ? _lerp(insert_bottom_d/2, insert_top_d/2,
                                  (z - insert_bottom_z) / (ledge_bottom_z - insert_bottom_z))
                            + body_clearance :
    insert_top_d/2 + fit_clearance;

module insert_cavity(insert_top_d, insert_bottom_d, insert_height,
                      ledge_engagement_height, fit_clearance, body_clearance,
                      bottom_margin, floor_thickness, overshoot=20, fn=50) {
    pot_height = insert_cavity_height(insert_height, floor_thickness, bottom_margin);
    ledge_bottom_z = pot_height - ledge_engagement_height;
    r_bottom      = cavity_radius_at(floor_thickness, insert_top_d, insert_bottom_d,
                                      insert_height, ledge_engagement_height,
                                      fit_clearance, body_clearance, pot_height);
    r_ledge_lower = cavity_radius_at(ledge_bottom_z, insert_top_d, insert_bottom_d,
                                      insert_height, ledge_engagement_height,
                                      fit_clearance, body_clearance, pot_height);
    r_ledge_upper = insert_top_d/2 + fit_clearance;

    pts = [
        [0, floor_thickness],
        [r_bottom, floor_thickness],
        [r_bottom, pot_height - insert_height],
        [r_ledge_lower, ledge_bottom_z],
        [r_ledge_upper, ledge_bottom_z],
        [r_ledge_upper, pot_height + overshoot],
        [0, pot_height + overshoot]
    ];
    rotate_extrude($fn=fn) polygon(pts);
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
openscad -o /tmp/test_out.csg tests/test_insert.scad
echo "exit: $?"
```
Expected: `exit: 0`, no `ERROR`.

- [ ] **Step 5: Visual render check**

```bash
openscad -o /tmp/insert_cavity.png --imgsize=800,800 --camera=0,0,60,60,0,45,300 \
  -D 'insert_top_d=150; insert_bottom_d=110; insert_height=130; ledge_engagement_height=8; fit_clearance=0.3; body_clearance=3; bottom_margin=5; floor_thickness=3;' \
  --D 'insert_cavity(insert_top_d, insert_bottom_d, insert_height, ledge_engagement_height, fit_clearance, body_clearance, bottom_margin, floor_thickness);' 2>&1 || true
```
If `-D`-based module invocation doesn't render as expected on this OpenSCAD version, instead create a scratch file `/tmp/preview_insert.scad` that includes `modules/insert.scad` and calls `insert_cavity(150, 110, 130, 8, 0.3, 3, 5, 3);`, then run `openscad -o /tmp/insert_cavity.png --imgsize=800,800 /tmp/preview_insert.scad`. Open the PNG and confirm: a stepped cavity profile, tight recess at the top, wider open recess below it, solid disc at the bottom.

- [ ] **Step 6: Commit**

```bash
git add modules/insert.scad tests/test_insert.scad
git commit -m "Add insert cavity profile module with ledge/clearance zones"
```

---

### Task 3: Outer body module (follow-insert and custom modes)

**Files:**
- Create: `modules/body.scad`
- Test: `tests/test_body.scad`

**Interfaces:**
- Consumes: `modules/insert.scad` — `cavity_radius_at()`, `insert_cavity_height()`.
- Produces:
  - `module outer_body_follow(insert_top_d, insert_bottom_d, insert_height, ledge_engagement_height, fit_clearance, body_clearance, bottom_margin, floor_thickness, wall_thickness, fn=50)` → solid outer body, profile mirrors the cavity offset outward by `wall_thickness`, spanning `z = [0, pot_height]`.
  - `module outer_body_custom(outer_top_d, outer_bottom_d, outer_height, pot_height, fn=50)` → solid outer body with an independent linear taper; asserts `outer_height >= pot_height`. When `outer_height > pot_height`, the extra height is added below the rim (the cavity is translated up by `outer_height - pot_height` by the caller in `planter.scad`, not inside this module).

- [ ] **Step 1: Write the failing test**

```openscad
// tests/test_body.scad
include <../modules/insert.scad>
include <../modules/body.scad>

// custom mode must reject an outer_height shorter than the required cavity height
ok = true;
// (assert() inside outer_body_custom is exercised via render, not directly testable
//  as a boolean here, so we test the underlying math path instead:)
pot_h = insert_cavity_height(130, 3, 5); // 138
assert(pot_h == 138);

// follow-insert outer radius at the rim must equal cavity radius + wall_thickness
r = cavity_radius_at(138, 150, 110, 130, 8, 0.3, 3, 138) + 2.4;
assert(r == 150/2 + 0.3 + 2.4, str("expected 77.7, got ", r));

cube(0.001);
```

- [ ] **Step 2: Run test to verify it fails**

```bash
openscad -o /tmp/test_out.csg tests/test_body.scad
```
Expected: FAIL — `body.scad` does not exist.

- [ ] **Step 3: Write `modules/body.scad`**

```openscad
// modules/body.scad
include <insert.scad>

module outer_body_follow(insert_top_d, insert_bottom_d, insert_height,
                          ledge_engagement_height, fit_clearance, body_clearance,
                          bottom_margin, floor_thickness, wall_thickness, fn=50) {
    pot_height = insert_cavity_height(insert_height, floor_thickness, bottom_margin);
    steps = 40;
    pts = concat(
        [[0, 0]],
        [ for (i = [0:steps])
            let(
                z  = pot_height * i / steps,
                zc = max(z, floor_thickness),
                r  = cavity_radius_at(zc, insert_top_d, insert_bottom_d, insert_height,
                                       ledge_engagement_height, fit_clearance,
                                       body_clearance, pot_height) + wall_thickness
            )
            [r, z]
        ],
        [[0, pot_height]]
    );
    rotate_extrude($fn=fn) polygon(pts);
}

module outer_body_custom(outer_top_d, outer_bottom_d, outer_height, pot_height, fn=50) {
    assert(outer_height >= pot_height,
        str("outer_height (", outer_height, ") must be >= required cavity height (", pot_height, ")"));
    pts = [
        [0, 0],
        [outer_bottom_d/2, 0],
        [outer_top_d/2, outer_height],
        [0, outer_height]
    ];
    rotate_extrude($fn=fn) polygon(pts);
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
openscad -o /tmp/test_out.csg tests/test_body.scad
echo "exit: $?"
```
Expected: `exit: 0`.

- [ ] **Step 5: Add and run an assertion-failure test for custom mode**

```openscad
// tests/test_body_custom_assert.scad
include <../modules/body.scad>
// outer_height (100) is deliberately shorter than pot_height (138) — must fail.
outer_body_custom(150, 110, 100, 138);
```

```bash
openscad -o /tmp/test_out.csg tests/test_body_custom_assert.scad
echo "exit: $?"
```
Expected: non-zero exit, stderr contains `ERROR: Assertion failed`.

- [ ] **Step 6: Commit**

```bash
git add modules/body.scad tests/test_body.scad tests/test_body_custom_assert.scad
git commit -m "Add outer body module with follow-insert and custom taper modes"
```

---

### Task 4: Base / drainage module

**Files:**
- Create: `modules/base.scad`
- Test: `tests/test_base.scad`

**Interfaces:**
- Consumes: nothing from earlier tasks (self-contained; caller passes plain numbers).
- Produces: `module drainage_holes(count, diameter, placement_radius, floor_thickness)` → union of cylinders cut through the floor, for use inside a `difference()` in `planter.scad`.

- [ ] **Step 1: Write the failing test**

```openscad
// tests/test_base.scad
include <../modules/base.scad>
// Smoke-test only: confirm the module exists and renders without error.
drainage_holes(6, 4, 30, 3);
```

- [ ] **Step 2: Run test to verify it fails**

```bash
openscad -o /tmp/test_out.csg tests/test_base.scad
```
Expected: FAIL — `base.scad` does not exist.

- [ ] **Step 3: Write `modules/base.scad`**

```openscad
// modules/base.scad
module drainage_holes(count, diameter, placement_radius, floor_thickness) {
    for (i = [0 : count - 1]) {
        angle = i * 360 / count;
        translate([placement_radius * cos(angle), placement_radius * sin(angle), -1])
            cylinder(h = floor_thickness + 2, d = diameter, $fn = 32);
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
openscad -o /tmp/test_out.csg tests/test_base.scad
echo "exit: $?"
```
Expected: `exit: 0`.

- [ ] **Step 5: Commit**

```bash
git add modules/base.scad tests/test_base.scad
git commit -m "Add drainage hole module for solid base"
```

---

### Task 5: Decoration module

**Files:**
- Create: `modules/decoration.scad`
- Test: `tests/test_decoration.scad`

**Interfaces:**
- Consumes: real BOSL2 texture name strings enumerated in Task 1, Step 4 (recorded in `tests/test_bosl2_texture_smoke.scad`'s header comment).
- Produces: `module decorated_solid(pattern_type, pattern_orientation, relief_mode, pattern_depth, pattern_repeat, r1, r2, height, wall_thickness, fn=50)` — a solid cylinder/cone (`r1` at bottom, `r2` at top) with the requested surface texture, or a plain `cylinder()` when `pattern_type == "none"`. Callers `difference()` this against the cavity, same as they would `outer_body_follow`/`outer_body_custom` — but note this module replaces those for the *decorated* case (`planter.scad` in Task 6 chooses between plain body modules and this one).

- [ ] **Step 1: Write the failing test**

```openscad
// tests/test_decoration.scad
include <../modules/decoration.scad>

// "none" must produce plain geometry without needing BOSL2 at all.
decorated_solid("none", "vertical", "raised", 1, 8, 50, 75, 100, 3);
```

- [ ] **Step 2: Run test to verify it fails**

```bash
openscad -o /tmp/test_out.csg tests/test_decoration.scad
```
Expected: FAIL — `decoration.scad` does not exist.

- [ ] **Step 3: Write `modules/decoration.scad`**

Use the exact texture name strings found in Task 1 Step 4 in place of `"<RIDGE_TEXTURE>"` / `"<GEOMETRIC_TEXTURE>"` below before committing this file — do not leave the placeholder names in the committed version.

```openscad
// modules/decoration.scad
include <../lib/BOSL2/std.scad>

function _decoration_texture(pattern_type, pattern_orientation) =
    pattern_type == "ridges"    ? "<RIDGE_TEXTURE>" :
    pattern_type == "geometric" ? "<GEOMETRIC_TEXTURE>" :
    undef;

module decorated_solid(pattern_type, pattern_orientation, relief_mode, pattern_depth,
                        pattern_repeat, r1, r2, height, wall_thickness, fn=50) {
    if (pattern_type == "none") {
        cylinder(h = height, r1 = r1, r2 = r2, $fn = fn);
    } else {
        assert(pattern_depth < wall_thickness * 0.7,
            str("pattern_depth (", pattern_depth, ") must be < 70% of wall_thickness (", wall_thickness, ")"));
        tex = _decoration_texture(pattern_type, pattern_orientation);
        rot = (pattern_orientation == "horizontal") ? 90 : 0;
        rotate([0, 0, 0])
        zrot(0)
        cyl(h = height, r1 = r1, r2 = r2, anchor = BOTTOM, $fn = fn,
            texture = tex,
            tex_size = [pattern_repeat, pattern_repeat],
            tex_depth = pattern_depth,
            tex_inset = (relief_mode == "etched"),
            tex_rot = rot);
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
openscad -o /tmp/test_out.csg tests/test_decoration.scad
echo "exit: $?"
```
Expected: `exit: 0`.

- [ ] **Step 5: Add a decorated-render test and check it visually**

```openscad
// tests/test_decoration_ridges.scad
include <../modules/decoration.scad>
decorated_solid("ridges", "vertical", "raised", 1.5, 12, 75, 60, 100, 4);
```

```bash
openscad -o /tmp/test_out.csg tests/test_decoration_ridges.scad && echo "exit: $?"
openscad -o /tmp/ridges.png --imgsize=800,800 tests/test_decoration_ridges.scad
```
Confirm `exit: 0` and open `/tmp/ridges.png` to visually confirm vertical raised ridges appear on the tapered surface. Repeat with `"geometric"` / `"etched"` to sanity-check the other combination before moving on.

- [ ] **Step 6: Add and run an assertion-failure test for depth-vs-wall**

```openscad
// tests/test_decoration_depth_assert.scad
include <../modules/decoration.scad>
// pattern_depth (3) is not < 70% of wall_thickness (3) — must fail.
decorated_solid("ridges", "vertical", "raised", 3, 12, 75, 60, 100, 3);
```

```bash
openscad -o /tmp/test_out.csg tests/test_decoration_depth_assert.scad
echo "exit: $?"
```
Expected: non-zero exit, `ERROR: Assertion failed`.

- [ ] **Step 7: Commit**

```bash
git add modules/decoration.scad tests/test_decoration.scad tests/test_decoration_ridges.scad tests/test_decoration_depth_assert.scad
git commit -m "Add decoration module with ridge/geometric texture support"
```

---

### Task 6: Top-level assembly (`planter.scad`)

**Files:**
- Create: `planter.scad`
- Test: `tests/test_planter_integration.scad`

**Interfaces:**
- Consumes:
  - `modules/insert.scad`: `insert_cavity_height()`, `insert_cavity()`
  - `modules/body.scad`: `outer_body_follow()`, `outer_body_custom()`
  - `modules/decoration.scad`: `decorated_solid()`
  - `modules/base.scad`: `drainage_holes()`
- Produces: the final renderable model at the top level of `planter.scad` (no new interface — this is the leaf of the dependency graph).

- [ ] **Step 1: Write the failing integration test**

```openscad
// tests/test_planter_integration.scad
// Renders planter.scad with the real 150/110/130 insert and default decoration,
// just to confirm the full assembly compiles without error.
insert_top_d = 150;
insert_bottom_d = 110;
insert_height = 130;
ledge_engagement_height = 8;
fit_clearance = 0.3;
body_clearance = 3;
bottom_margin = 5;
floor_thickness = 3;
wall_thickness = 3;
outer_mode = "follow"; // "follow" or "custom"
outer_top_d = 160;     // only used when outer_mode == "custom"
outer_bottom_d = 120;  // only used when outer_mode == "custom"
outer_height = 140;    // only used when outer_mode == "custom"
pattern_type = "ridges";       // "none" | "ridges" | "geometric"
pattern_orientation = "vertical"; // "vertical" | "horizontal"
relief_mode = "raised";           // "raised" | "etched"
pattern_depth = 1.5;
pattern_repeat = 16;
drainage_holes_enabled = true;
drainage_hole_count = 6;
drainage_hole_diameter = 4;
smoothness = 80;

include <../planter.scad>
```

- [ ] **Step 2: Run test to verify it fails**

```bash
openscad -o /tmp/test_out.csg tests/test_planter_integration.scad
```
Expected: FAIL — `planter.scad` does not exist.

- [ ] **Step 3: Write `planter.scad`**

```openscad
// planter.scad
include <lib/BOSL2/std.scad>
include <modules/insert.scad>
include <modules/body.scad>
include <modules/decoration.scad>
include <modules/base.scad>

/* [Insert Dimensions] */
insert_top_d = 150;     // top rim diameter (mm)
insert_bottom_d = 110;  // bottom diameter (mm)
insert_height = 130;    // insert height (mm)

/* [Fit] */
ledge_engagement_height = 8; // depth of the rim's tight-fit seat (mm)
fit_clearance = 0.3;         // radial clearance at the rim seat (mm)
body_clearance = 3;          // radial clearance around the tapered insert body (mm)
bottom_margin = 5;           // air gap below the insert's bottom (mm)

/* [Outer Shape] */
outer_mode = "follow"; // "follow" or "custom"
wall_thickness = 3;     // used in follow mode (mm)
outer_top_d = 160;      // used in custom mode (mm)
outer_bottom_d = 120;   // used in custom mode (mm)
outer_height = 140;     // used in custom mode (mm)

/* [Decoration] */
pattern_type = "ridges";          // "none", "ridges", "geometric"
pattern_orientation = "vertical";  // "vertical", "horizontal"
relief_mode = "raised";            // "raised", "etched"
pattern_depth = 1.5;    // mm
pattern_repeat = 16;    // tile count around circumference

/* [Base] */
floor_thickness = 3;              // mm
drainage_holes_enabled = false;    // add drainage holes to the solid floor
drainage_hole_count = 6;
drainage_hole_diameter = 4;

/* [Quality] */
smoothness = 80; // $fn used for all revolved geometry

assert(insert_bottom_d < insert_top_d,
    "insert_bottom_d must be smaller than insert_top_d (insert tapers inward)");
assert(wall_thickness > 0, "wall_thickness must be > 0");
assert(pattern_depth < wall_thickness * 0.7 || pattern_type == "none",
    "pattern_depth must be < 70% of wall_thickness");

pot_height = insert_cavity_height(insert_height, floor_thickness, bottom_margin);

module planter() {
    difference() {
        // outer body (plain or decorated) --------------------------------
        if (pattern_type == "none") {
            if (outer_mode == "custom") {
                outer_body_custom(outer_top_d, outer_bottom_d, outer_height, pot_height, fn=smoothness);
            } else {
                outer_body_follow(insert_top_d, insert_bottom_d, insert_height,
                    ledge_engagement_height, fit_clearance, body_clearance,
                    bottom_margin, floor_thickness, wall_thickness, fn=smoothness);
            }
        } else {
            // decorated_solid needs simple r1/r2/height, so decoration is only
            // offered as a straight-taper cone regardless of outer_mode; this
            // matches the "follow" profile's endpoints when outer_mode=="follow".
            r_top = (outer_mode == "custom") ? outer_top_d/2
                    : cavity_radius_at(pot_height, insert_top_d, insert_bottom_d, insert_height,
                        ledge_engagement_height, fit_clearance, body_clearance, pot_height) + wall_thickness;
            r_bottom = (outer_mode == "custom") ? outer_bottom_d/2
                    : cavity_radius_at(floor_thickness, insert_top_d, insert_bottom_d, insert_height,
                        ledge_engagement_height, fit_clearance, body_clearance, pot_height) + wall_thickness;
            h = (outer_mode == "custom") ? outer_height : pot_height;
            decorated_solid(pattern_type, pattern_orientation, relief_mode, pattern_depth,
                pattern_repeat, r_bottom, r_top, h, wall_thickness, fn=smoothness);
        }

        // cavity -----------------------------------------------------------
        z_offset = (outer_mode == "custom") ? (outer_height - pot_height) : 0;
        translate([0, 0, z_offset])
            insert_cavity(insert_top_d, insert_bottom_d, insert_height,
                ledge_engagement_height, fit_clearance, body_clearance,
                bottom_margin, floor_thickness, fn=smoothness);

        // drainage -----------------------------------------------------------
        if (drainage_holes_enabled) {
            r_bottom_cavity = cavity_radius_at(floor_thickness, insert_top_d, insert_bottom_d,
                insert_height, ledge_engagement_height, fit_clearance, body_clearance, pot_height);
            drainage_holes(drainage_hole_count, drainage_hole_diameter,
                r_bottom_cavity * 0.6, floor_thickness);
        }
    }
}

planter();
```

- [ ] **Step 4: Run test to verify it passes**

```bash
openscad -o /tmp/test_out.csg tests/test_planter_integration.scad
echo "exit: $?"
```
Expected: `exit: 0`, no `ERROR`.

- [ ] **Step 5: Render a preview image with the real insert dimensions**

```bash
openscad -o /tmp/planter_default.png --imgsize=1000,1000 tests/test_planter_integration.scad
```
Open the PNG and confirm: a tapered vertical-ridged pot with a visible internal step near the top and a solid floor with 6 drainage holes.

- [ ] **Step 6: Commit**

```bash
git add planter.scad tests/test_planter_integration.scad
git commit -m "Add top-level planter.scad assembling insert, body, decoration, and base"
```

---

### Task 7: README and documentation

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: nothing (documentation only).

- [ ] **Step 1: Write `README.md`**

Include these sections:
1. **What this is** — one paragraph, links to nothing external, describes the parametric planter generator.
2. **Requirements** — OpenSCAD 2019.05+ (BOSL2 is vendored, no separate install needed); Customizer panel recommended (View → Show Customizer).
3. **Measuring your insert** — explains `insert_top_d` (widest point / rim diameter), `insert_bottom_d`, `insert_height`, with a note that these are the *only* required measurements to reprint for a different insert.
4. **Parameter reference** — one line per Customizer parameter (name, meaning, default), grouped by the same `[Section]` headings used in `planter.scad`.
5. **Preset: this project's insert** — the exact values used throughout this plan (`insert_top_d=150, insert_bottom_d=110, insert_height=130`), presented as a copy-pasteable settings block.
6. **Decoration examples** — a short table: `pattern_type` × `relief_mode` combinations and what each looks like in one sentence.
7. **License** — link to `LICENSE`.

- [ ] **Step 2: Sanity-check the README's parameter reference against `planter.scad`**

```bash
grep -E '^\w+ = ' planter.scad
```
Compare the output to the README's parameter table — every variable listed here must appear in the README table (and vice versa). Fix any mismatch.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Add README with measuring guide and parameter reference"
```

---

### Task 8: Final validation pass

**Files:**
- None created; verification only.

- [ ] **Step 1: Render all four decoration combinations for the real insert**

```bash
for pt in ridges geometric; do
  for rm in raised etched; do
    sed -e "s/^pattern_type = .*/pattern_type = \"$pt\";/" \
        -e "s/^relief_mode = .*/relief_mode = \"$rm\";/" \
        tests/test_planter_integration.scad > /tmp/variant_${pt}_${rm}.scad
    openscad -o /tmp/variant_${pt}_${rm}.png --imgsize=800,800 /tmp/variant_${pt}_${rm}.scad
    echo "$pt/$rm exit: $?"
  done
done
```
Expected: all four `exit: 0`. Open each PNG and confirm the pattern/relief combination looks correct (raised = protrudes outward, etched = recessed inward).

- [ ] **Step 2: Render the custom outer-mode path**

```bash
sed -e 's/^outer_mode = .*/outer_mode = "custom";/' tests/test_planter_integration.scad > /tmp/variant_custom.scad
openscad -o /tmp/variant_custom.png --imgsize=800,800 /tmp/variant_custom.scad
echo "exit: $?"
```
Expected: `exit: 0`. Confirm visually the outer silhouette differs from follow-mode while the insert still visibly seats correctly (step near the top).

- [ ] **Step 3: Re-run every test file to confirm nothing regressed**

```bash
for f in tests/test_insert.scad tests/test_body.scad tests/test_base.scad \
         tests/test_decoration.scad tests/test_planter_integration.scad; do
  openscad -o /tmp/final_check.csg "$f"
  echo "$f exit: $?"
done
```
Expected: every line reads `exit: 0`.

- [ ] **Step 4: Report to Barrett**

Summarize: what renders correctly, any BOSL2 texture names actually used (from Task 1 Step 4), and that GitHub repo creation/push is the next step pending his go-ahead (per the spec's GitHub section).
