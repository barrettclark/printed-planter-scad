# Relief Mode Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework `relief_mode == "etched"` for the 8 Phase-1 custom-tile patterns (`tumbling_cubes`, `islamic_star`, `tetrakis_square`, `kisrhombille`, `triakis_triangular`, `rhombille`, `cairo_pentagonal`, `floret_pentagonal`) into a true two-tier outline engrave (flat wall, a primary groove around each motif's outer silhouette, a thinner/shallower secondary groove on internal facet seams), and add a new third `relief_mode` value, `"alternating"`, that renders some copies of a motif proud of the wall and others sunk below it in one render, for the same 8 patterns. `"raised"` does not change for any pattern. `intertwine`, `teardrop`, and `deltoidal_trihexagonal` are explicitly out of scope (three different reasons -- see Global Constraints).

**Architecture:** Two new shared tile-assembler functions live in `modules/decoration.scad` next to the existing `_tile_from_islands()`: `_tile_outline_from_islands(motif_groups, outer_gap, inner_gap)` (etched) builds a full planar edge-adjacency arrangement over each pattern's *original, pre-shrink* sub-regions and classifies every internal shared edge as a primary (different-motif) or secondary (same-motif) groove; `_tile_alternating_from_islands(islands, high_group)` (alternating) reuses `_tile_from_islands()` with every island forced to height `0` or `1` by an `alt_key` tag and a real `ground_z = 0.5` nominal-wall plane. Both require `_tile_from_islands()` and `_tile_walls()` to gain a `ground_z` parameter (default `0`, so every existing raised-mode caller is unaffected) with `_tile_walls()` getting a real conditional on the sign of `z - ground_z`, not just a substitution -- a "low" island's wall would otherwise wind backwards. Each of the 8 patterns' islands-building loops is extended to also expose its *original* (un-shrunk) sub-regions grouped by motif (`motif_groups`, for the outline builder) and a per-island `group_id`/`alt_key` pair (for the alternating builder) -- two genuinely different tags, only coinciding for 6 of the 8 patterns (the "kis" family diverges; see Global Constraints).

**Tech Stack:** OpenSCAD 2021.01, BOSL2 (`lib/BOSL2/std.scad`), this repo's existing `modules/decoration.scad` VNF-tile infrastructure (`_tile_from_islands()`, `_tile_walls()`, `_tile_on_edge()`, `_tile_quantize()`/`_tile_q()`, `_UNIT_TILE`, `_kis_shrunk_fan()`).

**Spec:** `docs/superpowers/specs/2026-09-20-relief-mode-redesign-design.md` -- this plan implements that spec in full for Phase 1; every correction in its "Design" section (Correction 1, 1b, 2) is load-bearing and is carried forward verbatim below, not re-derived or simplified.

## Global Constraints

