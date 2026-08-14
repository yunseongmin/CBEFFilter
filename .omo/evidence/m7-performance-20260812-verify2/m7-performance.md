# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/m7-performance-20260812-verify2/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T19:37:33Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `b3b849ad34e95ab98dd1e190b7ed16efecc7042f0c40b8411dd55c4e0ca8a431` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 18.98 | 19.43 | 99532800 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 6.86 | 6.93 | 109428736 B | 262144 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 3.82 | 3.83 | 66355200 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 15.42 | 15.57 | 165888000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 26.21 | 26.25 | 165888000 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 101.30 | 101.13 | 398131200 B | 0 B | FAIL | PASS | FAIL |
| film_grain | 3840×2160 | 9.42 | 9.43 | 109166592 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 30.07 | 30.18 | 265420800 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 78.72 | 79.49 | 663552000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 161.87 | 163.73 | 663552000 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
