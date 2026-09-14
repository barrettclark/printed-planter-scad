#!/usr/bin/env bash
#
# Regenerates every image in docs/gallery.md. Run from anywhere:
#
#     ./docs/images/render.sh              # everything (~10-15 minutes)
#     ./docs/images/render.sh outer- pot-  # only images whose name starts with
#                                          # one of these prefixes
#
# Close-ups come from decorated_solid() on its own; the full-assembly shots
# come from planter.scad with -D overrides, i.e. exactly what a Customizer
# user gets.
#
# WHY THE `CGAL error` GREP BELOW IS NOT OPTIONAL: "tumbling_cubes",
# "intertwine" and "islamic_star" abort CGAL at some pattern_repeat/smoothness
# combinations (README.md, "Note on the interlocking patterns and CGAL"), and
# when that happens OpenSCAD still exits 0 and still writes a plausible-looking
# PNG. The console string is the only signal, so a render whose output contains
# it is a hard failure here -- shipping the image anyway would put a corrupted
# mesh in the docs under the name of a working pattern.
#
# Do NOT widen that grep to "WARNING": decorated_solid() echoes a WARNING line
# on every single render of those three patterns as a proactive notice. It is
# normal and means nothing went wrong.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/docs/images"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$OUT"

# --- close-up geometry -------------------------------------------------------
#
# A straight cylinder whose height is exactly its own circumference, so
# tex_reps=[n,n] lays down SQUARE tiles -- the flat-tile shot the gallery leads
# with, free of the ~3.2x horizontal stretch the real pot applies (see
# docs/gallery.md, "Full-Pot Examples").
CU_R=90
CU_H=565.4867        # 2 * pi * 90
CU_REPS=32           # 32 tiles around 565mm of circumference -> ~17.7mm tiles
CU_DEPTH=1.5         # planter.scad's shipped pattern_depth default
CU_WALL=10           # only feeds decorated_solid()'s depth < 0.7*wall assert
CU_FN=80             # planter.scad's shipped smoothness default
# Orthographic, so there is no perspective taper across the frame, and off-axis
# by ~25 degrees in both azimuth and elevation. Dead-on, OpenSCAD's
# camera-mounted light hits every flat plateau at the same angle and patterns
# built from flat islands (islamic_star, tumbling_cubes, intertwine) wash out to
# near-invisible outlines. 25/25 rakes the light across the relief while
# compressing both axes by about the same cos(25)=0.91, so tile aspect is
# essentially preserved.
CU_CAMERA="53.6,-115.0,341.9,0,0,282.7"
CU_IMG="800,800"

PATTERN_TYPES=(none ridges diamonds hex_grid pyramids bricks checkers dots
               cubes tri_grid teardrop tumbling_cubes intertwine islamic_star)

# --- render helper -----------------------------------------------------------
# Optional name prefixes to restrict this run to. Partial re-runs go through the
# same code path (and the same CGAL check) as a full run, so a single re-rendered
# image can't silently drift from the settings the rest of the gallery uses.
FILTERS=("$@")

wanted() {
    [ ${#FILTERS[@]} -eq 0 ] && return 0
    local f
    for f in "${FILTERS[@]}"; do
        # Match either the full output name (e.g. "pot-", "outer-", "preset-",
        # or "pattern-islamic_star" as a prefix) or a bare pattern_type name
        # against its "pattern-<type>-<relief>" close-up name -- every pattern
        # is referred to by its bare name throughout the rest of this page, so
        # `render.sh islamic_star` needs to work, not just `render.sh
        # pattern-islamic_star`.
        case "$1" in "$f"*) return 0 ;; esac
        case "$1" in pattern-"$f"-*) return 0 ;; esac
    done
    return 1
}

