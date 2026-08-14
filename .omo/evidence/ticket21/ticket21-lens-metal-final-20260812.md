# Ticket 21 — Lens Reflections Metal final evidence

Date: 2026-08-12  
Platform: macOS 26.5.2, Apple M3 Pro, arm64  
Bundle SHA-256: `f3567a2e7bcd53ac0e7d77e430bcad2f098a2304cb90045068ea4081ad36c8e8`

## Focused behavior

- `make -B test-v2-lens-metal`: PASS.
  - Public CPU/Metal seam covers automatic multi-source selection and deterministic tie-breaking, Manual Source, all three Working Modes, Clean/Vintage/Anamorphic profiles, five element solos, Source Map before/after, Ghost Paths, Elements Only, Alpha/RGBA external matte, positive/negative morphology, premultiplied alpha, signed HDR, odd data-window origins, render scales 0.5/1/2, crop/no-wrap/off-screen behavior, deterministic random/reverse seek, and shallow-wide plus tall-narrow 8K/12K correctness guards.
  - Enforced bounds: maximum RGB error `<=2e-4`, mean absolute RGB error `<=2e-5`, centroid delta `<=0.1px`, energy delta `<=0.5%`, and exact identity/alpha/crop bytes.
- `make test-v2-lens-source-cpu test-v2-lens-external-matte-cpu test-v2-lens-elements-cpu test-m6`: PASS.
- `make test-frame-arena`: PASS; allocation-failure cleanup maps to `TemporaryAllocationFailed`, completion-bound reuse is safe, and no in-flight slot is reused.

## Build and unaffected contracts

- Precompiled Metal source and metallib build: PASS.
- `make test-v2-compile test-v2-inspector test`: PASS; typed settings, inspector metadata, five stable OFX descriptors, and bundled metallib ABI are intact.
- Ticket 14 Grain Metal regression: PASS, 48-frame max CPU/Metal error `1.94907188e-05`, mean absolute error `3.72534133e-07`.
- Ticket 17 Optical Metal regression: PASS, max CPU/Metal error `2.38e-06`, mean error `7e-08`; aberration/quality CPU contract also PASS.

## Performance and memory

Canonical reports:

- `.omo/evidence/ticket21/final/m7-performance.json`
- `.omo/evidence/ticket21/final/m7-performance.md`

Three completed warmups preceded ten measured renders on the owned queue.

| Resolution | Median | Average | Scratch reserved | Arena growth | Result |
|---|---:|---:|---:|---:|---|
| 1920×1080 | 5.05 ms | 5.30 ms | 35,618,816 B | 0 B | PASS |
| 3840×2160 | 13.57 ms | 13.56 ms | 141,279,232 B | 0 B | PASS |

Thresholds were 41.67 ms at 1080p, 83.33 ms at UHD, scratch below 256 MiB, and post-warmup arena growth no more than 8 MiB.

## Implementation constraints observed

- One command buffer per render and no backend wait.
- Precompiled metallib only.
- Deterministic two-stage GPU top-8 selection with tile-index tie-breaking; no CPU readback.
- Shared source/matte/half-source resources and one destination-gather projection.
- Full-resolution source pixels remain exact in the large-frame path; only the reflection contribution is projected and upsampled.
- No element-count multiplied full-resolution RGBA buffers.
