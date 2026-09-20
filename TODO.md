* [x] Preset insert sizes: 100x85 (75mm bottom); 130x120 (100mm bottom); 180x160 (125mm bottom)
* [x] Add interlocking teardrop (from BOSL2)
* [x] I like the way shapes are raised. I don't know what etched does. I wanted it to have an engraved look - like it was etched into stone or glass.
* [x] I would love to include interlocking geometric patterns. I saved some examples to the Desktop. More: https://www.magnific.com/free-photos-vectors/geometric-interlocking-pattern
* [x] Include example images in the README
* [ ] More interlocking geometric pattern ideas (planar Euclidean uniform tilings, not spherical/hyperbolic) -- see https://en.wikipedia.org/wiki/List_of_Euclidean_uniform_tilings, https://en.wikipedia.org/wiki/Uniform_tiling, https://en.wikipedia.org/wiki/List_of_tessellations. In progress, batched 2-3 at a time:
  - The 11 Euclidean uniform tilings exhaust the edge-to-edge regular/semiregular options: triangular, square, hexagonal, truncated square, snub square, trihexagonal, truncated hexagonal, rhombitrihexagonal, truncated trihexagonal, snub trihexagonal, elongated triangular.
  - Their duals add visually distinct candidates, especially good fits for the Islamic/Escher interlocking aesthetic:
    - [x] Tetrakis square tiling ("V4.8^2") -- batch 1, shares a "kis" (centroid-fan) helper with Kisrhombille and Triakis triangular
    - [x] Kisrhombille tiling ("V4.6.12") -- batch 1, reuses tumbling_cubes' existing hexagon/rhombus math
    - [x] Triakis triangular tiling ("V3.12^2") -- batch 1
    - [x] Rhombille tiling ("V3.6.3.6", diamond/rhombus motif) -- batch 2, reuses tumbling_cubes' hexagon math directly
    - [x] Cairo pentagonal tiling ("V3^2.4.3.4", distinctive interlocking pentagons -- probably the most visually striking one) -- batch 2
    - [ ] Prismatic pentagonal tiling ("V3^3.4^2") -- batch 3
    - [x] Floret pentagonal tiling ("V3^4.6", pinwheel-like pentagon clusters) -- batch 3
    - [ ] Deltoidal trihexagonal tiling ("V3.4.6.4", kite-shaped motif) -- batch 3
  - (Excluded on purpose: the apeirogonal hosohedron/order-2 apeirogonal tiling and their prism/antiprism/dual variants from the same Wikipedia list -- these involve infinite-sided polygons and aren't practical decorative motifs for a finite tile.)
* [ ] "etched" doesn't do what was originally wanted for most patterns -- the goal was
  the outline of each shape engraved into the planter (flat surface, thin incised line
  tracing the motif), like it was etched into stone or glass. That's only actually true
  for "ridges"/"pyramids"/"diamonds" (and "hex_grid"/"tri_grid", which shift the same
  panel/groove relief inward) -- those keep a flat panel and cut a thin V-groove along
  the outline. Every other pattern's "etched" instead sinks the WHOLE shape as a
  recessed copy of the raised relief (a dimple/recess, or for "rhombille"/
  "cairo_pentagonal"/"tumbling_cubes"/"islamic_star" a true inverted copy of the entire
  raised motif, not just its outline; the "kis" family and "floret_pentagonal" are a
  third case -- a separate flat panel with only a thin groove BETWEEN facets, which is
  closer to the outline idea but traces facet boundaries within the motif, not the
  motif's own outer silhouette). Needs a real design pass on what "etched" should mean
  for each pattern family, not just the current mode-independent-vs-mode-dependent
  split -- possibly a genuine third relief style (flat wall + thin V-groove along each
  motif's outer boundary only) distinct from both "raised" and the current "etched".
* [ ] "bricks" pattern_type looks like a basket weave (too square/wide per brick), especially at lower pattern_repeat -- confirmed the root cause: BOSL2's "bricks" heightfield hardcodes exactly one brick per tile width (only 2 brick-rows per tile height, offset for the running-bond look), so brick width is set entirely by pattern_repeat. Doubling pattern_repeat was tried and bricks are still about twice as wide as wanted. Needs either (a) a "bricks"-specific horizontal-density multiplier decoupled from pattern_repeat (similar to how the "kis" family patterns get their own independent constants), or (b) a custom hand-rolled brick tile with more than one brick per unit-tile-width, rather than relying on BOSL2's built-in "bricks"/"bricks_vnf" textures.
