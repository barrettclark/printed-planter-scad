* [x] Preset insert sizes: 100x85 (75mm bottom); 130x120 (100mm bottom); 180x160 (125mm bottom)
* [x] Add interlocking teardrop (from BOSL2)
* [x] I like the way shapes are raised. I don't know what etched does. I wanted it to have an engraved look - like it was etched into stone or glass.
* [x] I would love to include interlocking geometric patterns. I saved some examples to the Desktop. More: https://www.magnific.com/free-photos-vectors/geometric-interlocking-pattern
* [x] Include example images in the README
* [ ] More interlocking geometric pattern ideas (planar Euclidean uniform tilings, not spherical/hyperbolic) -- see https://en.wikipedia.org/wiki/List_of_Euclidean_uniform_tilings, https://en.wikipedia.org/wiki/Uniform_tiling, https://en.wikipedia.org/wiki/List_of_tessellations. In progress, batched 2-3 at a time:
  - The 11 Euclidean uniform tilings exhaust the edge-to-edge regular/semiregular options: triangular, square, hexagonal, truncated square, snub square, trihexagonal, truncated hexagonal, rhombitrihexagonal, truncated trihexagonal, snub trihexagonal, elongated triangular.
  - Their duals add visually distinct candidates, especially good fits for the Islamic/Escher interlocking aesthetic:
    - [ ] Tetrakis square tiling ("V4.8^2") -- batch 1, shares a "kis" (centroid-fan) helper with Kisrhombille and Triakis triangular
    - [ ] Kisrhombille tiling ("V4.6.12") -- batch 1, reuses tumbling_cubes' existing hexagon/rhombus math
    - [ ] Triakis triangular tiling ("V3.12^2") -- batch 1
    - [ ] Rhombille tiling ("V3.6.3.6", diamond/rhombus motif) -- batch 2, reuses tumbling_cubes' hexagon math directly
    - [ ] Cairo pentagonal tiling ("V3^2.4.3.4", distinctive interlocking pentagons -- probably the most visually striking one) -- batch 2
    - [ ] Prismatic pentagonal tiling ("V3^3.4^2") -- batch 3
    - [ ] Floret pentagonal tiling ("V3^4.6", pinwheel-like pentagon clusters) -- batch 3
    - [ ] Deltoidal trihexagonal tiling ("V3.4.6.4", kite-shaped motif) -- batch 3
  - (Excluded on purpose: the apeirogonal hosohedron/order-2 apeirogonal tiling and their prism/antiprism/dual variants from the same Wikipedia list -- these involve infinite-sided polygons and aren't practical decorative motifs for a finite tile.)
