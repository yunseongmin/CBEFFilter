# Ticket 20 — Lens signed-axis elements CPU verification

Date: 2026-08-12  
Result: PASS

## Delivered behavior

- Compiled `GhostElementPlan[5]` for Generic Clean, Generic Vintage, and Generic Anamorphic profiles.
- Profile elements span both signed sides of the optical center and are not constrained to a universal `k=-1` reflection.
- Focused, aperture Disc, aperture Ring, broad Veil, and directional Streak shapes have independent energy, defocus, falloff, spectral tint, dispersion, and background response.
- Focused projection retains source-local structure with the public NCC gate `>= 0.75`.
- `Ghost Paths`, `Elements Only`, and `Element Solo` are distinct public render outputs; the five solo renders reconstruct all elements within `2e-4` per channel.
- One-pixel source movement is continuous, each profile's element energy stays within the `±3%` budget, bright-background impact is reduced, and off-screen contribution is finite-reach/no-wrap.
- Signed HDR, alpha-bit preservation, non-zero-origin crop, padded rows, and crop sentinels pass through the public CPU render seam.

## Verification

The final affected-target run completed with exit status 0:

- `test-v2-lens-elements-cpu`: PASS
- `test-v2-lens-source-cpu`: PASS
- `test-v2-lens-external-matte-cpu`: PASS
- `test-v2-compile`: PASS
- `test-v2-inspector`: PASS
- `test-m6-cpu`: PASS
- plugin bundle build: PASS
- plugin ABI probe: PASS (`five stable OpenFX effect descriptors + bundled Metal library`)

Metal element projection and CPU/Metal parity remain Ticket 21 scope.