- `RELIEF_MODES = ["raised", "etched", "alternating"]` -- a new, separate list from `PATTERN_TYPES` (pattern *names*, not modes). `decorated_solid()` asserts `in_list(relief_mode, RELIEF_MODES)` the same way it already asserts `pattern_type`.
- The 8 Phase-1 `"alternating"`-supporting patterns, exactly: `tumbling_cubes`, `islamic_star`, `tetrakis_square`, `kisrhombille`, `triakis_triangular`, `rhombille`, `cairo_pentagonal`, `floret_pentagonal`. If `relief_mode == "alternating"` and `pattern_type` is not one of these 8, `decorated_solid()` must assert with a message naming which `pattern_type`s currently support `"alternating"` -- never silently fall back to `"raised"`.
- `intertwine`'s `"etched"` mode is **unchanged**, not migrated to `_tile_outline_from_islands()` at all: `_intertwine_tile()` unions every overlapping ring strand into one island before it ever reaches `_tile_from_islands()` (`modules/decoration.scad:665-678` as of this plan), so there is no non-overlapping planar arrangement for the outline builder to classify, even for a single group -- the existing generic `_tile_from_islands()` + `tex_inset` mechanism already grooves around that one island's own outer boundary, which is exactly the whole-silhouette result this pattern needs. `intertwine` does not support `"alternating"` either: the same union that erases per-ring identity also erases the tagging `alt_key` would need, and splitting the strands back apart would reintroduce the overlapping-strand VNF-closure problem that union was written to avoid. Do not touch `_intertwine_tile()` in this plan.
- `teardrop` has no islands list at all (`_teardrop_tile()` is a hand-rolled outline, not built via `_tile_from_islands()`) and supports neither new mode in Phase 1. Do not touch `_teardrop_tile()` in this plan.
- `deltoidal_trihexagonal` has an islands list (`_deltoidal_trihexagonal_tile()`) but no `relief_mode` parameter and no per-island height variation -- it merged into `main` after this spec was first drafted and has no mode split to rework or preserve. Do not touch `_deltoidal_trihexagonal_tile()`, and do not add it to `RELIEF_MODES`-alternation support, in this plan.
- `dots`, `cubes`, `checkers`, `bricks` are out of scope entirely (Phase 2, a separate future plan) -- do not attempt to convert their BOSL2-native heightfields to islands-based tiles here.
- The alternating builder's islands format is `[[region, height, group_id, alt_key], ...]` -- **two extra fields** versus `_tile_from_islands()`'s plain `[region, height]`. `group_id` identifies which physical motif an island belongs to (used only by the outline builder, to classify same-motif vs. different-motif edges); `alt_key` identifies which high/low alternation bucket an island falls into (used only by `_tile_alternating_from_islands()`, via `high_group`, a set of `alt_key` values that render high). These fields coincide (`alt_key = group_id`) for `tumbling_cubes`, `rhombille`, `cairo_pentagonal`, `floret_pentagonal`, and `islamic_star`; they genuinely differ for the "kis" family (`tetrakis_square`, `kisrhombille`, `triakis_triangular`), where `group_id` must stay unique per fan (required for the outline builder's edge classification to work at all) while `alt_key` is the fan-triangle's own local index within its fan.
- `_tile_from_islands(islands, ground_z = 0)` and `_tile_walls(path, z, ground_z = 0)` both need the new `ground_z` parameter, defaulting to `0` so every existing raised-mode call site is unaffected. `_tile_walls()` needs a real conditional on the sign of `z - ground_z` (build the quad as `[[a,ground_z],[b,ground_z],[b,z],[a,z]]` when `z >= ground_z`, or with the low/high pair swapped, `[[a,z],[b,z],[b,ground_z],[a,ground_z]]`, when `z < ground_z`) -- a plain parameter substitution alone produces a wall with a flipped face normal for any "low" island (`z = 0 < ground_z = 0.5`), which is a real, silent geometry bug (not always visible at the VNF level, only downstream in CGAL's manifoldness check or a visibly inverted face).
- `_tile_alternating_from_islands(islands, high_group, ground_z = 0.5)` is a thin wrapper: `_tile_from_islands([for (il = islands) [il[0], in_list(il[3], high_group) ? 1 : 0]], ground_z)`. It ignores `il[1]` (the stored raw height) and `il[2]` (`group_id`) entirely -- only the region (`il[0]`) and `alt_key` (`il[3]`) matter to this builder.
- `_tile_outline_from_islands(motif_groups, outer_gap, inner_gap)` builds its edge-adjacency classification with **sort-based matching, not a nested double loop**. Verified directly (Task 1's own research pass): an `O(n^2)` nested-loop match over kisrhombille's own ~900-edge motif-group arrangement did not finish within a 180-second timeout; the sort-based approach below (`sort()` the `[key, edge_index]` pairs, then scan for adjacent-equal-key runs with a small bounded lookahead) computed the identical, independently-cross-checked match counts (129 primary pairs, 300 secondary pairs, 0 bugs) in about 4 seconds. Do not implement the outline builder's matching step as a double loop.
- **A second, separate performance risk exists downstream of matching: BOSL2's region `union()` function itself.** Verified directly: with the matching step fixed (sort-based, fast), building kisrhombille's 129-strip primary region and 300-strip secondary region via `union(primary_regions)`/`union(secondary_regions)` (each a flat list of single-quad regions, one per matched edge) took over two minutes combined and had not finished when this plan's own research pass killed it to stay within its own time budget. This is not a bug in the matching logic -- it is BOSL2's `union()` function itself, whose own doc comment (`lib/BOSL2/regions.scad:1230`) states plainly: "This function is much slower than the native union module acting on geometry... only use it when you need a point list for further processing" -- and its implementation is a **sequential fold** (union region 1 with region 2, union that result with region 3, and so on), so the accumulated region's own complexity grows at every step, not a single batch operation. `_tile_outline_from_islands()` genuinely needs the point-list (region) result, not rendered geometry, to keep composing with `_tile_from_islands()` downstream, so switching to the native 3D/2D `union()` *module* is not a drop-in option. Task 1 must budget real time to address this -- see Task 1 Step 4's own "if plain union is too slow" fallback (a batched/hierarchical union, unioning small groups first and then unioning the much-shorter list of group results) and Step 12's build-timing requirement. This plan's own author could not fully re-verify the batched fallback against the exact slow real-world input (kisrhombille's own overlapping, vertex-sharing strips) within this plan-writing pass's own time budget -- a synthetic stand-in test of comparable size (129/300 disjoint quads, not sharing any vertices) unioned in well under a minute, which is NOT the same shape of input as the real strips (which deliberately overlap at shared vertices, per `_outline_edge_strip()`'s own corner-coverage extension) and so does not prove the real case is fast, only that raw item count alone isn't automatically the bottleneck. Task 1's implementer must measure the real thing, not trust this plan's synthetic proxy.
- Every `motif_groups` list fed to `_tile_outline_from_islands()` must be built over a **3x3 "supertile"** of the pattern's own placement lattice (offsets `(dx, dy)` for `dx, dy` in `{-1, 0, 1}`, positions deduplicated via `_tile_q()`), not just the placements that happen to overlap the unit tile. This is Task 1's own load-bearing finding, not in the spec verbatim: feeding only the tile-covering placements list (e.g. `_CP_PLACEMENTS`'s 8 entries) leaves some of a motif's own internal edges without their true neighbour (that neighbour's sub-region lies just past the tile boundary, in a placement the covering list never needed), which the edge classifier cannot tell apart from a real gap/bug without seeing it. Verified computationally per pattern (Task 1's research): `islamic_star`, `kisrhombille`, `cairo_pentagonal`, `floret_pentagonal`, and the `tumbling_cubes`/`rhombille` 2-group split all resolve to exactly 0 unmatched-and-relevant edges at 3x3-supertile scale; `cairo_pentagonal` specifically does **not** resolve with just its own 4 covering hubs at full pinwheel membership (6 genuine bugs remained) -- it needs neighbour hubs the 3x3 supertile supplies.
- An unmatched edge is only a bug if it is also **relevant**: `_outline_edge_relevant(a, b)` (its axis-aligned bounding box overlaps `[0,1]x[0,1]` with a small epsilon) must be true. An unmatched-and-irrelevant edge (its true neighbour lives further out than the 3x3 supertile reached) contributes nothing to the final tile once clipped to `_UNIT_TILE`, so it is silently skipped, not asserted on.
- CGAL-fragility disclosure convention (established by `intertwine`/`cairo_pentagonal`/`floret_pentagonal`/`deltoidal_trihexagonal`'s own plans): local-macOS-clean is necessary but never sufficient to claim CI-clean. Every CGAL sweep result this plan or its tasks record must be labeled with the platform it was measured on, and any CI-pinned value must eventually be confirmed against a real GitHub Actions Ubuntu run before being trusted, not just measured locally.
- `planter.scad`'s Customizer dropdown comment for `relief_mode` (currently `// ["raised", "etched"]`, line 50 as of this plan) must become `// ["raised", "etched", "alternating"]`.

---

## Why a 3x3 supertile, sort-based matching, and a batched union fallback: the research behind this plan

This plan's author ran the actual edge-classification algorithm below against the real geometry in `modules/decoration.scad` (via throwaway OpenSCAD scripts that `include` the real file) before writing any task, per this project's own "verify against real code" convention. Three findings shape every task below and are restated here so implementers don't have to rediscover them:

1. **Feeding only the tile-covering placements list to the edge classifier produces false "gap" bugs.** For `islamic_star`, building `motif_groups` from just the star + 4 `_IS_CROSS_CENTERS` crosses (5 groups) left 48 of the crosses' own outward-facing edges unmatched -- their true neighbour (a star or cross in the next tile over) simply wasn't present in the input. All 48 turned out to be **irrelevant** (their bounding box lies entirely outside `[0,1]x[0,1]`), so this is not itself a bug, but a naive "assert every unmatched edge is a bug" check would wrongly fail on correct geometry. Building `motif_groups` from a 3x3 supertile of each pattern's placement lattice, deduplicated by `_tile_q()`-quantized position, resolved this to exactly 0 unmatched-and-relevant edges for `islamic_star`, `kisrhombille`, the `tumbling_cubes`/`rhombille` 2-group split, and `floret_pentagonal`. `cairo_pentagonal` needed the full 3x3 supertile specifically -- a narrower fix (materializing each of its own 4 covering hubs' full 4-member pinwheel, but no *new* hubs) still left 6 genuine unmatched-and-relevant edges, because Cairo's pinwheel-to-pinwheel boundaries reach hubs the covering list never lists at all.
2. **A nested double-loop edge match is too slow to ship.** `kisrhombille`'s own per-fan `group_id` scheme (required -- see Global Constraints) produces roughly 900 edges at 3x3-supertile scale; a straightforward `[for (i=...) [for (j=...) if (...) j]]` double loop over that many edges did not complete within 180 seconds (verified directly: an `openscad -o foo.stl` invocation of exactly this code was killed by `timeout 180` with no output). The sort-based alternative in Task 1 below -- pair each edge's canonical key with its own index, `sort()` the pairs (`sort()` orders nested vectors lexicographically), then scan the sorted list for runs of adjacent equal keys with a small bounded lookahead (not a full rescan to the end) -- computed the *identical* primary/secondary pair counts (cross-checked against the double-loop result on a smaller, tractable input where both approaches could run) in about 4 seconds on the same input.
3. **BOSL2's own region `union()` function is a separate, later bottleneck for the same pattern.** With matching fixed (finding 2 above), building `kisrhombille`'s groove geometry -- unioning its 129 primary-tier strip regions, then its 300 secondary-tier strip regions (`union(primary_regions)`/`union(secondary_regions)` in the builder below) -- took over two minutes combined and had not finished when this research pass stopped it. This is not a matching-algorithm bug: BOSL2's `union()` function's own doc comment says plainly it is "much slower than the native union module acting on geometry" and its implementation sequentially folds one region into the next (region1+region2, then +region3, then +region4, ...), so the accumulated region's own complexity grows at every step rather than being computed as one batch operation. Because `_tile_outline_from_islands()` needs the resulting *region* (a point list) to keep composing with `_tile_from_islands()` downstream, the native, fast 3D/2D `union()` *module* (which produces rendered geometry, not a region) is not a substitute. Task 1 Step 4 below includes a batched/hierarchical union fallback (`_outline_batched_union()`) that unions small groups first and then unions the much shorter list of group results, which should reduce the total work if the real bottleneck scales with the ACCUMULATED region's complexity rather than the raw item count -- but this plan's own research pass could not fully re-confirm that fallback against the real slow input (a synthetic stand-in of comparable item count, but of non-overlapping quads that don't share vertices the way the real strips deliberately do, unioned in under a minute and so does not prove the real case is fixed). Task 1's implementer must measure the real `kisrhombille`/`floret_pentagonal` build times directly (Step 12) and apply/tune the fallback if plain `union()` is still too slow, rather than trust this plan's own inconclusive synthetic check.

Every per-pattern task below builds `motif_groups` using this same "3x3 supertile, deduplicated" recipe via one shared helper, `_outline_supertile_points()`, introduced in Task 1.

---

## Task 1: Shared builders, `RELIEF_MODES` validation, and two proof patterns (`islamic_star`, `kisrhombille`)

This task is the spec's own recommended "prove the mechanism first" step: it lands both new shared builders, wires the new validation, and rewires exactly 2 patterns chosen to exercise both builders meaningfully -- `islamic_star` (the simple case: every group has one sub-region, `group_id == alt_key`, so the secondary groove tier degrades to empty and there's no internal fan to get wrong) and `kisrhombille` (the one pattern in this whole plan where `group_id` and `alt_key` genuinely diverge, and the highest-risk case for the edge-count/performance finding above). Every later task (2 through 6) reuses this task's shared functions unchanged.

**Files:**
- Modify: `modules/decoration.scad` (generalize `_tile_from_islands()`/`_tile_walls()`; add `_tile_q2()`, `_outline_edge_key()`, `_outline_all_edges()`, `_outline_edge_relevant()`, `_outline_edge_strip()`, `_outline_match_runs()`, `_outline_supertile_points()`, `_OUTLINE_INNER_Z`, `_tile_outline_from_islands()`, `_tile_alternating_from_islands()`; add `RELIEF_MODES`, `ALTERNATING_PATTERNS`; rewire `_islamic_star_tile()` and `_kisrhombille_tile()`; update `_decoration_texture()`'s dispatch for both; update `decorated_solid()`'s validation and `tex_inset` wiring)
- Modify: `planter.scad` (Customizer dropdown comment for `relief_mode`, line 50)
- Modify: `tests/test_decoration_islamic_star.scad` (add `"alternating"` block)
- Modify: `tests/test_decoration_kisrhombille.scad` (add `"alternating"` block)
- Create: `tests/test_decoration_invalid_relief_mode.scad`

**Interfaces:**
- Consumes: `_UNIT_TILE`, `_tile_on_edge()`, `_tile_q()`, `_tile_quantize()`, `_kis_shrunk_fan()`, `_kis_centroid()`, `_TC_CENTERS`, `_tc_rhombus()`, `_TC_V`, `_is_star()`, `_is_cross()`, `_IS_CROSS_CENTERS`, `_IS_R`, `_IS_RIN`, `_IS_RX`, `_IS_GAP`, `_IS_Z_STAR`, `_IS_Z_CROSS`, `_KIS_GAP` -- all pre-existing, unchanged.
- Produces (used by every later task): `_tile_from_islands(islands, ground_z = 0)`, `_tile_walls(path, z, ground_z = 0)`, `_outline_supertile_points(base_points)`, `_tile_outline_from_islands(motif_groups, outer_gap, inner_gap)`, `_tile_alternating_from_islands(islands, high_group, ground_z = 0.5)`, `RELIEF_MODES`, `ALTERNATING_PATTERNS`.

### Step 1: Write the failing tests

Add to `tests/test_decoration_islamic_star.scad` (append before the final `difference() { ... }` block that already renders `"raised"`):

```openscad
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
    decorated_solid("islamic_star", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
difference() {
    decorated_solid("islamic_star", "vertical", "etched", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

Add to `tests/test_decoration_kisrhombille.scad` (append before the final `difference() { ... }` block):

```openscad
// "alternating": alt_key is the fan-triangle's local index (0..3) within its
// own 4-triangle fan, matching the same pinwheel parity the raised heights
// already use ([1.0, 0.4, 1.0, 0.4] -- indices 0 and 2 are the "high" ones).
// group_id must stay unique per fan (a composite (center, k) key) so the
// etched outline builder can tell "same rhombus's own internal seam" apart
// from "boundary between two different rhombi" -- group_id and alt_key
// genuinely differ here, the one case in this whole plan where they do.
_tex_alt = _decoration_texture("kisrhombille", "alternating");
assert(is_vnf(_tex_alt), "_decoration_texture(\"kisrhombille\", \"alternating\") must be a valid VNF");
_alt_zs = unique([for (p = _tex_alt[0]) p[2]]);
assert(_alt_zs == [0, 0.5, 1],
    str("kisrhombille alternating VNF must use exactly Z levels {0, 0.5, 1}, got ", _alt_zs));
assert(_tex_alt != _decoration_texture("kisrhombille", "raised"),
    "kisrhombille alternating tile must differ from raised");
assert(_tex_alt != _decoration_texture("kisrhombille", "etched"),
    "kisrhombille alternating tile must differ from etched");

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex_alt, axis, 0);
    hi = _tile_edge_profile(_tex_alt, axis, 1);
    name = (axis == 0) ? "x" : "y";
    assert(len(lo) == len(hi),
        str("kisrhombille alternating tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("kisrhombille alternating tile ", name, " edge vertices don't line up (including Z): ", mismatched));
}

// Etched must now be a genuinely different (flat panel + two-tier groove)
// VNF from before this plan -- Z levels 1 (panel), 0.5 (secondary/internal
// fan-seam groove), 0 (primary groove -- but kisrhombille's own fans are
// grouped by (center, k), so EVERY internal edge is same-group/secondary;
// primary edges only appear between different rhombi/hexagons, which do
// exist here -- e.g. between two rhombi of the same hexagon share a spoke,
// which is a DIFFERENT group -- so both tiers must appear).
_tex_etched_new = _decoration_texture("kisrhombille", "etched");
_etched_zs_new = unique([for (p = _tex_etched_new[0]) p[2]]);
assert(_etched_zs_new == [0, 0.5, 1],
    str("kisrhombille etched VNF must use exactly Z levels {0, 0.5, 1} (two-tier groove), got ", _etched_zs_new));

difference() {
    decorated_solid("kisrhombille", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

Also create `tests/test_decoration_invalid_relief_mode.scad`:

```openscad
// tests/test_decoration_invalid_relief_mode.scad
//
// relief_mode was never validated before this plan. Two failure modes:
// a bogus string, and "alternating" on a pattern_type that doesn't support
// it (any of the 13 patterns outside ALTERNATING_PATTERNS).
include <../modules/decoration.scad>

decorated_solid("ridges", "vertical", "bogus", 1.5, 12, 75, 60, 100, 4);
```

Create a second negative-test file, `tests/test_decoration_invalid_alternating_pattern.scad`:

```openscad
// tests/test_decoration_invalid_alternating_pattern.scad
//
// "alternating" is only supported for the 8 Phase-1 patterns
// (ALTERNATING_PATTERNS). "ridges" is a BOSL2 heightfield pattern with no
// islands list at all, so this must fail loudly, not silently fall back to
// "raised".
include <../modules/decoration.scad>

decorated_solid("ridges", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
```

### Step 2: Run tests to verify they fail

```bash
openscad -o /tmp/test.csg tests/test_decoration_islamic_star.scad
openscad -o /tmp/test.csg tests/test_decoration_kisrhombille.scad
openscad -o /tmp/test.csg tests/test_decoration_invalid_relief_mode.scad
openscad -o /tmp/test.csg tests/test_decoration_invalid_alternating_pattern.scad
```
Expected: the first two FAIL (`_decoration_texture("islamic_star"/"kisrhombille", "alternating")` doesn't resolve to a VNF yet -- `is_vnf()` assertion fails, or `decorated_solid()` itself asserts on an unrecognized `relief_mode`). The last two currently render successfully with no assertion at all (this project has never validated `relief_mode`) -- confirm this directly rather than assuming it: run `openscad -o /tmp/test.csg tests/test_decoration_invalid_relief_mode.scad` against the CURRENT, unmodified `modules/decoration.scad` and confirm it exits 0 (no assertion fires) before proceeding, so this task's own validation step has a real, demonstrated gap to close.

### Step 3: Generalize `_tile_from_islands()` and `_tile_walls()` with `ground_z`

Replace the existing `_tile_walls()` (`modules/decoration.scad:224-229`):

```openscad
// One vertical quad per non-shared segment, wound so a CCW path (BOSL2's
// convention for a region's outer path) faces outward and a CW path (a hole)
// faces inward. ground_z defaults to 0 (every existing raised-mode caller's
// own implicit floor); the alternating builder's "low" islands (z=0) sit
// BELOW a ground_z=0.5 nominal wall, which flips which pair of vertices is
// the "bottom" of the wall -- a plain substitution of ground_z for the old
// literal 0s is not enough (the quad's face normal would flip for any
// z < ground_z), so this branches explicitly on the sign of z - ground_z.
function _tile_walls(path, z, ground_z = 0) =
    let (n = len(path))
    [for (i = [0:n-1]) let (a = path[i], b = path[(i+1) % n])
        if (!_tile_on_edge(a, b))
            (z >= ground_z)
                ? [[[a[0], a[1], ground_z], [b[0], b[1], ground_z], [b[0], b[1], z], [a[0], a[1], z]],
                   [[0, 1, 2, 3]]]
                : [[[a[0], a[1], z], [b[0], b[1], z], [b[0], b[1], ground_z], [a[0], a[1], ground_z]],
                   [[0, 1, 2, 3]]]];
```

Replace the existing `_tile_from_islands()` (`modules/decoration.scad:231-250`):

```openscad
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
```

This is a pure generalization: every existing call site (`_tumbling_cubes_tile()`, `_rhombille_tile()`, `_cairo_pentagonal_tile()`, `_teardrop_tile()` does NOT use this -- it has its own hand-rolled assembly -- `_tetrakis_square_tile()`, `_kisrhombille_tile()`, `_triakis_triangular_tile()`, `_floret_pentagonal_tile()`, `_deltoidal_trihexagonal_tile()`, `_intertwine_tile()`, `_islamic_star_tile()`) calls `_tile_from_islands(islands)` with one argument, so `ground_z` defaults to `0` and produces byte-identical output to before.

### Step 4: Add the outline-etch shared builder

Insert immediately after the new `_tile_from_islands()` (before the `"--- Shared kis-operation geometry"` comment block):

```openscad
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
// shared edge) hashes identically.
function _outline_edge_key(a, b) =
    let (qa = _tile_q2(a), qb = _tile_q2(b))
    (qa[0] < qb[0] || (qa[0] == qb[0] && qa[1] < qb[1])) ? [qa, qb] : [qb, qa];

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

// Sort-based O(n log n) matching -- see this plan's "Why sort-based
// matching" research note: a naive double loop over ~900 edges (kisrhombille
// at 3x3-supertile scale) did not finish in 180 seconds; this does the
// identical classification in about 4 seconds. Pairs each edge's canonical
// key with its own index, sorts (sort() orders nested vectors
// lexicographically), then scans for runs of adjacent equal keys. `window`
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
            [_outline_edge_strip(edges[r[1][0]][2], edges[r[1][0]][3], outer_gap)]],
        secondary_regions = [for (r = pairs) if (edges[r[1][0]][1] == edges[r[1][1]][1])
            [_outline_edge_strip(edges[r[1][0]][2], edges[r[1][0]][3], inner_gap)]],
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
```

`_tile_outline_from_islands()` already routes both its strip-union calls through `_outline_batched_union()` above (passing its own `union_batch_size` parameter through to `_outline_batched_union()`'s `batch_size`) rather than a bare `union()`, precisely because of this plan's own kisrhombille finding -- Step 12 below still requires measuring the real build time, since this plan's own research could not fully confirm the batched approach against the real slow input (only a non-representative synthetic stand-in -- see the research note). If Step 12 finds a pattern is still too slow at the default `union_batch_size = 8`, try passing a smaller value (e.g. 4) for that pattern's own `_tile_outline_from_islands()` call, or investigate further -- the batching strategy itself, not just its tuning parameter, may need rethinking for that pattern's specific edge/strip count.

### Step 5: Add the alternating shared builder

Insert immediately after `_tile_outline_from_islands()`:

```openscad
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
```

### Step 6: Add `RELIEF_MODES`/`ALTERNATING_PATTERNS` and wire validation into `decorated_solid()`

Insert immediately after `PATTERN_TYPES`'s closing `];` (after the existing `_ASPECT_EXCLUDED_PATTERNS`/`_ASPECT_SQRT3_PATTERNS` block, or directly below `PATTERN_TYPES` -- either is fine; place it right after `PATTERN_TYPES` for visibility):

```openscad
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
```

In `decorated_solid()`, immediately after the existing `pattern_type` assertion (`modules/decoration.scad:790-791`), add:

```openscad
    assert(in_list(relief_mode, RELIEF_MODES),
        str("relief_mode must be one of ", RELIEF_MODES, ", got \"", relief_mode, "\""));
    assert(relief_mode != "alternating" || in_list(pattern_type, ALTERNATING_PATTERNS),
        str("relief_mode \"alternating\" is only supported for pattern_type in ",
            ALTERNATING_PATTERNS, ", got \"", pattern_type, "\""));
```

Replace the existing `is_etched`/`tex_inset` wiring (`modules/decoration.scad:852` and `:866`):

```openscad
        is_etched = (relief_mode == "etched");
```
becomes (kept, still used by the `dots`-specific `depth` line below it, unchanged):
```openscad
        is_etched = (relief_mode == "etched");
```
(no change to that line -- only the `tex_inset` argument to `cyl()` changes). Replace:
```openscad
            tex_inset = is_etched,
```
with:
```openscad
            tex_inset = (relief_mode == "etched") ? true
                      : (relief_mode == "alternating") ? 0.5
                      : false, // "raised"
```

### Step 7: Rewire `islamic_star`

Replace `_islamic_star_tile()` (`modules/decoration.scad:710-714`) entirely:

```openscad
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
```

The `relief_mode == "raised"` (final `:`) branch is the pre-existing `_islamic_star_tile()` body, byte-identical -- confirm this directly by diffing against the pre-edit function body before moving on, since "raised" must not change.

### Step 8: Rewire `kisrhombille`

Replace `_kisrhombille_tile()` (`modules/decoration.scad:590-595`) entirely:

```openscad
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
```

`_kis_raw_fan()` (the pre-shrink, un-offset version of `_kis_shrunk_fan()`'s own triangle construction) does not exist yet -- add it directly above `_kisrhombille_motif_groups()`, next to the existing `_kis_shrunk_fan()`/`_kis_centroid()` in the "Shared kis-operation geometry" section:

```openscad
// Un-shrunk counterpart to _kis_shrunk_fan(): the fan's ORIGINAL triangles
// (no offset() shrink), needed by the outline builder's edge classifier,
// which must see two neighbouring fans' triangles still sharing an exact
// edge to find the true internal-vs-external classification (Correction 1
// in the spec -- the already-gapped islands list is unusable for this).
function _kis_raw_fan(poly) =
    let (c = _kis_centroid(poly), n = len(poly))
    [for (i = [0:n-1]) [c, poly[i], poly[(i+1) % n]]];
```

The `relief_mode == "raised"` branch above is the pre-existing `_kisrhombille_tile()` body, byte-identical.

### Step 9: Update `_decoration_texture()`'s dispatch

No changes needed for `islamic_star`/`kisrhombille` themselves (both already call `pattern_type == "islamic_star" ? _islamic_star_tile()` etc. -- the call site just needs the new `relief_mode` argument threaded through for `islamic_star`, which previously took none). Update the `islamic_star` line in `_decoration_texture()` (`modules/decoration.scad:752`):

```openscad
    pattern_type == "islamic_star"   ? _islamic_star_tile(relief_mode) :
```
(`kisrhombille`'s line, `:754`, already passes `relief_mode` -- no change needed there.)

### Step 10: Update `planter.scad`'s Customizer comment

```openscad
relief_mode = "raised";            // ["raised", "etched", "alternating"]
```

### Step 11: Run the new/modified tests

```bash
openscad -o /tmp/test.csg tests/test_decoration_islamic_star.scad
openscad -o /tmp/test.csg tests/test_decoration_kisrhombille.scad
openscad -o /tmp/test.csg tests/test_decoration_invalid_relief_mode.scad
```
Expected: the first two now PASS. The third: run it and confirm the assertion fires with the message prefix `relief_mode must be one of`; this is a negative test, so "PASS" means the file's `assert()` triggers OpenSCAD's normal ERROR exit -- check via `echo $?` (non-zero) and grep the output for the expected message, the same way `tests/test_decoration_invalid_pattern_type.scad` is checked in `.github/workflows/test.yml`.

```bash
openscad -o /tmp/test.csg tests/test_decoration_invalid_alternating_pattern.scad
```
Expected: FAIL with the message prefix `relief_mode "alternating" is only supported for pattern_type in`.

### Step 12: Time the new tile-build path

`kisrhombille` is a real risk point for the tile-*construction* time (not just CGAL render time), per this plan's own research finding -- and it is NOT resolved yet, only characterized. Run and record wall-clock time:

```bash
time openscad -o /tmp/test.stl tests/test_decoration_kisrhombille.scad
```

Do not assume this will be fast. This plan's own research pass measured `kisrhombille`'s `_tile_outline_from_islands()` call alone (900 edges, 129 primary-tier strips, 300 secondary-tier strips) taking over two minutes on a PLAIN, unbatched `union(primary_regions)`/`union(secondary_regions)` and had not finished when that research pass stopped it to stay within its own budget -- see this plan's "Why a 3x3 supertile..." research note, finding 3. `_tile_outline_from_islands()` as specified in Step 4 above already routes both calls through `_outline_batched_union()` instead of the plain version specifically to address this, but this plan's own research could only confirm the batched approach against a non-representative synthetic stand-in (disjoint quads that don't share vertices), not the real, slower, vertex-sharing strips -- so it is genuinely unknown, as of this plan, whether the default `union_batch_size = 8` is enough. If this file's own build time is more than roughly 10-15 seconds:
1. Confirm `_outline_match_runs()` really is the sort-based approach (not a double loop) -- that was finding 2's own bottleneck and is a different failure mode from this one.
2. Confirm `_tile_outline_from_islands()` really is calling `_outline_batched_union()`, not a bare `union()`, for both `primary_region` and `secondary_union`.
3. Try a smaller `union_batch_size` for this call specifically (`_tile_outline_from_islands(_kisrhombille_motif_groups(), _KISR_OUTER_GAP, _KISR_INNER_GAP, 4)`, e.g.) and re-measure; the parameter defaults to 8 and is per-call, so tuning it for `kisrhombille` alone doesn't affect any other pattern's own call. If that doesn't help either, the batching strategy itself may need rethinking (e.g. batching by which fan/group a strip came from, so spatially-nearby strips get unioned together first, rather than by their arbitrary position in the flat `primary_regions`/`secondary_regions` list) -- treat this as open investigation, not a solved problem this plan can hand over as a known-good recipe.
4. Record whichever outcome actually happened (fixed by batching/tuning, or still slow and needs further investigation) in this task's own commit message and in Task 7's CGAL/performance write-up -- do not silently ship a multi-minute tile build.

`islamic_star`'s own motif_groups are far smaller (star + 4 crosses, no per-fan subdivision) and are not expected to hit this -- confirm with the same `time` invocation on its own test file, but treat a slow result there as a different, more surprising finding worth its own investigation, not evidence this same fix applies.

### Step 13: Commit

```bash
git add modules/decoration.scad planter.scad \
        tests/test_decoration_islamic_star.scad tests/test_decoration_kisrhombille.scad \
        tests/test_decoration_invalid_relief_mode.scad tests/test_decoration_invalid_alternating_pattern.scad
git commit -m "Add outline-etch and alternating relief-mode builders; prove them on islamic_star/kisrhombille"
```

---

## Task 2: `tumbling_cubes` and `rhombille`

Both patterns share the exact same hexagon/rhombus placement geometry (`_TC_CENTERS`, `_tc_rhombus()`) and, per the spec's own resolved bug, must use a **2-group split** for both the outline and alternating builders -- NOT one group per `_TC_CENTERS` index. `_TC_CENTERS = [[0,0],[1,0],[0,1],[1,1],[0.5,0.5]]` has 5 *positions* but only 2 *distinct physical hexagons*: indices 0-3 are periodic images of one hexagon sitting at each integer lattice corner (the same hexagon clipped differently by the unit-tile boundary as it repeats), and only index 4 is a second, genuinely separate hexagon at the true tile center. Grouping by index instead of physical identity would assign different heights to two clipped pieces of the SAME physical motif, breaking the tile-seam height match BOSL2's stitching depends on.

Since the underlying geometry is identical between the two patterns (only the RAISED heights differ -- `tumbling_cubes` uses 3 distinct `_TC_Z` heights for the isometric-cube illusion, `rhombille` uses 1 uniform `_RH_Z`), both patterns' etched/alternating tiles are built via one shared pair of helper functions, called from each pattern's own wrapper with its own named gap constants (per this file's never-share-a-constant convention).

**Files:**
- Modify: `modules/decoration.scad` (add `_tc_motif_groups()`, `_tc_alternating_islands()` shared helpers; add `_TC_OUTER_GAP`/`_TC_INNER_GAP`/`_TC_HIGH_GROUP`, `_RH_OUTER_GAP`/`_RH_INNER_GAP`/`_RH_HIGH_GROUP`; rewire `_tumbling_cubes_tile()` and `_rhombille_tile()`; update `_decoration_texture()`'s dispatch for both)
- Modify: `tests/test_decoration_tumbling_cubes.scad` (add `"etched"`/`"alternating"` blocks)
- Modify: `tests/test_decoration_rhombille.scad` (add `"etched"`/`"alternating"` blocks; **remove** the now-stale "raised and etched must resolve to the exact same VNF" assertion -- this pattern's etched geometry is now genuinely different)

**Interfaces:**
- Consumes (from Task 1): `_tile_outline_from_islands()`, `_tile_alternating_from_islands()`, `_outline_supertile_points()`.
- Produces: `_tumbling_cubes_tile(relief_mode)`, `_rhombille_tile(relief_mode)` (both signature changes from no-arg).

### Step 1: Write the failing tests

Append to `tests/test_decoration_tumbling_cubes.scad` (this file's own `_tile_edge_profile()` helper already exists -- reuse it):

```openscad
_TC_OUTER_GAP_EXPECTED_GROUP_COUNT = 2; // documents the 2-physical-hexagon
                                        // invariant this task's grouping
                                        // depends on -- not a real constant
                                        // in modules/decoration.scad, just a
                                        // readability anchor for this test

_tex_etched = _decoration_texture("tumbling_cubes", "etched");
assert(is_vnf(_tex_etched), "_decoration_texture(\"tumbling_cubes\", \"etched\") must be a valid VNF");
assert(_tex_etched != _tex, "tumbling_cubes etched tile must differ from raised (whole-shape inversion is gone)");
_etched_zs = unique([for (p = _tex_etched[0]) p[2]]);
assert(_etched_zs == [0, 0.5, 1],
    str("tumbling_cubes etched VNF must use exactly Z levels {0, 0.5, 1} (two-tier groove: primary ",
        "between the two physical hexagons, secondary within one hexagon's own 3 rhombi), got ", _etched_zs));

_tex_alt = _decoration_texture("tumbling_cubes", "alternating");
assert(is_vnf(_tex_alt), "_decoration_texture(\"tumbling_cubes\", \"alternating\") must be a valid VNF");
_alt_zs = unique([for (p = _tex_alt[0]) p[2]]);
assert(_alt_zs == [0, 0.5, 1],
    str("tumbling_cubes alternating VNF must use exactly Z levels {0, 0.5, 1}, got ", _alt_zs));
assert(_tex_alt != _tex && _tex_alt != _tex_etched,
    "tumbling_cubes alternating tile must differ from both raised and etched");

for (tex = [_tex_etched, _tex_alt]) {
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(tex, axis, 0);
        hi = _tile_edge_profile(tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        assert(len(lo) == len(hi),
            str("tumbling_cubes tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("tumbling_cubes tile ", name, " edge vertices don't line up (including Z): ", mismatched));
    }
}

difference() {
    decorated_solid("tumbling_cubes", "vertical", "etched", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
difference() {
    decorated_solid("tumbling_cubes", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

Append the mirror-image block to `tests/test_decoration_rhombille.scad` (same structure, `"rhombille"` in place of `"tumbling_cubes"`), and **delete** this file's existing assertion block:

```openscad
// raised and etched must resolve to the exact same VNF -- rhombille's
// geometry doesn't depend on relief_mode ...
_tex_etched = _decoration_texture("rhombille", "etched");
assert(_tex == _tex_etched, ...);
```

(replace it with the new etched-differs-from-raised assertion, matching the new `tumbling_cubes` block's shape).

### Step 2: Run tests to verify they fail

```bash
openscad -o /tmp/test.csg tests/test_decoration_tumbling_cubes.scad
openscad -o /tmp/test.csg tests/test_decoration_rhombille.scad
```
Expected: both FAIL (`_decoration_texture("tumbling_cubes"/"rhombille", "etched")` still returns the pre-existing whole-tile VNF, `!=` assertion against itself fails; `"alternating"` isn't handled at all, `_tumbling_cubes_tile()`/`_rhombille_tile()` still take no `relief_mode` argument so the call itself errors).

### Step 3: Add the shared TC/rhombille helpers

Insert immediately after `_tc_rhombus()` (`modules/decoration.scad:317-319`), before `_tumbling_cubes_tile()`:

```openscad
// Shared by tumbling_cubes and rhombille: both reuse this exact hexagon/
// rhombus placement geometry (_TC_CENTERS/_tc_rhombus()), so their
// etched/alternating tiles are IDENTICAL -- only "raised" differs between
// the two patterns (3 distinct heights for the isometric-cube illusion vs.
// 1 uniform height). group_id/alt_key coincide here (0 = the corner
// hexagon cluster wherever clipped, 1 = the center hexagon) -- the spec's
// own resolved correction: _TC_CENTERS has 5 POSITIONS but only 2
// DISTINCT PHYSICAL hexagons (indices 0-3 are periodic images of one
// hexagon at each integer lattice corner; index 4 is a second, separate
// hexagon at the true tile center). Grouping by _TC_CENTERS index instead
// would assign different heights/groove classification to two clipped
// pieces of the SAME physical motif, breaking the tile-seam match.
function _tc_motif_groups() =
    let (
        corner_centers = _outline_supertile_points([_TC_CENTERS[0], _TC_CENTERS[1],
                                                      _TC_CENTERS[2], _TC_CENTERS[3]]),
        center_centers = _outline_supertile_points([_TC_CENTERS[4]])
    )
    // EXACTLY 2 groups, not one per physical hexagon instance: the outer
    // list here has 2 elements (the corner-cluster group, the center group),
    // each built by a list comprehension with NO extra [] around
    // _tc_rhombus(c, k) -- wrapping it in an extra [...] would instead
    // produce one group per rhombus (far too fine-grained: the spec's own
    // correction collapses ALL corner-cluster rhombi, across every deduped
    // physical hexagon at every integer lattice corner, into ONE group,
    // since they're periodic images of the same motif -- see this task's
    // own opening paragraph). Double-check the bracket depth here against
    // this exact code before shipping; it is the single easiest place in
    // this whole plan to introduce an off-by-one-list-nesting bug.
    [
        [for (c = corner_centers) for (k = [0:2]) _tc_rhombus(c, k)],
        [for (c = center_centers) for (k = [0:2]) _tc_rhombus(c, k)]
    ];

// alt_key/group_id: 0 = corner cluster (wherever clipped), 1 = center
// hexagon. gap/height are supplied by each pattern's own wrapper (see
// _tumbling_cubes_tile()/_rhombille_tile() below) since only the SHRINK
// amount differs between the two patterns (own gap constants), not the
// underlying placement geometry.
function _tc_alternating_islands(gap) =
    concat(
        [for (ci = [0:3]) for (k = [0:2])
            let (r = offset(_tc_rhombus(_TC_CENTERS[ci], k), delta = -gap / 2, closed = true))
            if (len(r) >= 3) [[r], 1, 0, 0]],
        [for (k = [0:2])
            let (r = offset(_tc_rhombus(_TC_CENTERS[4], k), delta = -gap / 2, closed = true))
            if (len(r) >= 3) [[r], 1, 1, 1]]);
```

### Step 4: Rewire `_tumbling_cubes_tile()`

Replace (`modules/decoration.scad:321-325`):

```openscad
_TC_OUTER_GAP = 0.055; // etched primary groove (between the 2 physical
                       // hexagons), own constant, same scale as _TC_GAP
_TC_INNER_GAP = 0.03;  // etched secondary groove (within one hexagon's own
                       // 3 rhombi), thinner than the primary tier
_TC_HIGH_GROUP = [0];  // corner-hexagon-cluster high, center hexagon low --
                       // per the spec's "alternate corner-hexagon-high/
                       // center-hexagon-low or the reverse" -- a visual-
                       // judgment call, confirm this reads well once
                       // rendered

function _tumbling_cubes_tile(relief_mode) =
    relief_mode == "etched"
        ? _tile_outline_from_islands(_tc_motif_groups(), _TC_OUTER_GAP, _TC_INNER_GAP)
    : relief_mode == "alternating"
        ? _tile_alternating_from_islands(_tc_alternating_islands(_TC_GAP), _TC_HIGH_GROUP)
    : _tile_from_islands([
        for (c = _TC_CENTERS) for (k = [0:2])
            let (r = offset(_tc_rhombus(c, k), delta = -_TC_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _TC_Z[k]]]);
```

### Step 5: Rewire `_rhombille_tile()`

Replace (`modules/decoration.scad:343-347`):

```openscad
_RH_OUTER_GAP = 0.055;
_RH_INNER_GAP = 0.03;
_RH_HIGH_GROUP = [0]; // same corner/center split and reasoning as tumbling_cubes

function _rhombille_tile(relief_mode) =
    relief_mode == "etched"
        ? _tile_outline_from_islands(_tc_motif_groups(), _RH_OUTER_GAP, _RH_INNER_GAP)
    : relief_mode == "alternating"
        ? _tile_alternating_from_islands(_tc_alternating_islands(_RH_GAP), _RH_HIGH_GROUP)
    : _tile_from_islands([
        for (c = _TC_CENTERS) for (k = [0:2])
            let (r = offset(_tc_rhombus(c, k), delta = -_RH_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _RH_Z]]);
```

### Step 6: Update `_decoration_texture()`'s dispatch

```openscad
    pattern_type == "tumbling_cubes" ? _tumbling_cubes_tile(relief_mode) :
    ...
    pattern_type == "rhombille"          ? _rhombille_tile(relief_mode) :
```

### Step 7: Run tests, confirm pass; time the build

```bash
openscad -o /tmp/test.csg tests/test_decoration_tumbling_cubes.scad
openscad -o /tmp/test.csg tests/test_decoration_rhombille.scad
time openscad -o /tmp/test.stl tests/test_decoration_tumbling_cubes.scad
```
Expected: both test files PASS; build time single-digit seconds (this pattern's motif_groups has only 2 groups, far below kisrhombille's per-fan scale, so no repeat of Task 1's performance risk is expected -- confirm anyway).

### Step 8: Commit

```bash
git add modules/decoration.scad tests/test_decoration_tumbling_cubes.scad tests/test_decoration_rhombille.scad
git commit -m "Wire outline-etch and alternating relief modes for tumbling_cubes/rhombille"
```

---

## Task 3: `tetrakis_square`

The simplest remaining pattern: the whole unit tile IS the one kis-fanned cell (`_kis_shrunk_fan(_UNIT_TILE, ...)`), so there is exactly **1 group** -- meaning `_tile_outline_from_islands()` produces **zero primary-tier groove** for this pattern (there is no second motif instance within the tile to have a boundary against; the fan's own outer boundary IS the tile edge, already suppressed by `_tile_on_edge()`). This is the pattern that most directly exercises the "no primary groove at all is sometimes correct, not a bug" case documented in Task 1's `_tile_outline_from_islands()` comment.

**Files:**
- Modify: `modules/decoration.scad` (rewire `_tetrakis_square_tile()`; update `_decoration_texture()`'s dispatch -- already passes `relief_mode`, no dispatch-line change needed)
- Modify: `tests/test_decoration_tetrakis_square.scad` (add `"alternating"` block; update the existing etched-must-be-flat assertion, which is now WRONG -- etched is no longer flat, it has a secondary groove)

**Interfaces:**
- Consumes (from Task 1): `_tile_outline_from_islands()`, `_tile_alternating_from_islands()`, `_outline_supertile_points()`, `_kis_raw_fan()` (from Task 1 Step 8).
- Produces: `_tetrakis_square_tile(relief_mode)` (no signature change -- already takes `relief_mode`).

### Step 1: Write the failing tests

The existing assertion in `tests/test_decoration_tetrakis_square.scad`:
```openscad
assert(len(_etched_zs) <= 2,
    str("tetrakis_square etched must be flat (one fan height plus the z=0 ground), got heights ", _etched_zs));
```
must be replaced (this is now false -- etched has a real secondary-tier groove at `_OUTLINE_INNER_Z`):

```openscad
// Etched is now a true outline engrave: since tetrakis_square's single fan
// spans the WHOLE unit tile (there is no second motif instance within one
// tile), there is no motif-to-motif boundary and so NO primary (z=0) groove
// tier at all -- only the fan's own internal seams (secondary, z=0.5). This
// is the one pattern in this plan where that's expected, not a bug: see
// _tile_outline_from_islands()'s own comment on this exact case.
_etched_zs = unique([for (p = _etched_tex[0]) p[2]]);
assert(_etched_zs == [0.5, 1],
    str("tetrakis_square etched VNF must use exactly Z levels {0.5, 1} -- no primary/z=0 ",
        "groove tier, since the whole unit tile is one motif with no sibling instance to ",
        "have a boundary against -- got ", _etched_zs));
assert(_etched_tex != _raised_tex, "tetrakis_square etched tile must differ from raised");

_tex_alt = _decoration_texture("tetrakis_square", "alternating");
assert(is_vnf(_tex_alt), "_decoration_texture(\"tetrakis_square\", \"alternating\") must be a valid VNF");
_alt_zs = unique([for (p = _tex_alt[0]) p[2]]);
assert(_alt_zs == [0, 0.5, 1],
    str("tetrakis_square alternating VNF must use exactly Z levels {0, 0.5, 1}, got ", _alt_zs));
assert(_tex_alt != _raised_tex && _tex_alt != _etched_tex,
    "tetrakis_square alternating tile must differ from both raised and etched");

for (tex = [_etched_tex, _tex_alt]) {
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(tex, axis, 0);
        hi = _tile_edge_profile(tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        assert(len(lo) == len(hi),
            str("tetrakis_square tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("tetrakis_square tile ", name, " edge vertices don't line up (including Z): ", mismatched));
    }
}

difference() {
    decorated_solid("tetrakis_square", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

(the existing `for (relief = ["raised", "etched"])` loop earlier in the file already exercises both modes' VNF/bounds/style checks -- leave that loop as-is, it doesn't assert flatness).

### Step 2: Run test to verify it fails

```bash
openscad -o /tmp/test.csg tests/test_decoration_tetrakis_square.scad
```
Expected: FAIL (current etched IS flat -- `2` Z levels, not the new assertion's expectation, and `"alternating"` isn't wired).

### Step 3: Rewire `_tetrakis_square_tile()`

Replace (`modules/decoration.scad:291-293`):

```openscad
_TSQ_OUTER_GAP = 0.05;  // unused in practice (this pattern's single fan spans
                        // the whole tile -- no motif-to-motif boundary exists
                        // to groove at this tier), kept as a real named
                        // constant/parameter for interface consistency with
                        // every other _tile_outline_from_islands() caller
_TSQ_INNER_GAP = 0.025; // etched secondary groove (the fan's own 4 triangle
                        // seams)
_TSQ_HIGH_GROUP = [0, 2]; // matches the existing raised pinwheel parity
                          // ([1.0, 0.45, 1.0, 0.45] -- indices 0 and 2 high)

function _tetrakis_square_motif_groups() = [_kis_raw_fan(_UNIT_TILE)];

function _tetrakis_square_alternating_islands() =
    [for (e = _kis_shrunk_fan(_UNIT_TILE, _KIS_GAP, [0, 1, 2, 3]))
        [e[0], 1, 0, e[1]]];

function _tetrakis_square_tile(relief_mode) =
    relief_mode == "etched"
        ? _tile_outline_from_islands(_tetrakis_square_motif_groups(), _TSQ_OUTER_GAP, _TSQ_INNER_GAP)
    : relief_mode == "alternating"
        ? _tile_alternating_from_islands(_tetrakis_square_alternating_islands(), _TSQ_HIGH_GROUP)
    : _tile_from_islands(_kis_shrunk_fan(_UNIT_TILE, _KIS_GAP, [1.0, 0.45, 1.0, 0.45]));
```

`_kis_raw_fan()` was already added in Task 1 Step 8 -- no need to redefine it. If this task lands independently of Task 1 in review order (it shouldn't -- Task 1 is a hard prerequisite), confirm `_kis_raw_fan()` exists before writing this step's code.

### Step 4: Run tests, confirm pass; time the build

```bash
openscad -o /tmp/test.csg tests/test_decoration_tetrakis_square.scad
time openscad -o /tmp/test.stl tests/test_decoration_tetrakis_square.scad
```

### Step 5: Commit

```bash
git add modules/decoration.scad tests/test_decoration_tetrakis_square.scad
git commit -m "Wire outline-etch and alternating relief modes for tetrakis_square"
```

---

## Task 4: `triakis_triangular`

Two cells (`_TT_A`, `_TT_B`, the unit square's two diagonal-split triangles), each independently kis-fanned into 3 sub-triangles. Unlike `tetrakis_square`, this pattern DOES have a real motif-to-motif boundary within one tile: the shared diagonal between `_TT_A` and `_TT_B` is a primary (different-group) edge. Unlike `tumbling_cubes`/`kisrhombille`'s pinwheel patterns, `triakis_triangular`'s raised heights are **3 distinct values per fan** (`[1.0, 0.4, 0.7]`), not a clean 2-way alternation -- so `alternating` mode's `high_group` choice here is a genuine judgment call (which single sub-triangle per fan renders high), not a parity that already exists in raised mode to reuse.

**Files:**
- Modify: `modules/decoration.scad` (rewire `_triakis_triangular_tile()`)
- Modify: `tests/test_decoration_triakis_triangular.scad` (add `"alternating"` block; update etched-must-be-flat assertion)

**Interfaces:**
- Consumes (from Task 1): `_tile_outline_from_islands()`, `_tile_alternating_from_islands()`, `_outline_supertile_points()`, `_kis_raw_fan()`.
- Produces: `_triakis_triangular_tile(relief_mode)` (no signature change).

### Step 1: Write the failing tests

Replace the existing flatness assertion:
```openscad
assert(len(_etched_zs) <= 2, ...);
```
with:
```openscad
// Etched is a true outline engrave now: _TT_A and _TT_B ARE two different
// motifs (their shared diagonal is a real primary-tier boundary), so BOTH
// tiers appear here, unlike tetrakis_square.
_etched_zs = unique([for (p = _etched_tex[0]) p[2]]);
assert(_etched_zs == [0, 0.5, 1],
    str("triakis_triangular etched VNF must use exactly Z levels {0, 0.5, 1} (primary groove ",
        "on the A/B diagonal, secondary on each cell's own 3-triangle fan seams), got ", _etched_zs));
assert(_etched_tex != _raised_tex, "triakis_triangular etched tile must differ from raised");

_tex_alt = _decoration_texture("triakis_triangular", "alternating");
assert(is_vnf(_tex_alt), "_decoration_texture(\"triakis_triangular\", \"alternating\") must be a valid VNF");
_alt_zs = unique([for (p = _tex_alt[0]) p[2]]);
assert(_alt_zs == [0, 0.5, 1],
    str("triakis_triangular alternating VNF must use exactly Z levels {0, 0.5, 1}, got ", _alt_zs));
assert(_tex_alt != _raised_tex && _tex_alt != _etched_tex,
    "triakis_triangular alternating tile must differ from both raised and etched");

for (tex = [_etched_tex, _tex_alt]) {
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(tex, axis, 0);
        hi = _tile_edge_profile(tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        assert(len(lo) == len(hi),
            str("triakis_triangular tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("triakis_triangular tile ", name, " edge vertices don't line up (including Z): ", mismatched));
    }
}

difference() {
    decorated_solid("triakis_triangular", "vertical", "alternating", 1.5, 12, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

### Step 2: Run test to verify it fails

```bash
openscad -o /tmp/test.csg tests/test_decoration_triakis_triangular.scad
```
Expected: FAIL.

### Step 3: Rewire `_triakis_triangular_tile()`

Replace (`modules/decoration.scad:614-618`):

```openscad
_TRIT_OUTER_GAP = 0.05;  // etched primary groove (the A/B diagonal boundary)
_TRIT_INNER_GAP = 0.025; // etched secondary groove (each cell's own fan seams)
// alt_key: local triangle index (0..2) within EACH cell's own 3-triangle fan.
// Raised uses 3 DISTINCT heights per fan ([1.0, 0.4, 0.7], no clean 2-way
// parity), so unlike tumbling_cubes/kisrhombille/tetrakis_square this
// high/low split has no existing raised-mode alternation to reuse -- index 0
// (the tallest raised height, 1.0) renders high, indices 1 and 2 low. Visual-
// judgment call, confirm once rendered.
_TRIT_HIGH_GROUP = [0];

function _triakis_triangular_motif_groups() =
    [_kis_raw_fan(_TT_A), _kis_raw_fan(_TT_B)];

function _triakis_triangular_alternating_islands() =
    concat(
        [for (e = _kis_shrunk_fan(_TT_A, _KIS_GAP, [0, 1, 2])) [e[0], 1, "A", e[1]]],
        [for (e = _kis_shrunk_fan(_TT_B, _KIS_GAP, [0, 1, 2])) [e[0], 1, "B", e[1]]]);

function _triakis_triangular_tile(relief_mode) =
    relief_mode == "etched"
        ? _tile_outline_from_islands(_triakis_triangular_motif_groups(), _TRIT_OUTER_GAP, _TRIT_INNER_GAP)
    : relief_mode == "alternating"
        ? _tile_alternating_from_islands(_triakis_triangular_alternating_islands(), _TRIT_HIGH_GROUP)
    : _tile_from_islands(concat(
        _kis_shrunk_fan(_TT_A, _KIS_GAP, [1.0, 0.4, 0.7]),
        _kis_shrunk_fan(_TT_B, _KIS_GAP, [1.0, 0.4, 0.7])));
```

Note `_triakis_triangular_motif_groups()` does **not** need `_outline_supertile_points()`: `_TT_A`/`_TT_B` already tile the unit square exactly with no further lattice to enumerate (there is only ever one copy of each cell per tile, unlike the hexagon/hub-based patterns). Confirm this directly (re-run Task 1's own research methodology -- a throwaway script checking `_outline_stats()`-style bug/nonmanifold counts over `[_kis_raw_fan(_TT_A), _kis_raw_fan(_TT_B)]` alone) before shipping; if it turns up unmatched-and-relevant edges, the fix is the same 3x3-supertile treatment as the other patterns, applied to `_TT_A`/`_TT_B`'s own translated copies.

### Step 4: Run tests, confirm pass; time the build

```bash
openscad -o /tmp/test.csg tests/test_decoration_triakis_triangular.scad
time openscad -o /tmp/test.stl tests/test_decoration_triakis_triangular.scad
```

### Step 5: Commit

```bash
git add modules/decoration.scad tests/test_decoration_triakis_triangular.scad
git commit -m "Wire outline-etch and alternating relief modes for triakis_triangular"
```

---

## Task 5: `cairo_pentagonal`

The first pattern in this plan whose `motif_groups` construction genuinely needs the full 3x3 supertile (not just its own covering hubs' full pinwheel membership -- verified directly in Task 1's research: 6 unmatched-and-relevant edges remained with just the 4 covering hubs materialized to their full 4-member pinwheel; 0 with the full 3x3 supertile). `group_id` is the hub's `(m, n)` position (NOT the placement's `k`, which is a sub-motif's orientation *within* one hub's 4-pentagon pinwheel cluster -- `_CP_PLACEMENTS` has multiple entries sharing the same `(m,n)` at different `k`, and multiple entries sharing the same `k` at different `(m,n)`, so a `k`-only `group_id` would both collide distinct hubs together and split one hub's own cluster apart). `alt_key` is `k` itself. `cairo_pentagonal` has no existing raised-mode parity to reuse for `alt_key`'s high/low split (it's uniform-height in raised mode) -- even-`k`-high is used here as a reasonable default, matching `floret_pentagonal`'s own convention, flagged as a visual-judgment call.

**Files:**
- Modify: `modules/decoration.scad` (rewire `_cairo_pentagonal_tile()`; update `_decoration_texture()`'s dispatch -- signature change, was no-arg)
- Modify: `tests/test_decoration_cairo_pentagonal.scad` (add `"etched"`/`"alternating"` blocks; **remove** the stale "raised and etched must resolve to the exact same VNF" assertion)

**Interfaces:**
- Consumes (from Task 1): `_tile_outline_from_islands()`, `_tile_alternating_from_islands()`, `_outline_supertile_points()`.
- Produces: `_cairo_pentagonal_tile(relief_mode)` (signature change from no-arg).

### Step 1: Write the failing tests

Delete this existing block from `tests/test_decoration_cairo_pentagonal.scad`:
```openscad
_tex_etched = _decoration_texture("cairo_pentagonal", "etched");
assert(_tex == _tex_etched, ...);
```

Replace with:
```openscad
_tex_etched = _decoration_texture("cairo_pentagonal", "etched");
assert(is_vnf(_tex_etched), "_decoration_texture(\"cairo_pentagonal\", \"etched\") must be a valid VNF");
assert(_tex_etched != _tex, "cairo_pentagonal etched tile must differ from raised (whole-shape inversion is gone)");
_etched_zs = unique([for (p = _tex_etched[0]) p[2]]);
assert(_etched_zs == [0, 0.5, 1],
    str("cairo_pentagonal etched VNF must use exactly Z levels {0, 0.5, 1} (primary groove between ",
        "different hubs' pentagons, secondary within one hub's own 4-pentagon pinwheel), got ", _etched_zs));

_tex_alt = _decoration_texture("cairo_pentagonal", "alternating");
assert(is_vnf(_tex_alt), "_decoration_texture(\"cairo_pentagonal\", \"alternating\") must be a valid VNF");
_alt_zs = unique([for (p = _tex_alt[0]) p[2]]);
assert(_alt_zs == [0, 0.5, 1],
    str("cairo_pentagonal alternating VNF must use exactly Z levels {0, 0.5, 1}, got ", _alt_zs));
assert(_tex_alt != _tex && _tex_alt != _tex_etched,
    "cairo_pentagonal alternating tile must differ from both raised and etched");

for (tex = [_tex_etched, _tex_alt]) {
    for (axis = [0, 1]) {
        lo = _tile_edge_profile(tex, axis, 0);
        hi = _tile_edge_profile(tex, axis, 1);
        name = (axis == 0) ? "x" : "y";
        assert(len(lo) == len(hi),
            str("cairo_pentagonal tile has ", len(lo), " vertices on ", name, "=0 but ",
                len(hi), " on ", name, "=1 -- tiles cannot stitch"));
        mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                         str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
        assert(len(mismatched) == 0,
            str("cairo_pentagonal tile ", name, " edge vertices don't line up (including Z): ", mismatched));
    }
}

difference() {
    decorated_solid("cairo_pentagonal", "vertical", "etched", 1.5, 32, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
difference() {
    decorated_solid("cairo_pentagonal", "vertical", "alternating", 1.5, 32, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

(Keep `pattern_repeat=32` for the new `difference()` blocks -- this file's own existing comment explains that value was chosen and CI-confirmed for exactly this pattern/geometry combination; reuse it rather than reverting to the template's usual 12.)

### Step 2: Run test to verify it fails

```bash
openscad -o /tmp/test.csg tests/test_decoration_cairo_pentagonal.scad
```
Expected: FAIL.

### Step 3: Rewire `_cairo_pentagonal_tile()`

Replace (`modules/decoration.scad:394-400`):

```openscad
_CP_OUTER_GAP = 0.05;
_CP_INNER_GAP = 0.025;
_CP_HIGH_GROUP = [0, 2]; // even k high, odd k low -- no existing raised-mode
                         // parity to reuse (cairo_pentagonal is uniform-
                         // height in raised mode), so this is a visual-
                         // judgment default matching floret_pentagonal's own
                         // convention; confirm once rendered

// group_id = the hub's (m,n) position (quantized), NOT the placement's k --
// k is a sub-motif's orientation WITHIN one hub's cluster; _CP_PLACEMENTS has
// multiple entries sharing the same (m,n) at different k, and multiple
// entries sharing the same k at different (m,n), so a k-only group_id would
// both collide distinct hubs together and split one hub's own cluster apart.
function _cairo_pentagonal_motif_groups() =
    let (
        hubs_raw = unique([for (pl = _CP_PLACEMENTS) [pl[0], pl[1]]]),
        hubs = _outline_supertile_points(hubs_raw)
    )
    [for (h = hubs) [for (k = [0:3]) _cp_pentagon(h[0], h[1], k)]];

function _cairo_pentagonal_alternating_islands() =
    [for (pl = _CP_PLACEMENTS)
        let (poly = _cp_pentagon(pl[0], pl[1], pl[2]),
             r = offset(poly, delta = -_CP_GAP / 2, closed = true))
        if (len(r) >= 3) [[r], 1, [pl[0], pl[1]], pl[2]]];

function _cairo_pentagonal_tile(relief_mode) =
    relief_mode == "etched"
        ? _tile_outline_from_islands(_cairo_pentagonal_motif_groups(), _CP_OUTER_GAP, _CP_INNER_GAP)
    : relief_mode == "alternating"
        ? _tile_alternating_from_islands(_cairo_pentagonal_alternating_islands(), _CP_HIGH_GROUP)
    : _tile_from_islands([
        for (pl = _CP_PLACEMENTS)
            let (poly = _cp_pentagon(pl[0], pl[1], pl[2]),
                 r = offset(poly, delta = -_CP_GAP / 2, closed = true))
            if (len(r) >= 3) [[r], _CP_Z]
    ]);
```

`_cairo_pentagonal_motif_groups()` deliberately builds each deduped hub's **full 4-member pinwheel** (`for (k = [0:3])`), not just the `k` values `_CP_PLACEMENTS` happens to list for that hub -- Task 1's own research found this necessary (a hub materialized with only its listed `k`s still left genuine gaps in the arrangement, since a pinwheel's own missing member is exactly where its neighbour-hub's edges would otherwise find their match).

### Step 4: Update `_decoration_texture()`'s dispatch

```openscad
    pattern_type == "cairo_pentagonal"   ? _cairo_pentagonal_tile(relief_mode) :
```

### Step 5: Run tests, confirm pass; time the build

```bash
openscad -o /tmp/test.csg tests/test_decoration_cairo_pentagonal.scad
time openscad -o /tmp/test.stl tests/test_decoration_cairo_pentagonal.scad
```
This pattern's `motif_groups` are larger than Task 1's proof patterns (up to ~20+ deduped hubs x 4 pentagons at 3x3-supertile scale) -- confirm build time is still reasonable (a handful of seconds); if not, this is the next place to check the sort-based-matching requirement was actually followed.

### Step 6: Commit

```bash
git add modules/decoration.scad tests/test_decoration_cairo_pentagonal.scad
git commit -m "Wire outline-etch and alternating relief modes for cairo_pentagonal"
```

---

## Task 6: `floret_pentagonal`

Structurally the closest pattern to `cairo_pentagonal` (hub-based grouping, `alt_key = k`), but already has an existing raised-mode parity to reuse directly: `floret_pentagonal`'s raised mode already alternates high/low by placement orientation `k` (even → high, odd → low). Reuse that same parity for `alt_key`'s high/low split in `"alternating"` mode (mapped to `1`/`0` instead of `1`/`_FP_Z_LO`, per the spec).

**Files:**
- Modify: `modules/decoration.scad` (rewire `_floret_pentagonal_tile()`)
- Modify: `tests/test_decoration_floret_pentagonal.scad` (add `"alternating"` block; update the etched-must-differ-from-raised assertions, which already exist and stay true, but the etched Z-level assertion changes)

**Interfaces:**
- Consumes (from Task 1): `_tile_outline_from_islands()`, `_tile_alternating_from_islands()`, `_outline_supertile_points()`.
- Produces: `_floret_pentagonal_tile(relief_mode)` (no signature change).

### Step 1: Write the failing tests

Replace the existing etched Z-level assertion:
```openscad
assert(_zs_etched == [0, 1],
    str("floret_pentagonal etched VNF must use exactly 2 Z levels (ground, uniform full height), got ", _zs_etched));
```
with:
```openscad
// Etched is now a true outline engrave, not a flattened-fan flat panel:
// primary groove between different hubs' rosettes, secondary within one
// hub's own 6-pentagon rosette.
assert(_zs_etched == [0, 0.5, 1],
    str("floret_pentagonal etched VNF must use exactly Z levels {0, 0.5, 1} (two-tier groove), got ", _zs_etched));
```

Add, after the existing raised/etched comparison assertions:
```openscad
_tex_alt = _decoration_texture("floret_pentagonal", "alternating");
assert(is_vnf(_tex_alt), "_decoration_texture(\"floret_pentagonal\", \"alternating\") must be a valid VNF");
_zs_alt = unique([for (p = _tex_alt[0]) p[2]]);
assert(_zs_alt == [0, 0.5, 1],
    str("floret_pentagonal alternating VNF must use exactly Z levels {0, 0.5, 1}, got ", _zs_alt));
assert(_tex_alt != _tex_raised && _tex_alt != _tex_etched,
    "floret_pentagonal alternating tile must differ from both raised and etched");

for (axis = [0, 1]) {
    lo = _tile_edge_profile(_tex_alt, axis, 0);
    hi = _tile_edge_profile(_tex_alt, axis, 1);
    name = (axis == 0) ? "x" : "y";
    assert(len(lo) == len(hi),
        str("floret_pentagonal alternating tile has ", len(lo), " vertices on ", name, "=0 but ",
            len(hi), " on ", name, "=1 -- tiles cannot stitch"));
    mismatched = [for (i = [0:len(lo)-1]) if (!approx(lo[i], hi[i]))
                     str(name, "=0 ", lo[i], " vs ", name, "=1 ", hi[i])];
    assert(len(mismatched) == 0,
        str("floret_pentagonal alternating tile ", name, " edge vertices don't line up (including Z): ", mismatched));
}

difference() {
    decorated_solid("floret_pentagonal", "vertical", "alternating", 1.5, 26, 75, 60, 100, 4);
    translate([300, 0, 0]) cube(10, center = true);
}
```

(Keep `pattern_repeat=26` for this new `difference()`, matching this file's own existing raised-mode render's CGAL-safe value for this exact geometry.)

### Step 2: Run test to verify it fails

```bash
openscad -o /tmp/test.csg tests/test_decoration_floret_pentagonal.scad
```
Expected: FAIL.

### Step 3: Rewire `_floret_pentagonal_tile()`

Replace (`modules/decoration.scad:479-487`):

```openscad
_FP_OUTER_GAP = 0.05;
_FP_INNER_GAP = 0.025;
_FP_HIGH_GROUP = [0, 2, 4]; // reuses the SAME even-k-high parity raised mode
                            // already uses -- mapped to 1/0 instead of 1/_FP_Z_LO

// group_id = the hub's (hub_x, hub_y) position, NOT k -- same reasoning as
// cairo_pentagonal: _FP_PLACEMENTS has six entries sharing the same hub, one
// per pentagon in that hub's rosette, so a k-only group_id would treat
// different hubs' pentagons as one motif and one hub's own rosette as
// several.
function _floret_pentagonal_motif_groups() =
    let (
        hubs_raw = unique([for (pl = _FP_PLACEMENTS) [pl[0], pl[1]]]),
        hubs = _outline_supertile_points(hubs_raw)
    )
    [for (h = hubs) [for (k = [0:5]) _fp_pentagon(h[0], h[1], k)]];

function _floret_pentagonal_alternating_islands() =
    [for (pl = _FP_PLACEMENTS)
        let (poly = _fp_pentagon(pl[0], pl[1], pl[2]),
             r = offset(poly, delta = -_FP_GAP / 2, closed = true))
        if (len(r) >= 3) [[r], 1, [pl[0], pl[1]], pl[2]]];

function _floret_pentagonal_tile(relief_mode) =
    relief_mode == "etched"
        ? _tile_outline_from_islands(_floret_pentagonal_motif_groups(), _FP_OUTER_GAP, _FP_INNER_GAP)
    : relief_mode == "alternating"
        ? _tile_alternating_from_islands(_floret_pentagonal_alternating_islands(), _FP_HIGH_GROUP)
    : _tile_from_islands([
        for (pl = _FP_PLACEMENTS)
            let (poly = _fp_pentagon(pl[0], pl[1], pl[2]),
                 r = offset(poly, delta = -_FP_GAP / 2, closed = true),
                 z = (pl[2] % 2 == 0) ? _FP_Z_HI : _FP_Z_LO)
            if (len(r) >= 3) [[r], z]
    ]);
```

Note the `"raised"` branch above drops the old `(relief_mode == "etched") ? _FP_Z_HI : ...` ternary entirely -- that branch only existed because raised and etched used to share one dispatch expression; now etched has its own top-level branch, so the `"raised"` (final `:`) branch only ever needs its own raised-mode height rule.

`_floret_pentagonal_motif_groups()` builds each deduped hub's **full 6-member rosette** (`for (k = [0:5])`), matching the same "materialize every group member, not just what the covering list happened to need" requirement `cairo_pentagonal` has. Task 1's research found this pattern resolves cleanly with just its own hubs' full rosettes (no unmatched-and-relevant edges even without extending to further neighbour hubs) -- but build `motif_groups` from the full 3x3-supertile hub set anyway, for consistency with every other pattern in this plan and because the cheaper "just this pattern's own hubs" version was only verified for `floret_pentagonal` specifically, not proven necessary-and-sufficient in general.

### Step 4: Run tests, confirm pass; time the build

```bash
openscad -o /tmp/test.csg tests/test_decoration_floret_pentagonal.scad
time openscad -o /tmp/test.stl tests/test_decoration_floret_pentagonal.scad
```
This is the largest `motif_groups` in the whole plan (18 placements, hubs at 3x3-supertile scale, 6-member rosettes each) -- confirm build time carefully; this is the single most likely place for the O(n²)-matching mistake to resurface if a future edit ever reintroduces it.

### Step 5: Commit

```bash
git add modules/decoration.scad tests/test_decoration_floret_pentagonal.scad
git commit -m "Wire outline-etch and alternating relief modes for floret_pentagonal"
```

---

## Task 7: Test-infrastructure updates, CGAL-sweep guidance, and documentation

**Files:**
- Modify: `tests/test_decoration_pattern_types.scad` (no `PATTERN_TYPES`/`EXPECTED_VNF_PATTERN_TYPES` changes needed -- this task only touched `relief_mode` behavior, not pattern names or which patterns resolve to VNFs at `"raised"` -- but re-run it to confirm the `raised`-mode dispatch table is still untouched)
- Modify: `tests/test_decoration_etched_groove.scad` (this file's whole premise -- `VNF_PATTERN_TYPES` = "etched equals raised" vs. `KIS_PATTERN_TYPES` = "etched differs from raised" -- is now WRONG for every Phase-1 pattern except `intertwine`; needs a real rewrite, not a list edit)
- Modify: `.github/workflows/test.yml` (per-pattern test loop already includes every `test_decoration_<name>.scad` file by name -- no loop changes needed for those; the single-pattern `for pt in ...` `relief_mode` loop, `~line 97`, must add `"alternating"`; add `test_decoration_invalid_relief_mode.scad`/`test_decoration_invalid_alternating_pattern.scad` to the negative-test section; extend `run_assembly_combo` coverage per Step 3 below)
- Modify: `README.md` (rewrite the `"etched"` discussion; add `"alternating"` coverage; extend the CGAL-fragility section)
- Modify: `docs/gallery.md` (add an "Alternating" column to each of the 8 Phase-1 patterns' tables; note images need regenerating)
- Modify: `docs/images/render.sh` (extend its per-pattern image list to render an `"alternating"` variant for the 8 Phase-1 patterns, following its existing raised/etched invocation pattern)
- Modify: `TODO.md` (check off the etched-mode redesign item; add a Phase 2 backlog item for the 4 BOSL2-native pattern conversions)

### Step 1: Rewrite `tests/test_decoration_etched_groove.scad`

This file's current structure pins two static facts that are now false for 6 of the 8 patterns it covers:
- `VNF_PATTERN_TYPES = ["teardrop", "tumbling_cubes", "intertwine", "islamic_star", "rhombille", "cairo_pentagonal", "deltoidal_trihexagonal"]` asserts `_decoration_texture(pt, "etched") == _decoration_texture(pt, "raised")` for every listed pattern -- true only for `teardrop`, `intertwine`, `deltoidal_trihexagonal` after this plan (the three untouched-by-design patterns). `tumbling_cubes`, `islamic_star`, `rhombille`, `cairo_pentagonal` must move OUT of this list.
- `KIS_PATTERN_TYPES = ["tetrakis_square", "kisrhombille", "triakis_triangular", "floret_pentagonal"]` asserts `_decoration_texture(pt, "etched") != _decoration_texture(pt, "raised")` -- still true, and now joined by the 4 patterns moving out of `VNF_PATTERN_TYPES` above.

Read the file fresh to confirm its exact current shape (it should match what Task 1-6 left it, since none of those tasks touched this file), then:

```openscad
// VNF_PATTERN_TYPES: patterns whose etched tile is IDENTICAL to raised
// (decorated_solid()'s tex_inset alone handles the raised/etched
// distinction). After the relief-mode redesign, this is down to the 3
// patterns Task 1's Global Constraints explicitly kept untouched:
// "teardrop" (no islands list, hand-rolled outline), "intertwine" (already
// correct via its one pre-unioned island), and "deltoidal_trihexagonal" (no
// relief_mode split at all -- uniform height in every mode).
VNF_PATTERN_TYPES = ["teardrop", "intertwine", "deltoidal_trihexagonal"];

// KIS_PATTERN_TYPES: patterns whose etched and raised tiles are genuinely
// DIFFERENT VNFs. After the relief-mode redesign this is all 8 Phase-1
// patterns (tumbling_cubes/islamic_star/rhombille/cairo_pentagonal joined
// tetrakis_square/kisrhombille/triakis_triangular/floret_pentagonal here,
// moving OUT of VNF_PATTERN_TYPES above) -- every one of them now builds a
// real two-tier outline groove via _tile_outline_from_islands(), not a
// flattened-fan panel or a whole-shape inversion.
KIS_PATTERN_TYPES = ["tumbling_cubes", "islamic_star", "tetrakis_square",
                     "kisrhombille", "triakis_triangular", "rhombille",
                     "cairo_pentagonal", "floret_pentagonal"];
```

The rest of the file's structure (the loop asserting every OTHER `pattern_type` keeps today's inset-the-bump behaviour, the `KIS_PATTERN_TYPES` loop asserting `etched != raised` and both are valid VNFs, the final render loop) is unaffected by this list change and needs no further edits -- confirm this by reading the loops after making the list edit, since a loop that iterates `PATTERN_TYPES` and branches on `in_list(pt, VNF_PATTERN_TYPES)`/`in_list(pt, KIS_PATTERN_TYPES)` will now route `tumbling_cubes`/`islamic_star`/`rhombille`/`cairo_pentagonal` through the `KIS_PATTERN_TYPES` branch automatically once the list membership changes, with no other code change needed.

Run:
```bash
openscad -o /tmp/test.csg tests/test_decoration_etched_groove.scad
```
Expected: PASS with the two list edits above (all 6 tasks' worth of rewiring must already be committed for this to pass -- this is a good end-to-end cross-check that every pattern's dispatch actually changed as intended).

### Step 2: Extend `.github/workflows/test.yml`

- The `for f in teardrop tumbling_cubes intertwine islamic_star tetrakis_square kisrhombille triakis_triangular rhombille cairo_pentagonal floret_pentagonal deltoidal_trihexagonal; do` per-tile-test loop (`~line 74-76`) already runs every `tests/test_decoration_<name>.scad` file by name -- no change needed, since Tasks 1-6 extended those files in place rather than creating new ones (except the two new negative-test files, added separately below).
- The single-pattern `for pt in ...; do for relief in raised etched; do` loop (`~line 97-99`) must become `for relief in raised etched alternating; do` -- but `"alternating"` will assertion-fail for the 13 non-`ALTERNATING_PATTERNS` values in that same `for pt in ...` list, so this loop needs to skip `relief_mode="alternating"` for those, e.g.:
  ```bash
  for pt in none ridges diamonds hex_grid pyramids bricks checkers dots cubes tri_grid teardrop tumbling_cubes intertwine islamic_star tetrakis_square kisrhombille triakis_triangular rhombille cairo_pentagonal floret_pentagonal deltoidal_trihexagonal; do
    for relief in raised etched alternating; do
      if [ "$relief" = "alternating" ]; then
        case "$pt" in
          tumbling_cubes|islamic_star|tetrakis_square|kisrhombille|triakis_triangular|rhombille|cairo_pentagonal|floret_pentagonal) ;;
          *) continue ;;
        esac
      fi
      echo "=== decorated_solid pattern_type=$pt relief_mode=$relief (expect texture build to succeed) ==="
      ...
  ```
  Read the existing loop body fresh before editing (it currently builds a `decorated_solid()` call directly, not via a helper function) and keep its existing error-detection logic (`ERROR`/`CGAL error` grep) unchanged -- only the iteration and skip-list are new.
- Add both new negative tests to the invalid-input section (near the existing `tests/test_decoration_invalid_pattern_type.scad` block, `~line 524-536`):
  ```bash
  echo "=== tests/test_decoration_invalid_relief_mode.scad (expect specific message) ==="
  out=$(openscad -o /tmp/ci_test_decoration_invalid_relief_mode.csg tests/test_decoration_invalid_relief_mode.scad 2>&1)
  code=$?
  if [ $code -eq 0 ]; then
    echo "FAIL: invalid relief_mode did not actually fail an assertion"
    exit 1
  fi
  if ! echo "$out" | grep -q "relief_mode must be one of"; then
    echo "FAIL: invalid relief_mode assertion is missing the expected message prefix"
    exit 1
  fi

  echo "=== tests/test_decoration_invalid_alternating_pattern.scad (expect specific message) ==="
  out=$(openscad -o /tmp/ci_test_decoration_invalid_alternating_pattern.csg tests/test_decoration_invalid_alternating_pattern.scad 2>&1)
  code=$?
  if [ $code -eq 0 ]; then
    echo "FAIL: invalid alternating-pattern combo did not actually fail an assertion"
    exit 1
  fi
  if ! echo "$out" | grep -q 'relief_mode "alternating" is only supported for pattern_type in'; then
    echo "FAIL: invalid alternating-pattern assertion is missing the expected message prefix"
    exit 1
  fi
  ```
- Extend `run_assembly_combo` coverage (`~line 318-346` and `~line 415-420`): each of the 8 `ALTERNATING_PATTERNS` needs at least one `run_assembly_combo "$pt" "alternating" <reps>` entry at a CI-safe reduced value, and (pending Step 3's sweep results) a defaults-pinning entry alongside the existing `raised`/`etched` ones. **Do not guess reduced values from the existing raised/etched entries** -- the etched geometry itself changed shape entirely (a groove network instead of a flattened panel or whole-shape inversion) for 6 of the 8 patterns, and alternating is new geometry outright; per this plan's own CGAL-fragility Global Constraint, every fragility threshold in this file "moves whenever the underlying tile geometry changes" (README.md's own existing wording), so the existing pinned values cannot be assumed to still be safe for the NEW etched geometry either. Step 3 covers the actual sweep methodology.

### Step 3: CGAL-fragility sweep -- methodology (do not skip; do not assume old values transfer)

This redesign changes the etched VNF for 6 patterns entirely (a groove-network construction, not the old flattened-fan-panel or whole-shape-inversion) and introduces new alternating-mode geometry for all 8 Phase-1 patterns -- a materially larger CGAL-risk surface than any single new pattern this project has shipped before (8 patterns x up to 2 changed/new relief modes = up to 16 new VNF constructions to characterize, versus 1 VNF for a typical new-pattern plan). Follow the exact sweep discipline `cairo_pentagonal`/`floret_pentagonal`/`intertwine`/`deltoidal_trihexagonal`'s own plans established, run per pattern:

1. For each of the 8 `ALTERNATING_PATTERNS`, for each of the (up to) 2 changed/new relief modes (`"etched"` for all 8; `"alternating"` for all 8 -- 16 total sweeps), build `tests/test_planter_integration.scad` (the full assembly, not a bare cylinder) across `pattern_repeat` 3 through 16 at `smoothness=24`, and across `smoothness` in `{24, 40, 60, 80, 100}` at the shipped `pattern_repeat=16`, via real `openscad -o foo.stl -D 'pattern_type="..."' -D 'relief_mode="..."' -D 'pattern_repeat=N' -D 'smoothness=M' tests/test_planter_integration.scad` invocations (not `.csg` -- an `.stl` export is what actually forces the CGAL Nef-polyhedron evaluation this fragility class depends on). Grep each run's console output for `CGAL error`.
2. Record every abort/clean result in a table, the same style `README.md`'s existing CGAL section already uses per pattern (see the `cairo_pentagonal`/`floret_pentagonal`/`deltoidal_trihexagonal` paragraphs there for the exact tone and level of numeric specificity this project expects -- concrete `pattern_repeat` values that aborted/were clean, not a vague "some values may fail").
3. For each pattern/mode combination that finds at least one real abort, pick a CI-pinned reduced `pattern_repeat` value with a **tested-clean margin on both sides**, not an isolated clean value between two aborts (`intertwine`'s own history is the standing cautionary example: its first CI-pinned value, 3, passed locally but CGAL-aborted on the real GitHub Actions Ubuntu runner specifically because it lacked that margin).
4. If a pattern/mode combination measures clean across the ENTIRE tested range (no aborts anywhere), it joins the "measured clean everywhere" precautionary bucket (like the "kis" family / `deltoidal_trihexagonal` do today) instead of the "known to abort" bucket -- update `decorated_solid()`'s two-bucket `echo()` warning accordingly (`modules/decoration.scad:834-849` as of this plan) for whichever patterns' bucket placement changes as a result of this task (a pattern already in the "known to abort" bucket for its OLD etched geometry may or may not still belong there for the NEW etched geometry -- re-measure, don't assume the bucket carries over).
5. Update `README.md`'s CGAL section with the real, measured results (Step 4 below covers exact wording/placement) and `.github/workflows/test.yml`'s `run_assembly_combo` calls with the chosen reduced values.
6. **Get at least one CI-pinned value per pattern confirmed against a real GitHub Actions Ubuntu run** before treating any bucket placement or pinned value as final -- push a branch, watch the workflow run, and record the run URL in `README.md` the same way `rhombille`'s own CGAL paragraph already links a specific confirming run. Every pattern's local-macOS sweep result must be labeled as such (not silently presented as CI-confirmed) until this step completes for it.

This step is explicitly **not required to be fully executed by whoever writes/reviews this plan** -- per this project's own established convention (see `docs/superpowers/plans/2026-09-20-deltoidal-trihexagonal-pattern.md`'s own Step 9), it is fine for a plan to specify this methodology precisely and leave running the full 16-combination sweep to the task's own implementer, PROVIDED the implementer actually runs it (not skip it on the strength of this plan's own smaller spot-check below) before this task is considered complete.

**This plan's own spot-check** (not a substitute for the full sweep above, but real, direct evidence gathered while researching this plan): a throwaway script building `kisrhombille`'s real `"alternating"` tile (a small, fast, isolated check confirming a correct, ground_z-aware `_tile_from_islands()`/`_tile_walls()` produces exactly Z levels `{0, 0.5, 1}` and a matching tile seam -- completed in about 3 seconds) and its real `"etched"`/outline tile (via the exact algorithm in Task 1, with the sort-based matching fix but WITHOUT yet trying the `_outline_batched_union()` fallback) found the matching step itself fast (~4 seconds, 900 edges, 129 primary/300 secondary pairs, 0 bugs), but the subsequent `union(primary_regions)`/`union(secondary_regions)` calls took over 2 minutes combined and had not finished when this research pass stopped them to stay within its own time budget -- see this plan's "Why a 3x3 supertile..." research note, finding 3, and Task 1 Step 4's `_outline_batched_union()` fallback, added specifically because of this finding. A full real-cylinder-and-CGAL render (the shipped-defaults geometry, `cyl(h=138, r1=61, r2=82.3, $fn=60, tex_reps=[16,8], tex_depth=1.5)`, differenced against a disjoint cube) was attempted but never reached CGAL evaluation at all in this research pass, since it was blocked on the strip-union step finishing first -- so this plan has **no** direct CGAL-fragility evidence for `kisrhombille`'s new etched geometry yet, only a build-time finding. Treat `kisrhombille` and `floret_pentagonal` as the two highest-priority patterns for this step's own sweep, both for CGAL-fragility AND for build-time -- if either takes materially longer than the other 6 patterns' own sweeps (even after applying the batched-union fallback and confirming it helps), that is itself a finding worth recording in `README.md` (a "this pattern's tile construction is slow, not just CGAL-fragile" caveat, distinct from the existing CGAL-abort caveats), not just silently accepted.

### Step 4: Rewrite `README.md`'s `"etched"` discussion

The current text (the "`\"etched\"` works one of two ways depending on the pattern" paragraph and its "kis family"/`floret_pentagonal` special-casing, `README.md`'s "Decoration Examples" section) describes a per-pattern-family split that Goal #2 of the spec explicitly retires for the 8 Phase-1 patterns -- after this plan, etched works the SAME way for all 8 (a two-tier outline groove), so this documentation should get simpler, not just updated in place. Replace the paragraph beginning `\`"etched"\` works one of two ways depending on the pattern.` through the end of the `"kis" family`/`floret_pentagonal` sentence with:

```markdown
`"etched"` works one of two ways depending on the pattern. `"ridges"`, `"pyramids"` and `"diamonds"` have a flat-topped counterpart shape, so etching them is a true line engrave: the wall keeps its nominal surface as flat panels, and only a thin V-groove is cut along each of the pattern's outlines. `"hex_grid"` and `"tri_grid"` work the same way, just shifting the same panel/groove relief inward rather than swapping to a separate counterpart shape.

Eight patterns -- `"tumbling_cubes"`, `"islamic_star"`, `"tetrakis_square"`, `"kisrhombille"`, `"triakis_triangular"`, `"rhombille"`, `"cairo_pentagonal"` and `"floret_pentagonal"` -- use a different, uniform mechanism: a flat wall cut by a real two-tier engraved groove. A primary groove traces each motif's own outer silhouette (where it meets a *different* motif instance -- e.g. the line between two adjacent Cairo pentagons, or between `"islamic_star"`'s star and a neighbouring cross); a thinner, shallower secondary groove marks internal facet structure within one motif, where a pattern has any (the "kis" family's fan triangles, `"floret_pentagonal"`'s rosette blades, `"tumbling_cubes"`'/`"rhombille"`'s per-rhombus seams, `"cairo_pentagonal"`'s per-hub pinwheel seams). A pattern whose motif has no internal sub-structure of its own within one tile (`"tetrakis_square"`'s single fan spans the whole unit tile, with no second motif instance inside it to have an outer boundary against) legitimately shows only the secondary tier, or only the primary tier -- whichever tier has nothing to groove is simply absent, not a bug.

`"none"` has no texture at all, so it only has one useful mode. `"teardrop"` and `"intertwine"` keep their own pre-existing etched behaviour (a whole-silhouette groove around each's own single pre-built island) -- see the note on those two patterns below. `"dots"`, `"cubes"`, `"checkers"` and `"bricks"` still sink the raised bump into a dimple, unchanged; converting them to the two-tier groove mechanism above is a deferred future project.

`"alternating"` (new) is a third relief style: within one tile, some copies of a motif sit proud of the nominal wall surface and others sit sunk below it, in a single render -- true bas-relief, not a raised or etched pass unioned with its own inverse. It's available for the same eight patterns as the two-tier etched groove above; every other `pattern_type` fails loudly with a clear message rather than falling back to `"raised"` if you select it.
```

Update the "Note on `"teardrop"` and `"intertwine"`" paragraph's opening sentence to make explicit that their etched behaviour predates and is unaffected by this redesign (it currently just describes their CGAL/union quirk without noting this).

### Step 5: Extend `README.md`'s CGAL-fragility section

Following the exact style of the existing per-pattern CGAL paragraphs (`cairo_pentagonal`, `floret_pentagonal`, `deltoidal_trihexagonal`), add a new paragraph (or extend the existing 8 patterns' own paragraphs in place, whichever reads better once Step 3's real results are in hand) reporting: which of the 8 patterns' NEW etched geometry and NEW alternating geometry measured clean vs. aborting, at what `pattern_repeat`/`smoothness` values, on what platform, with the CI-confirmation caveat for anything not yet re-verified against a real Ubuntu run. Do not claim CI-clean for any combination that has only been measured locally -- this project's established convention (stated explicitly in the `intertwine` paragraph already in `README.md`) is that local-macOS-clean is necessary but not sufficient.

### Step 6: Update `docs/gallery.md` and `docs/images/render.sh`

For each of the 8 Phase-1 patterns' existing `### <pattern>` subsection, extend the `| Raised | Etched |` table to `| Raised | Etched | Alternating |` with a third image column, following the exact table-row structure the existing two columns already use. Regenerate every affected image via `docs/images/render.sh` once `render.sh` itself has been extended to know about the new `"alternating"` variant (this task's own job -- read the script fresh, find where it lists raised/etched invocations per pattern, and add a third per the same pattern). Note in each subsection's descriptive paragraph that etched is now a two-tier outline groove (matching the new `README.md` wording), replacing whatever per-pattern-family etched description currently exists there (`tetrakis_square`'s subsection, quoted in this plan's own research above, is a representative example of text that needs rewriting -- "a single flat height across all four with only a thin engraved groove marking the fan lines" becomes "a flat wall cut by a primary groove... plus a secondary groove...", following Step 4's own new README wording).

### Step 7: Check off `TODO.md`

Change:
```
* [ ] "etched" doesn't do what was originally wanted for most patterns -- ...
```
to `* [x] ...` (the full existing text, unmodified -- just the checkbox), and add a new backlog item directly below it:

```
* [ ] Phase 2 of the etched/alternating relief-mode redesign: convert "dots",
  "cubes", "checkers", "bricks" from BOSL2-native heightfields into custom
  islands-based VNF tiles of our own (each is a small, well-understood shape
  -- a circle, an isometric rhombus pair, a 2x2 checker split, a brick
  rectangle), so they can plug into _tile_outline_from_islands()/
  _tile_alternating_from_islands() the same way the other 8 patterns now do.
  "raised" mode for these four is unaffected either way -- only "etched"/
  "alternating" depend on the conversion. See
  docs/superpowers/specs/2026-09-20-relief-mode-redesign-design.md's own
  "Phase 2" section.
```

### Step 8: Run the full test suite locally

```bash
for f in tests/test_decoration_pattern_types.scad \
         tests/test_decoration_etched_groove.scad \
         tests/test_decoration_islamic_star.scad \
         tests/test_decoration_kisrhombille.scad \
         tests/test_decoration_tumbling_cubes.scad \
         tests/test_decoration_rhombille.scad \
         tests/test_decoration_tetrakis_square.scad \
         tests/test_decoration_triakis_triangular.scad \
         tests/test_decoration_cairo_pentagonal.scad \
         tests/test_decoration_floret_pentagonal.scad \
         tests/test_decoration_invalid_relief_mode.scad \
         tests/test_decoration_invalid_alternating_pattern.scad; do
  echo "=== $f ==="
  openscad -o /tmp/relief_redesign_test.csg "$f" || echo "FAIL: $f"
done
```
Expected: every `test_decoration_<name>.scad` and `test_decoration_pattern_types.scad`/`test_decoration_etched_groove.scad` clean (exit 0); the two invalid-input files exit non-zero WITH the expected message (checked separately, per Step 11 of Task 1 and Step 2 of this task -- a bare loop like the one above will misreport them as "FAIL" since they're negative tests, so run those two individually with the message-grep check instead of folding them into this loop).

Then run Step 3's CGAL sweep (or confirm a prior run of it is still valid) and confirm its results match what got written into `README.md`/`.github/workflows/test.yml`.

### Step 9: Commit

```bash
git add tests/test_decoration_etched_groove.scad .github/workflows/test.yml \
        README.md docs/gallery.md docs/images/render.sh TODO.md
git commit -m "Finish relief-mode redesign: test-infra updates, CGAL sweep, docs"
```

---

## Self-Review

**1. Spec coverage:**
- Goal #1 (`"raised"` unchanged) -- every rewired `_foo_tile(relief_mode)`'s final `:` branch is the pre-existing function body verbatim; Tasks 1-6 each call this out explicitly as a step.
- Goal #2 (two-tier outline etched, 8 patterns, `intertwine`/`teardrop` excluded, `dots`/`cubes`/`checkers`/`bricks` deferred) -- Task 1 builds `_tile_outline_from_islands()`; Tasks 1-6 wire all 8 patterns; Global Constraints state the 3 exclusions and 4 deferrals explicitly.
- Goal #3 (`"alternating"`, real bas-relief, single render) -- Task 1 builds `_tile_alternating_from_islands()` with the real `ground_z=0.5` mechanism (Correction 2's exact fix); Tasks 1-6 wire all 8 patterns.
- Goal #4 (assertion, not silent wrong geometry, for unsupported patterns) -- Task 1 Step 6's `ALTERNATING_PATTERNS` assertion.
- Correction 1 (pre-shrink motif groups, not the already-gapped islands list) -- every `_foo_motif_groups()` function builds from ORIGINAL un-shrunk polygons (`_tc_rhombus()`, `_cp_pentagon()`, `_fp_pentagon()`, `_is_star()`/`_is_cross()`, `_kis_raw_fan()`), never from `_kis_shrunk_fan()`'s or the existing raised-mode `offset()`-shrunk output.
- Correction 1b / the edge-classification model itself -- Task 1 Step 4 implements exactly this (`_tile_outline_from_islands()`), with the "why union doesn't work" reasoning preserved verbatim in its own code comment.
- Correction 2 (real `ground_z` for both the ground face and `_tile_walls()`, with the sign-conditional) -- Task 1 Step 3, both functions, the conditional called out explicitly as required (not a plain substitution).
- `group_id`/`alt_key` field contract, and the "kis" family's genuine divergence -- Global Constraints states the contract; Tasks 1, 3, 4 (tetrakis_square, triakis_triangular) and Task 1's kisrhombille section all build `group_id` as a composite/unique-per-fan key distinct from `alt_key`.
- `high_group`/`alt_key` per-pattern derivations from the spec's own "Per-pattern `high_group` choice" section (`tumbling_cubes`/`rhombille`'s 2-group corner/center split, `cairo_pentagonal`/`floret_pentagonal`'s hub-vs-`k` distinction, the "kis" family's composite `group_id`) -- each carried forward into its own task's code and comments, not re-derived or simplified.
- `relief_mode` validation, `RELIEF_MODES` as a separate list from `PATTERN_TYPES` -- Task 1 Step 6.
- `decorated_solid()` wiring (`tex_inset` 3-way ternary) -- Task 1 Step 6.
- Test strategy (Z-level assertions `{0,0.5,1}`, tile-seam invariant including Z, differs-from-both-other-modes, invalid-`relief_mode` negative tests) -- every task's Step 1, and Task 1's two new negative-test files.
- CGAL-fragility sweep discipline and disclosure convention -- Global Constraints states it; Task 7 Step 3 gives the full methodology and this plan's own partial spot-check evidence, explicitly not overclaiming CI-clean.
- Documentation impact (`planter.scad` Customizer comment, `README.md`'s etched rewrite, gallery images, `TODO.md`) -- Task 1 Step 10 (planter.scad, landed early since it's part of the validation proof), Task 7 Steps 4-7.
- Rollout shape (shared builders + validation + 2-3 proof patterns first, then the rest) -- Task 1 is exactly this, with `islamic_star` (simple, `group_id==alt_key`) and `kisrhombille` (the one pattern where they diverge, and the performance-risk case) chosen specifically because together they exercise both builders' full contract.

**2. Placeholder scan:** No "TBD"/"fill in"/"similar to Task N" patterns found. Every code step includes real, complete function bodies grounded in the actual current `modules/decoration.scad` (read in full before this plan was written) or in this plan's own directly-verified research (the 3x3-supertile requirement, the sort-based-matching requirement, the region-union performance bottleneck, the `difference(secondary_union, primary_region)` bracket bug, and the tetrakis_square-has-no-primary-tier case were all discovered by running real OpenSCAD scripts against the real file, not assumed -- the bracket bug specifically was caught by a real CGAL-forcing render of `kisrhombille`'s own etched+alternating tiles failing with a `split_region_at_region_crossings`/"one of the inputs is not a region" error during this plan's own research pass, then fixed and re-verified with a small isolated harness reproducing the actual `ground_z`-aware `_tile_from_islands()`/`_tile_walls()`; the union-performance bottleneck was found by the same kind of direct measurement, and this plan is honest in Task 1 Step 4/Step 12 and Task 7 Step 3 that its own proposed batched-union fallback was NOT fully re-confirmed against the real slow input within this plan-writing pass's own budget -- flagged as open investigation for Task 1's implementer, not asserted as solved). Task 2's `_tc_motif_groups()` carries an inline comment warning about its own easiest-to-get-wrong bracket depth (one group per rhombus vs. the required 2 groups total) rather than showing and retracting a wrong draft, since two near-identical code blocks in one step risks an implementer copying the wrong one.

**3. Type/signature consistency:**
- `_tile_from_islands(islands, ground_z = 0)` / `_tile_walls(path, z, ground_z = 0)` -- same two names, same parameter order, used identically in Task 1's own new callers (`_tile_outline_from_islands()`, `_tile_alternating_from_islands()`) and left untouched for every pre-existing caller.
- `_tile_outline_from_islands(motif_groups, outer_gap, inner_gap, union_batch_size = 8)` -- the first 3 parameters are the exact signature from the spec, used identically in all 8 patterns' `"etched"` branch across Tasks 1-6; `union_batch_size` is Task 1's own added escalation hatch (Step 12) for the region-union performance finding, defaulted so every 3-argument call site is unaffected unless a later task's own timing step needs to override it.
- `_tile_alternating_from_islands(islands, high_group, ground_z = 0.5)` -- exact signature from the spec (`ground_z` added as a defaulted parameter per Correction 2's own suggestion, not a hardcoded literal), used identically in all 8 patterns' `"alternating"` branch.
- `islands` 4-tuple shape `[region, height, group_id, alt_key]` -- consistent across every `_foo_alternating_islands()` function in Tasks 1-6 (verified: `_islamic_star_alternating_islands()`, `_kisrhombille_alternating_islands()`, `_tc_alternating_islands()`, `_tetrakis_square_alternating_islands()`, `_triakis_triangular_alternating_islands()`, `_cairo_pentagonal_alternating_islands()`, `_floret_pentagonal_alternating_islands()` all return this exact 4-element shape).
- Every rewired `_foo_tile()` gains a `relief_mode` parameter where it didn't already have one (`_islamic_star_tile`, `_tumbling_cubes_tile`, `_rhombille_tile`, `_cairo_pentagonal_tile`) -- each corresponding `_decoration_texture()` dispatch-line edit is included in the same task (Task 1 Step 9, Task 2 Step 6, Task 5 Step 4); `_tetrakis_square_tile`, `_kisrhombille_tile`, `_triakis_triangular_tile`, `_floret_pentagonal_tile` already took `relief_mode` before this plan, so their dispatch lines are unchanged (confirmed against the real file, `modules/decoration.scad:753-758`).
- `RELIEF_MODES`/`ALTERNATING_PATTERNS` are defined once (Task 1) and only ever read, never redefined, in every later task.
