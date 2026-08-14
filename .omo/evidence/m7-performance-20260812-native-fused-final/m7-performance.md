# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/m7-performance-20260812-native-fused-final/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T20:17:57Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `b471818ac21ca368181bdff7632341effa5f79ca3d6275506d2d461916d3ef90` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 21.79 | 21.62 | 200540160 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 6.58 | 6.60 | 109428736 B | 262144 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 3.73 | 3.74 | 66355200 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 15.10 | 15.20 | 165888000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 24.10 | 24.23 | 267386880 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 127.80 | 127.63 | 802160640 B | 0 B | FAIL | PASS | FAIL |
| film_grain | 3840×2160 | 9.51 | 9.51 | 109166592 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 30.03 | 30.04 | 265420800 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 77.59 | 77.12 | 663552000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 182.69 | 183.06 | 1069547520 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
