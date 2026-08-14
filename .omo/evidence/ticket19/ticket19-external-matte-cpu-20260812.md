# Ticket 19 — Lens external matte

Date: 2026-08-12

## Implementation

- `include/cbef/RenderCore.h` keeps `RenderRequest::external_matte` appended after the existing fields and appends `PixelFormat::AlphaFloat32` without renumbering prior values.
- The CPU contract validates optional matte format, dimensions, stride, memory kind, aliasing, and Lens-only use. Alpha and RGBA float mattes use canonical-scale bilinear sampling with zero outside the matte support. RGBA coverage is positive scene-linear luminance multiplied by alpha, with straight and premultiplied association handled equivalently.
- Lens source detection stores pre-matte and matte-limited maps separately. `Source Map` remains the pre-matte diagnostic and `Matte Limited` reports the post-matte map; element energy uses the limited map.
- The Lens OFX descriptor declares an optional `Matte` clip supporting float Alpha and RGBA. The adapter fetches it only when connected and reports explicit host errors for missing or unsupported connected images.

## Verification

Command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build/obj/CBEFFilmEffects.o test-v2-compile test-v2-inspector test-v2-lens-source-cpu test-v2-lens-external-matte-cpu test-m6-cpu test
```

Observed results:

- `lens_external_matte_cpu_contract: PASS (optional matte, canonical sampling, diagnostics, validation)`
- `lens_source_map_cpu_contract: PASS (v2 CPU source map + manual source)`
- `lens_reflections_render_contract: PASS (CPU + Metal M6 Lens Reflections)`
- `typed_compile_contract: PASS`
- `inspector_metadata_contract: PASS`
- `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)`
- OFX object compilation completed successfully.

The focused contract exercises zero, partial, all-one, Alpha and RGBA matte coverage, premultiplied input, non-zero origins, padded strides, odd crop windows with sentinel preservation, render scales 0.5/1/2, diagnostic pre/post separation, and invalid stride rejection.

## Final post-refactor verification

Command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build/obj/core/RenderCore.o build/obj/CBEFFilmEffects.o test-v2-compile test-v2-inspector test-v2-lens-source-cpu test-v2-lens-external-matte-cpu test-m6-cpu test
```

Evidence files:

- `.omo/evidence/ticket19/final-validation.log`
- `.omo/evidence/ticket19/final-validation.exit` (`0`)

The final run rebuilt the shared RenderCore and OFX object after the matte morphology ordering fix, rebuilt the bundle and Metal library, and again observed the focused matte/source-map, typed, Inspector, M6 CPU+Metal, and ABI PASS lines above.
