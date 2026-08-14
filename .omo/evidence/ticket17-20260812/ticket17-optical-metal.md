# Ticket 17 Optical Metal sampling evidence

Date: 2026-08-12

## Implementation

- The compiled Optical plan resolves Preview, Balanced, and Final to deterministic 24, 64, and 128 sample prefixes.
- CPU and Metal consume the same host-generated aperture sequence. Field profile, Center / Rim bias, Cat-eye, coma, astigmatism, Field Focus Bias, chromatic aberration, vignetting, highlight response, and all Optical diagnostic views remain active.
- The sampling model uses full-resolution prepared `float4` data plus packed half, quarter, and eighth levels. The full-to-half model changes continuously across 4–8 px, with continuous later pyramid transitions.
- Metal uses the bundled precompiled library, one command buffer, FrameArena completion ownership, and no host wait.
- The default zero-dispersion path combines RGB at one coordinate without disabling any enabled control. Non-zero chromatic aberration retains the channel-specific path.

## Focused verification

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build test-v2-optical-metal test-v2-optical-field-cpu test-v2-compile test-v2-inspector test-frame-arena test`

- V2 CPU/Metal matrix: maximum pixel error `0.00000238`, mean pixel error `0.00000007`.
- Matrix coverage: 24/64/128 sample modes; Final, Optical Blurred Image, Optical Highlight Component, PSF Preview, and Highlight Source Map views; strong field profile, Cat-eye, coma, astigmatism, focus bias, chromatic aberration, and vignetting controls.
- 8K correctness: active Optical render on a 7680×4320 data window with a cropped render window completed, remained finite, preserved alpha, and retained crop sentinels.
- The CPU transition suite passed adjacent 4–8 px energy, centroid, and normalized second-moment bounds, plus 1080/UHD render-scale, signed HDR, transparent edge, odd-dimension, no-wrap, and crop contracts.
- Bundle build, typed compiler, Inspector metadata, FrameArena, legacy M5, and plugin ABI all passed. The affected build emitted no warnings.

Raw log: [`final/focused-build-tests.log`](final/focused-build-tests.log)

## Performance and memory

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer M7_OUTPUT_DIR=.omo/evidence/ticket17-20260812/final/benchmark make benchmark-optical`

Measured on Apple M3 Pro after three completed warmups and ten measured frames:

| Size | Median | Limit | Scratch requested / reserved | Limit | Arena growth |
|---|---:|---:|---:|---:|---:|
| 1920×1080 | 12.10 ms | 41.67 ms | 44,072,960 B | 192 MiB | 0 B |
| 3840×2160 | 48.58 ms | 83.33 ms | 176,259,072 B | 192 MiB | 0 B |

Artifacts: [`final/benchmark/m7-performance.json`](final/benchmark/m7-performance.json), [`final/benchmark/m7-performance.md`](final/benchmark/m7-performance.md), [`final/benchmark.log`](final/benchmark.log).

Runtime source-compilation scans found no source-library creation path in `src/core` or `src/metal`.
