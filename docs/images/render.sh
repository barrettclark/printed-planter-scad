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
# on every single render of those three patterns (plus a milder variant for
# the "kis" family -- tetrakis_square/kisrhombille/triakis_triangular -- which
# share the same defensive warning but have measured CGAL-clean everywhere
# tested) as a proactive notice. Either warning is normal and means nothing
# went wrong on its own.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/docs/images"

# Install cleanup before creating anything that needs cleaning up, not
# after: if `mktemp` below failed while `set -e` is active, exiting between
# creating $LOCK and installing this trap would leave $LOCK behind forever
# (every later invocation would report a false "already running" and refuse
# to proceed until someone deletes it by hand). $TMP and $LOCK are declared
# empty first so this trap is safe to fire even if it runs before either is
# actually set -- `rm -rf ""` is a no-op, not an error, under `set -u`.
#
# $LOCK_OWNED gates the $LOCK removal specifically: this trap also fires
# when THIS invocation fails to acquire the lock (mkdir below exits nonzero
# because another render.sh already holds it), and unconditionally removing
# $LOCK in that case would delete the OTHER run's lock out from under it,
# reopening the exact stale-clone race the lock exists to prevent. Only the
# invocation that actually created the lock (mkdir succeeded) may remove it.
TMP=""
LOCK=""
LOCK_OWNED=""
trap '[ -n "$LOCK_OWNED" ] && rm -rf "$LOCK"; rm -rf "$TMP"' EXIT

# Two concurrent invocations would each clone $OUT into their own $STAGE at
# start time; if one publishes and then the other publishes its (now stale)
# clone, the first run's images silently vanish. `mkdir` on a path that
# doesn't yet exist is atomic on every POSIX filesystem, which makes it a
# portable mutex without needing `flock` -- not present on macOS, which is
# exactly the platform this script has to run on without extras (see the
# bash-3.2 note below).
LOCK="$ROOT/docs/.render-lock"
# `if ! VAR=$(cmd); then` (not a bare assignment) for the same `set -e`
# reason as the PATTERN_TYPES extraction below: a bare failing assignment
# would exit the script before this diagnostic could run. Capturing stderr
# instead of discarding it also fixes a second problem: `mkdir` fails for
# reasons other than "the lock already exists" (a read-only or unwritable
# docs/, for instance), and blindly reporting all of them as "another
# render.sh is running" would send someone to delete a lock that was never
# actually stale.
if ! MKDIR_ERR="$(mkdir "$LOCK" 2>&1)"; then
    echo "FATAL: could not create lock directory $LOCK:" >&2
    echo "       $MKDIR_ERR" >&2
    echo "       If another render.sh is already running, wait for it to finish." >&2
    echo "       If this is stale from a run that crashed, remove it by hand." >&2
    exit 1
fi
LOCK_OWNED=1
# Only the lock holder may create $OUT. Doing this before lock acquisition
# let a second invocation recreate $OUT as an empty directory while the
# first was mid-publish (the brief window between its two `mv`s where $OUT
# is legitimately absent); the first invocation's second `mv "$STAGE" "$OUT"`
# then found $OUT already existing and, per plain `mv` semantics, moved
# $STAGE INSIDE it (docs/images/stage/*.png) instead of replacing it,
# silently corrupting the published gallery with exit 0. Confirmed this
# exact nesting behavior directly: `mv sourcedir existing_empty_dir` leaves
# existing_empty_dir/sourcedir, not existing_empty_dir's contents replaced.
mkdir -p "$OUT"
# $TMP lives under $OUT's own parent, not the system tmpdir: `mv` (rename) is
# only guaranteed atomic within a single filesystem, and $TMPDIR can be a
# different filesystem from the repo (e.g. tmpfs on Linux) -- staging here
# instead means the publish step below is a real same-filesystem rename, not
# a cross-filesystem copy-then-delete that could be interrupted partway.
TMP="$(mktemp -d "$ROOT/docs/.render-tmp.XXXXXX")"

# $OLD is set just before the publish step's two renames (below). If this
# script is interrupted in the brief window between them -- $OUT already
# renamed away, $STAGE not yet renamed into place -- $OUT would be left
# missing. Ctrl-C (SIGINT), a plain `kill` (SIGTERM), and a closed terminal
# or dropped SSH session (SIGHUP) are all catchable, so recover() puts $OLD
# back the moment any of them arrives, same as the explicit check after the
# second mv already does for an ordinary command failure. SIGKILL and power
# loss are NOT catchable by any process, so this can't cover every possible
# interruption -- but even then nothing is lost:
# $OLD survives under docs/.render-tmp.*/old (the EXIT trap that would
# delete it never runs on SIGKILL either), so the previous gallery is still
# recoverable by hand with `mv docs/.render-tmp.*/old docs/images`.
OLD=""
recover() {
    if [ -n "$OLD" ] && [ ! -d "$OUT" ] && [ -d "$OLD" ]; then
        mv "$OLD" "$OUT"
    fi
}
trap 'recover; exit 130' INT
trap 'recover; exit 143' TERM
trap 'recover; exit 129' HUP

