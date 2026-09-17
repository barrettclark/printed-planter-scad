# Square-Tile Aspect Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Post-implementation note:** this plan is committed as a historical record of the design process (matching this repo's convention for prior plans, e.g. `2026-09-12-parametric-planter.md` — plans are not rewritten or checkbox-updated after the fact). The final whole-branch review found a real gap this plan's Task 1 didn't anticipate: `_square_tile_vertical_reps()`'s sqrt(3) correction needs to apply to a different axis depending on `pattern_orientation`, because BOSL2 rotates the texture tile's own content for `pattern_orientation="horizontal"`. The function's shipped signature is `_square_tile_vertical_reps(pattern_type, pattern_orientation, pattern_repeat, r1, r2, height)` — one more parameter than Task 1's interface/code below shows — and the shipped formula's `aspect_correction` is `sqrt(3)` for vertical orientation but `1/sqrt(3)` for horizontal, not the one-way `sqrt(3)` this plan documents. See `modules/decoration.scad` for the actual shipped implementation and its inline reasoning, not this file, if the two ever disagree.

**Goal:** Make every shape-based decoration pattern (everything except `"ridges"` and `"bricks"`, which are intentionally directional/rectangular) render with tiles that are the same dimension top-to-bottom as left-to-right on the actual printed pot, instead of the current ~2.8-3.75x horizontal stretch.

**Architecture:** `decorated_solid()` (`modules/decoration.scad`) currently hardcodes `tex_reps = [pattern_repeat, pattern_repeat]` for every pattern — the same repeat count around the circumference as up the height, regardless of the pot's actual circumference/height ratio (~440mm / ~138mm at defaults, a ~3.2x mismatch). Fix: compute the vertical repeat count from the real geometry (`r1`, `r2`, `height`, already passed into `decorated_solid()`) so each tile comes out approximately square, with three BOSL2 catalog patterns (`"cubes"`, `"hex_grid"`, `"tri_grid"`) needing an additional `sqrt(3)` correction per BOSL2's own documented aspect requirements (`lib/BOSL2/skin.scad` texture catalog comments) for their tiles to be true isometric cubes / regular hexagons / equilateral triangles rather than merely square. Because the wall is a cone, not a cylinder, tiles can only be made square *on average* (at the mean radius) — a smaller residual taper distortion remains and must be disclosed honestly, same as the existing docs already do for the current (much larger) distortion.

**Tech Stack:** OpenSCAD, BOSL2.

**Spec:** This plan's own Architecture section above is the spec — derived from TODO.md's "Fix tile aspect-ratio distortion on the actual pot" and "BOSL2 aspect-scale corrections not applied for some patterns" entries, and confirmed against `lib/BOSL2/skin.scad`'s texture catalog documentation (grep `sqrt(3)` in that file) and the `_tile_from_islands()` / `_UNIT_TILE` convention already used for the four custom VNF tiles (confirmed unit-square, no intrinsic correction needed).

## Global Constraints

- Scope is exactly the 11 shape-based patterns: `"diamonds"`, `"hex_grid"`, `"pyramids"`, `"checkers"`, `"dots"`, `"cubes"`, `"tri_grid"`, `"teardrop"`, `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"`. `"none"` (no texture) and `"ridges"`/`"bricks"` (intentionally directional/rectangular) are explicitly OUT of scope and must keep their current `tex_reps = [pattern_repeat, pattern_repeat]` behavior unchanged — confirmed with the project owner, do not expand or narrow this list.
- No new Customizer field. `pattern_repeat` remains the only user-facing tiling control (horizontal/circumferential count); the vertical count becomes an internal derived value. Do not add a manual override — YAGNI, not requested.
- `"cubes"`, `"hex_grid"`, `"tri_grid"` need their vertical repeat count reduced by an additional factor of `sqrt(3)` relative to the plain square-tile formula, per BOSL2's own documentation (`lib/BOSL2/skin.scad` lines ~3735, ~3878-3888, ~3938-3944, ~3998-4004: "this texture needs to be scaled in vertically by sqrt(3) to have its correct aspect" for cubes; "If the texture is scaled in the Y direction by sqrt(3) then the groove is uniform on all six/three sides" for hex_grid/tri_grid).
- Vertical repeat count formula (verified against `_tile_from_islands()`'s unit-square convention and BOSL2's documented sqrt(3) requirement):
  - `avg_circumference = PI * (r1 + r2)` (r1 = bottom radius, r2 = top radius — averaging radii then computing circumference, i.e. `pi * d_avg`)
  - Plain square-tile patterns: `vertical_reps = max(1, round(pattern_repeat * height / avg_circumference))`
  - sqrt(3)-corrected patterns (`"cubes"`, `"hex_grid"`, `"tri_grid"`): `vertical_reps = max(1, round(pattern_repeat * height / (avg_circumference * sqrt(3))))`
  - Excluded patterns (`"none"`, `"ridges"`, `"bricks"`): `vertical_reps = pattern_repeat` (unchanged)
