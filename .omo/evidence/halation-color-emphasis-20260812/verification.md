# Halation Color Emphasis Verification

Date: 2026-08-12

## Public seams

- `EffectDefinition` and typed `Settings` expose append-only Halation controls and presets.
- `render(RenderRequest, CpuRenderBackend)` is the CPU behavioral seam.
- The same typed `RenderRequest` submitted to `MetalRenderBackend` is the GPU parity seam.
- Inspector grouping, labels, ordering, hints, and preset visibility are checked through metadata consumed by the OFX adapter.

## Compiled color model

The existing profile-relative result `P` remains unchanged. The UI choice is compiled once on the CPU into a unit-luminance target and a mix coefficient; Metal never interprets the raw choice ordinal.

`Y(r,g,b) = 0.27411851r + 0.87363190g - 0.14775041b`

`T = tint / Y(tint)`

`C = P + (Y(P)T - P)s`

Targets before normalization:

- Profile Relative: bypass (`s = 0`), preserving the pre-feature math and output bits.
- Film Red: `(1.00, 0.16, 0.04)`
- Warm Amber: `(1.00, 0.55, 0.12)`
- Neutral White (Artistic): `(1.00, 1.00, 1.00)`

The normalized target and the profile-relative result share the same scene-linear luminance. Full-strength Neutral White is therefore achromatic without clipping or changing alpha. The Inspector explicitly identifies it as an artistic optical bloom/glare hybrid rather than measured film halation.

## TDD evidence

- RED: `red-cpu-contract.txt` records the focused CPU contract failing because `color_emphasis` and `color_strength` did not yet exist.
- GREEN: the retained tests lock append-only parameter placement, the first three preset ordinals, Profile Relative hexadecimal float output, red/amber ordering, neutral chroma, luminance-energy stability, signed HDR, bit-preserved alpha, crop isolation, and CPU–Metal parity.

## Verification results

| Command | Result |
| --- | --- |
| `make test-v2-halation-cpu` | PASS |
| `make test-v2-halation-metal` on the Apple GPU | PASS; all three new modes remain within `4e-4` of CPU |
| `make test-m2` on the Apple GPU | PASS |
| `make test-v2-compile` | PASS |
| `make test-v2-inspector` | PASS |
| `make build` | PASS |
| `make test` | PASS; five stable OpenFX descriptors and bundled Metal library |
| `codesign --verify --deep --strict build/CBEFFilmEffects.ofx.bundle` | PASS |

Built artifact hashes:

- OFX binary: `6608bb00eec950b85becce9451401e3a9842961805da7dc985cfb9b4b88d51af`
- Metal library: `7ab96347d2757f2fc3f5dd4695e0a381bf79213ce74944335f00e56bd3c80cbb`

No full `verify-v2` run was performed here; the parent integration pass owns that single final run.