# STAGE starts as a full clone of the current docs/images/ -- EVERY file in
# it, not just the *.png renders. This directory also holds render.sh itself
# (this very script) and .gitignore's carve-out comment; cloning only *.png
# would silently delete those the moment the swap below replaces the whole
# directory with STAGE. A filtered run's untouched images (and everything
# non-PNG) ride along unchanged; each render() call overwrites just the
# name(s) it produces. Publishing is then a single same-filesystem rename of
# the whole directory, swapping straight from "old complete state" to "new
# complete state" with no window where docs/images/ holds a mix of old and
# new -- a per-file mv loop can't offer that no matter how carefully it's
# ordered, since some files are moved before others.
STAGE="$TMP/stage"
mkdir -p "$STAGE"
cp -a "$OUT"/. "$STAGE"/

# --- close-up geometry -------------------------------------------------------
#
# A straight cylinder whose height is exactly its own circumference, so
# tex_reps=[n,n] lays down SQUARE tiles -- the flat-tile shot the gallery leads
# with, free of even the small residual cone-taper effect (tiles are only
# exactly square at the pot's mean radius; roughly 0.87x-1.17x at its actual
# top/bottom radii at shipped defaults) that the real (conical) pot applies
# (see docs/gallery.md, "Full-Pot Examples").
CU_R=90
CU_H=565.4867        # 2 * pi * 90
CU_REPS=32           # 32 tiles around 565mm of circumference -> ~17.7mm tiles
CU_DEPTH=1.5         # planter.scad's shipped pattern_depth default
CU_WALL=10           # only feeds decorated_solid()'s depth < 0.7*wall assert
CU_FN=60             # planter.scad's shipped smoothness default
# Orthographic, so there is no perspective taper across the frame, and off-axis
# by ~25 degrees in both azimuth and elevation. Dead-on, OpenSCAD's
# camera-mounted light hits every flat plateau at the same angle and patterns
# built from flat islands (islamic_star, tumbling_cubes, intertwine) wash out to
# near-invisible outlines. 25/25 rakes the light across the relief while
# compressing both axes by about the same cos(25)=0.91, so tile aspect is
# essentially preserved.
CU_CAMERA="53.6,-115.0,341.9,0,0,282.7"
CU_IMG="800,800"

# Read straight from modules/decoration.scad's own PATTERN_TYPES rather than
# keeping a second hardcoded copy here -- a hardcoded list would silently omit
# a future pattern_type's gallery renders if someone added one without also
# remembering to update this file.
printf 'include <%s/modules/decoration.scad>\nfor (p = PATTERN_TYPES) echo(p);\n' "$ROOT" \
    > "$TMP/list_patterns.scad"
# Run this synchronously into a real file first, checked for its own exit
# status, rather than piping straight into the `while read` below via
# process substitution: `while ... done < <(cmd)` does NOT propagate cmd's
# exit status to the enclosing shell (`$?` after the loop reflects the loop
# itself, not the process-substituted command), so if openscad printed a few
# ECHO lines and then crashed partway, PATTERN_TYPES would come out
# non-empty-but-incomplete and the empty-check below would never fire --
# silently publishing a gallery missing whatever patterns came after the
# crash point.
LIST_OUT="$TMP/list_patterns.out"
# set +e / capture $? / set -e, same as render() below: with `set -e` still
# active, a bare failing command exits the script immediately -- BEFORE the
# next line's `list_code=$?` ever runs -- so the exit-status check two lines
# down would be unreachable for the very failure it exists to catch.
# Confirmed directly: `set -e; false; code=$?; echo "reached"` never prints
# "reached". This needs to be a non-strict context for the one line.
set +e
openscad -o "$TMP/list_patterns.csg" "$TMP/list_patterns.scad" > "$LIST_OUT" 2>&1
list_code=$?
set -e
# Checking the exit code alone isn't enough here either: confirmed by testing
# directly that OpenSCAD's .csg export exits 0 even when the file being
# compiled hits a real assertion failure partway through (the same
# exit-0-on-error behavior this script already works around for CGAL
# failures elsewhere) -- so an error partway through the PATTERN_TYPES loop
# would leave list_code at 0 with a truncated but nonempty ECHO list. Check
# for the literal ERROR string too, same convention as render()'s own checks.
if [ $list_code -ne 0 ] || grep -q "ERROR" "$LIST_OUT"; then
    echo "FATAL: could not evaluate modules/decoration.scad to list PATTERN_TYPES" >&2
    echo "       (exit $list_code, or ERROR in output):" >&2
    cat "$LIST_OUT" >&2
    exit 1