- All 14 pattern_types x 2 relief modes must still pass the full local CI-equivalent suite (`.github/workflows/test.yml`'s `scad-tests` job, extracted and run locally the same way prior PRs in this repo verified it — see `git log` on `docs/images/render.sh` commits for the exact extraction technique using `python3 -c "import yaml..."`) before any task in this plan is considered done. This includes the CGAL-fragile-pattern safety measurements for `"tumbling_cubes"`, `"intertwine"`, `"islamic_star"` — changing vertical tile counts changes tile geometry, so previously-measured "safe" `pattern_repeat`/`smoothness` combinations in `.github/workflows/test.yml` and README.md may no longer be accurate and must be re-measured, not assumed.
- Work happens in an isolated git worktree per this repo's established convention (see `superpowers:using-git-worktrees`); branch name should describe the fix (e.g. `square-tile-aspect`).

---

### Task 1: Implement the aspect-corrected vertical tile count

**Files:**
- Modify: `modules/decoration.scad` (add a helper function; change `decorated_solid()`'s `tex_reps` line)
- Test: `tests/test_decoration_tile_aspect.scad` (new file)

**Interfaces:**
- Produces: `_square_tile_vertical_reps(pattern_type, pattern_repeat, r1, r2, height)` — a function returning an integer >= 1, callable from `decorated_solid()` and from tests.
- Consumes: nothing new from other tasks (this is the first task).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_decoration_tile_aspect.scad`:

```openscad
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `openscad -o /tmp/test.csg tests/test_decoration_tile_aspect.scad`
Expected: FAIL — `_square_tile_vertical_reps` is not yet defined (ERROR: Unknown function).

- [ ] **Step 3: Implement `_square_tile_vertical_reps()` and wire it into `decorated_solid()`**

In `modules/decoration.scad`, add this function near the top (after `PATTERN_TYPES`, before the tile-builder functions):

```openscad
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

// decorated_solid() passes the same pattern_repeat for both the horizontal
// (circumferential) and vertical tex_reps, which only produces square tiles
// by coincidence: the wall's average circumference (~440mm at defaults) is
// nothing like its height (~138mm). This derives the vertical repeat count
// from the real geometry instead, so tiles come out approximately square
// (only approximately, since the wall is a cone: BOSL2 scales each texture
// strip to the LOCAL radius, so a single vertical_reps can only be exact at
// one radius -- see README.md's "Decoration" section for the residual
// taper effect this leaves).
//
// The four custom VNF tiles (teardrop, tumbling_cubes, intertwine,
// islamic_star) are built on _UNIT_TILE, confirmed elsewhere in this file
// to be exactly the unit square with no intrinsic distortion, so they use
// the plain formula like every BOSL2 catalog texture without a documented
// sqrt(3)/sqrt(2) requirement.
function _square_tile_vertical_reps(pattern_type, pattern_repeat, r1, r2, height) =
    in_list(pattern_type, _ASPECT_EXCLUDED_PATTERNS) ? pattern_repeat :
    let(
        avg_circumference = PI * (r1 + r2),
        aspect_correction = in_list(pattern_type, _ASPECT_SQRT3_PATTERNS) ? sqrt(3) : 1
    )
    max(1, round(pattern_repeat * height / (avg_circumference * aspect_correction)));
```

Then in `decorated_solid()`, change:

```openscad
            tex_reps = [pattern_repeat, pattern_repeat],
```

to:

```openscad
            tex_reps = [pattern_repeat, _square_tile_vertical_reps(pattern_type, pattern_repeat, r1, r2, height)],
```

- [ ] **Step 4: Run test to verify it passes**

Run: `openscad -o /tmp/test.csg tests/test_decoration_tile_aspect.scad`
Expected: PASS (no ERROR in output, exit 0).

- [ ] **Step 5: Run the existing decoration/pattern test files to confirm nothing broke**

Run each of these and confirm clean (no ERROR, exit 0) — these exercise every pattern_type/relief_mode combination and will now render with different (corrected) tile counts, so this step catches any pattern whose VNF construction breaks at the new vertical_reps values before the slower full-assembly checks in Task 2:

```bash
openscad -o /tmp/t1.csg tests/test_decoration.scad
openscad -o /tmp/t2.csg tests/test_decoration_ridges.scad
openscad -o /tmp/t3.csg tests/test_decoration_pattern_types.scad
openscad -o /tmp/t4.csg tests/test_decoration_etched_groove.scad
for f in teardrop tumbling_cubes intertwine islamic_star; do
    openscad -o /tmp/t_$f.stl tests/test_decoration_$f.scad
done
```

If any of these fail, fix `_square_tile_vertical_reps()` or the affected tile builder before moving on — do not defer to Task 2.

- [ ] **Step 6: Commit**

```bash
git add modules/decoration.scad tests/test_decoration_tile_aspect.scad
git commit -m "Derive the vertical tile repeat count from real geometry so shape-based patterns render square instead of stretched"
```

---

### Task 2: Re-verify CGAL-fragile pattern safety and update CI/README's documented safe combinations

**Files:**
- Modify: `.github/workflows/test.yml` (the `run_assembly_combo` calls and reduced-value comments for `tumbling_cubes`/`intertwine`/`islamic_star`)
- Modify: `README.md` (the "Note on the interlocking patterns and CGAL" section, lines ~141-145)

**Interfaces:**
- Consumes: Task 1's `_square_tile_vertical_reps()` (already merged into `decorated_solid()`), no new interfaces of its own.
- Produces: nothing new; this task only re-validates and re-documents existing behavior.

- [ ] **Step 1: Extract and run the full CI script locally**

```bash
python3 -c "
import yaml
with open('.github/workflows/test.yml') as f:
    d = yaml.safe_load(f)
script = d['jobs']['scad-tests']['steps'][-1]['run']
with open('/tmp/run_ci.sh', 'w') as f:
    f.write('#!/usr/bin/env bash\n')
    f.write(script)
"
bash /tmp/run_ci.sh > /tmp/ci_local.log 2>&1; echo "EXIT:$?"
grep -c FAIL /tmp/ci_local.log
```

Expected: this MAY fail on the `tumbling_cubes`/`islamic_star` default-settings checks near the end (the ones pinned at `pattern_repeat=16`, `smoothness=80`) or on the reduced-value loop, since vertical tile counts changed. Read `/tmp/ci_local.log` around any `FAIL:` line to see which combination broke and whether it's a CGAL abort (look for `CGAL error` or `ERROR` in the surrounding output) or something else.

- [ ] **Step 2: Re-measure safe pattern_repeat/smoothness combinations for the three CGAL-fragile patterns**

If Step 1 found breakage, re-run the specific failing combination(s) directly to confirm the CGAL abort:

```bash
openscad -D 'pattern_type="tumbling_cubes"' -D 'relief_mode="etched"' -D 'pattern_repeat=16' -D 'smoothness=80' -o /tmp/probe.stl tests/test_planter_integration.scad 2>&1 | grep -i "CGAL error\|ERROR"
```

If it aborts, search nearby `pattern_repeat`/`smoothness` values (following the existing methodology documented in README.md lines 141-145 and `.github/workflows/test.yml` lines ~195-203: vary both jointly, not just one) until a clean combination is found for the shipped defaults. If the *defaults themselves* (`pattern_repeat=16`, `smoothness=80`) can no longer be made clean for one of the three patterns, stop and flag this to the project owner rather than silently changing `planter.scad`'s shipped default `pattern_repeat`/`smoothness` — that is a bigger decision than this task covers.

- [ ] **Step 3: Update `.github/workflows/test.yml` and README.md with whatever the re-measurement found**

If the previously-documented safe values (reduced-check values of 4/6, and the default-settings pins) are still clean, update only the comments explaining *why* those specific numbers were chosen if the underlying tile geometry changed enough to make the old rationale stale. If different values are now needed, update:
- The `run_assembly_combo` calls for `"tumbling_cubes"`/`"intertwine"`/`"islamic_star"` in `.github/workflows/test.yml`
- README.md's "Note on the interlocking patterns and CGAL" section (the exact numbers quoted there, e.g. "fails at `pattern_repeat` 4 and 5 but is fine at 3 and 6")

Re-run the full local CI script (Step 1's command) after any change until it passes clean with zero `FAIL` lines.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/test.yml README.md
git commit -m "Re-verify CGAL-fragile pattern safety after the square-tile fix changed tile counts"
```

(If Step 1 found no breakage at all and no documentation needed correction, skip the commit — note in the task report that re-verification found no drift, rather than committing an empty/no-op change.)

---

### Task 3: Regenerate the gallery, update aspect-ratio documentation, and close out the TODO items

**Files:**
- Modify: `docs/images/render.sh` (comment at line ~131 referencing the old "~2.8-3.75x" number)
- Modify: `docs/gallery.md` (lines ~40, ~232, ~243-244, ~255 — the aspect-ratio disclosure and any per-pattern prose that describes the old stretched look)
- Modify: `README.md` (lines 81, 149, 151 — `pattern_repeat`'s description and the aspect-ratio note)
- Modify: `TODO.md` (check off or remove the two now-fixed items: "Fix tile aspect-ratio distortion on the actual pot" and "BOSL2 aspect-scale corrections not applied for some patterns")
- Regenerate: every file under `docs/images/*.png`

**Interfaces:**
- Consumes: Task 1 + Task 2's final, CI-verified state of `decorated_solid()` and any changed `pattern_repeat`/`smoothness` safe values.

- [ ] **Step 1: Regenerate every image**

```bash
./docs/images/render.sh
```

This takes ~10-15 minutes. Confirm it ends with "All renders complete and CGAL-clean" and `git status` shows only `docs/images/*.png` changes (no unexpected deletions — see `docs/images/render.sh`'s own header comments for the lock/staging mechanism if anything looks wrong).

- [ ] **Step 2: Measure the actual residual aspect ratio for the disclosure text**

The cone means tiles still aren't *exactly* square at every height (only on average, at the mean radius) — the disclosure must state the real remaining range, not claim perfection. Compute it the same way the current ~2.8-3.75x figures were derived (see README.md line 151's own math for the pattern): at the shipped defaults (`r1≈61`, `r2≈82.3`, `height=138`, `pattern_repeat=16`), work out the new `vertical_reps` via `_square_tile_vertical_reps()`, then compute tile width at the bottom radius and top radius against the resulting fixed tile height, and express the new (much smaller) residual range the same way the old ~2.8-3.75x range was expressed.

- [ ] **Step 3: Rewrite the aspect-ratio disclosure**

Update README.md line 151 and docs/gallery.md's corresponding sections (lines ~40, ~232, ~243-244) to describe the fix and the new (small residual) range from Step 2, instead of the old ~2.8-3.75x figures. State plainly that this was fixed (with a pointer to `_square_tile_vertical_reps()` in `modules/decoration.scad`), not just re-measured — readers of the old text were told this was a known limitation; say it no longer is one (beyond the small residual cone-taper effect).

Update docs/gallery.md line 255's prose about `hex_grid` "clearly distorted" if that specific example image no longer shows meaningful distortion after Step 1's regeneration — verify by looking at the actual regenerated image before changing the prose, don't assume.

Update README.md lines 81 and 149 (`pattern_repeat`'s table description and the "Adjust `pattern_orientation`..." paragraph) to describe the new behavior: `pattern_repeat` sets the horizontal/circumferential count directly; the vertical count is now derived automatically to keep tiles approximately square, rather than being set to the same value.

Update `docs/images/render.sh`'s comment at line ~131 to match.

- [ ] **Step 4: Update TODO.md**

Remove (or check off, matching this file's existing convention — check the file for how completed items are marked, if any are) the two entries: "Fix tile aspect-ratio distortion on the actual pot" and "BOSL2 aspect-scale corrections not applied for some patterns". Both are fully addressed by Task 1.

- [ ] **Step 5: Visual sanity check**

Look at the regenerated `docs/images/pattern-islamic_star-raised.png`, `docs/images/pattern-intertwine-raised.png`, `docs/images/pattern-cubes-raised.png`, and `docs/images/pattern-hex_grid-raised.png` directly (the four patterns explicitly discussed in this plan's motivation) and confirm each looks visually square/regular now, not stretched. This is the actual acceptance criterion the project owner cares about — the numeric tests in Task 1 prove the formula is implemented correctly, but only looking at the images proves it looks right.

- [ ] **Step 6: Commit**

```bash
git add docs/images README.md docs/gallery.md docs/images/render.sh TODO.md
git commit -m "Regenerate gallery and update docs for the square-tile aspect fix"
```

---

## Self-Review Notes

- Spec coverage: Task 1 covers the core fix and its correctness (unit tests). Task 2 covers the CI-safety re-verification the Global Constraints require. Task 3 covers the documentation/gallery/TODO cleanup the fix's visible surface requires. No gaps identified against the Architecture section.
- No placeholders: Task 1's code is complete and exact, derived from grepped BOSL2 documentation and the existing `_tile_from_islands()`/`_UNIT_TILE` convention, not a guess. Tasks 2 and 3 are necessarily investigative (their exact numbers depend on Task 1's real output), so their steps specify the *procedure* and *acceptance criterion* precisely rather than pre-committing to numbers that would be fabricated if written now.
- Type consistency: `_square_tile_vertical_reps()`'s signature (`pattern_type, pattern_repeat, r1, r2, height`) matches its one call site in `decorated_solid()`, which already has all five values in scope at the `tex_reps` line.
