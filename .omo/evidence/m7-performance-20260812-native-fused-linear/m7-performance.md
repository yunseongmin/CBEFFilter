# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/m7-performance-20260812-native-fused-linear/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T20:14:22Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `271116a65468ecac3e15de27b5790034f5f31457e585d25c3a26c85796ab6242` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 19.79 | 19.78 | 99532800 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 7.89 | 8.19 | 109428736 B | 262144 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 3.91 | 3.89 | 66355200 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 15.19 | 15.20 | 165888000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 18.86 | 19.40 | 165888000 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 85.58 | 85.52 | 398131200 B | 0 B | FAIL | PASS | FAIL |
| film_grain | 3840×2160 | 9.46 | 9.47 | 109166592 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 30.12 | 30.03 | 265420800 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 77.00 | 77.63 | 663552000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 122.95 | 122.72 | 663552000 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