fi
# `while read` array-append, not `mapfile`/`readarray`: those were added in
# bash 4.0, and macOS ships bash 3.2 as /bin/bash for licensing reasons (only
# a `brew install bash` gets you newer, and that's not on $PATH by default).
# `#!/usr/bin/env bash` at the top of this file resolves to whatever's first
# in the invoking user's PATH, which is 3.2 on a stock Mac -- `mapfile` would
# fail outright there before rendering a single image.
PATTERN_TYPES=()
while IFS= read -r pt; do
    PATTERN_TYPES+=("$pt")
done < <(grep '^ECHO:' "$LIST_OUT" | sed -E 's/^ECHO: "(.*)"$/\1/')
if [ ${#PATTERN_TYPES[@]} -eq 0 ]; then
    echo "FATAL: could not read PATTERN_TYPES from modules/decoration.scad" >&2
    exit 1
fi

# --- render helper -----------------------------------------------------------
# Optional name prefixes to restrict this run to. A filtered run goes through
# the same code path (and the same CGAL check) as a full run, so the image(s)
# it does render use exactly the current settings in this file, not some
# earlier version of them. It does NOT guard against gallery-wide drift the
# other direction: if a shared setting here, or something in
# modules/decoration.scad, changes, a filtered run only refreshes the names
# you asked for -- every other already-committed image keeps reflecting
# whatever was true when IT was last generated. Re-run with no filter after
# any shared change to bring the whole gallery back in sync.
FILTERS=("$@")
MATCHED=0
RENDERED=()

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
    MATCHED=$((MATCHED + 1))
    echo "=== $name ==="
    local out code
    set +e
    # Write into $TMP (scratch), not $STAGE or $OUT directly: only a render
    # that passes every check below gets moved into $STAGE. $TMP (and
    # everything under it, including $STAGE) is wiped by the EXIT trap
    # regardless of how the script ends, so a failed or interrupted run
    # never touches $OUT at all -- the actual publish into $OUT is a single
    # directory-rename swap at the very end of the script, once every
    # selected render has succeeded.
    out=$(openscad --render -o "$TMP/$name.png" "$@" 2>&1)
    code=$?
    set -e
    echo "$out"
    if [ $code -ne 0 ]; then
        echo "FATAL: openscad exited $code for $name" >&2
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
        exit 1
    fi
    if grep -q "ERROR:" <<< "$out"; then
        echo "FATAL: ERROR in openscad output for $name" >&2
        exit 1
    fi
    if [ ! -s "$TMP/$name.png" ]; then
        echo "FATAL: $TMP/$name.png is missing or empty" >&2
        exit 1
    fi
    mv "$TMP/$name.png" "$STAGE/$name.png"
    RENDERED+=("$name")
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
    for rel in "${reliefs[@]}"; do
        render "pattern-$pt-$rel" \
            --projection=o --imgsize="$CU_IMG" --camera="$CU_CAMERA" \
            -D "pt=\"$pt\"" -D "rel=\"$rel\"" "$TMP/tile.scad"
    done
done

# --- full-assembly shots -----------------------------------------------------
#
# Shipped defaults for pattern_repeat (16) and smoothness (60): the combination
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

if [ ${#FILTERS[@]} -gt 0 ] && [ "$MATCHED" -eq 0 ]; then
    echo "FATAL: no image name matched any of: ${FILTERS[*]} -- a typo'd filter" >&2
    echo "       would otherwise leave stale committed PNGs while this script" >&2
    echo "       reports success. Check the name against docs/gallery.md." >&2
    exit 1
fi

# Publish: every selected render passed every check above (a failure exits
# the whole script before this line runs), so $STAGE now holds the complete,
# correct gallery -- the untouched files it started as a clone of, plus this
# run's fresh renders overwriting their names. Swap it in with two whole-
# directory renames rather than looping mv per file: each rename is a single
# atomic same-filesystem syscall (see $TMP above), so there's no point in the
# swap where docs/images/ could be observed holding a mix of old and new
# files the way a per-file loop would allow. These are two renames, not one,
# though -- $OUT is genuinely absent for the instant between them. `recover()`
# (defined near the top, alongside its own commentary on what it can and
# can't catch) is wired to INT/TERM for exactly that window; here, an ordinary
# command failure on the second mv is checked explicitly rather than left to
# `set -e`, for the same reason -- letting `set -e` exit would hand off to
# the EXIT trap, which unconditionally `rm -rf`s $TMP, deleting $OLD (which
# lives under it) along with everything else and destroying the previously-
# committed gallery with nothing left in its place.
OLD="$TMP/old"
mv "$OUT" "$OLD"
if ! mv "$STAGE" "$OUT"; then
    echo "FATAL: could not publish to $OUT; restoring the previous gallery" >&2
    recover
    exit 1
fi

echo
echo "All renders complete and CGAL-clean: $OUT ($MATCHED image(s) rendered)"