render() {
    local name="$1"; shift
    wanted "$name" || return 0
    echo "=== $name ==="
    local out code
    set +e
    out=$(openscad --render -o "$OUT/$name.png" "$@" 2>&1)
    code=$?
    set -e
    echo "$out"
    # A failed render must not leave a bad or half-written PNG behind for a
    # later `git add docs/images/` to pick up -- every failure path below
    # removes it before exiting. For a partial re-run (e.g. `render.sh
    # islamic_star`) this deletes a previously-good committed image on
    # failure rather than leaving it in place -- deliberate: a loud deletion
    # `git status` will show is safer than a stale-but-good file silently
    # masking a real regression.
    if [ $code -ne 0 ]; then
        echo "FATAL: openscad exited $code for $name" >&2
        rm -f "$OUT/$name.png"
        exit 1
    fi
    # Both are silent-corruption signals: OpenSCAD 2021.01 exits 0 and writes
    # the PNG regardless.
    #
    # Use a here-string, not `echo "$out" | grep`: under `set -o pipefail`,
    # piping a large $out into `grep -q` (which exits the instant it finds a
    # match) can make `echo` receive SIGPIPE and exit 141 before it finishes
    # writing -- and pipefail then reports the PIPELINE as failed even though
    # grep matched, so this whole check would silently skip exactly the
    # large-verbose-output case (a real CGAL failure) it exists to catch. A
    # here-string has no pipe and no second process, so there's nothing to
    # race.
    if grep -q "CGAL error" <<< "$out"; then
        echo "FATAL: CGAL error while rendering $name -- the PNG it just wrote is" >&2
        echo "       from an aborted evaluation and must not be shipped. Nudge" >&2
        echo "       pattern_repeat or smoothness for this pattern and re-run." >&2
        rm -f "$OUT/$name.png"
        exit 1
    fi
    if grep -q "ERROR:" <<< "$out"; then
        echo "FATAL: ERROR in openscad output for $name" >&2
        rm -f "$OUT/$name.png"
        exit 1
    fi
    if [ ! -s "$OUT/$name.png" ]; then
        echo "FATAL: $OUT/$name.png is missing or empty" >&2
        rm -f "$OUT/$name.png"
        exit 1
    fi
}

# --- pattern close-ups -------------------------------------------------------
#
# One decorated_solid() per render, never two in a union(): "teardrop" and
# "intertwine" abort CGAL when union()ed with any other textured solid.
cat > "$TMP/tile.scad" <<EOF
include <$ROOT/modules/decoration.scad>
pt = "none";
rel = "raised";
decorated_solid(pt, "vertical", rel, $CU_DEPTH, $CU_REPS, $CU_R, $CU_R, $CU_H, $CU_WALL, $CU_FN);
EOF

for pt in "${PATTERN_TYPES[@]}"; do
    reliefs=(raised etched)
    # "none" has no texture at all, so relief_mode cannot change anything.
    [ "$pt" = "none" ] && reliefs=(raised)
    # "checkers" and "cubes" are their own inverse: recessing the motif yields
    # the identical tiling shifted half a tile, so the etched render is
    # indistinguishable from the raised one. Rendering it would only add a
    # duplicate image to the repo -- docs/gallery.md says so in prose instead.
    case "$pt" in checkers|cubes) reliefs=(raised) ;; esac
    for rel in "${reliefs[@]}"; do
        render "pattern-$pt-$rel" \
            --projection=o --imgsize="$CU_IMG" --camera="$CU_CAMERA" \
            -D "pt=\"$pt\"" -D "rel=\"$rel\"" "$TMP/tile.scad"
    done
done

# --- full-assembly shots -----------------------------------------------------
#
# Shipped defaults for pattern_repeat (16) and smoothness (80): the combination
# README documents as clean for all three fragile patterns, and the one a
# Customizer user actually gets.
POT_CAMERA="0,0,75,62,0,25,620"
POT_IMG="800,800"

pot() {
    local name="$1"; shift
    render "$name" --imgsize="$POT_IMG" --camera="$POT_CAMERA" "$@" "$ROOT/planter.scad"
}

# Full-pot examples. hex_grid in both relief modes is the aspect-ratio exhibit
# (its hexagons are visibly squashed against the square-tile close-up above);
# islamic_star shows what a large-motif pattern looks like once wrapped.
pot pot-hex_grid-raised   -D 'pattern_type="hex_grid"'     -D 'relief_mode="raised"'
pot pot-hex_grid-etched   -D 'pattern_type="hex_grid"'     -D 'relief_mode="etched"'
pot pot-islamic_star-raised -D 'pattern_type="islamic_star"' -D 'relief_mode="raised"'

# Insert presets, all on one fixed camera (no --viewall) so the three sizes are
# directly comparable rather than each normalised to fill the frame.
for preset in small medium large; do
    pot "preset-$preset" -D "insert_preset=\"$preset\""
done

# Outer shape modes, same camera so the silhouette is the only difference.
#
# The custom shot deliberately does NOT use planter.scad's stock
# outer_top_d/outer_bottom_d/outer_height (172/130/145). Those are tuned to sit
# just outside the default insert, so a render of them is almost pixel-identical
# to "follow" and the pair teaches nothing. A straight-sided, taller shell is
# the case custom mode actually exists for: an outer silhouette that does not
# track the insert's taper at all.
pot outer-follow -D 'outer_mode="follow"'
pot outer-custom -D 'outer_mode="custom"' \
    -D 'outer_top_d=180' -D 'outer_bottom_d=180' -D 'outer_height=175'

echo
echo "All renders complete and CGAL-clean: $OUT"
