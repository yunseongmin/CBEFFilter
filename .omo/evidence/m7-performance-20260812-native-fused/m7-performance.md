# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/m7-performance-20260812-native-fused/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T20:13:47Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `a64b16dea62b10c8485d98215fe08409c5129c4e5eda9ee44f91a6b323f23804` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 19.64 | 19.30 | 99532800 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 10.64 | 10.31 | 109428736 B | 262144 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 5.49 | 5.47 | 66355200 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 15.46 | 15.72 | 165888000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 18.79 | 18.82 | 165888000 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 85.06 | 84.98 | 398131200 B | 0 B | FAIL | PASS | FAIL |
| film_grain | 3840×2160 | 9.43 | 9.44 | 109166592 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 30.08 | 30.09 | 265420800 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 79.02 | 79.23 | 663552000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 123.39 | 123.19 | 663552000 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
