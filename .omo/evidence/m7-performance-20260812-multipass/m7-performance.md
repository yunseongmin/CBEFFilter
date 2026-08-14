# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/m7-performance-20260812-multipass/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T19:34:18Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `b3b849ad34e95ab98dd1e190b7ed16efecc7042f0c40b8411dd55c4e0ca8a431` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 16.74 | 16.76 | 99532800 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 6.75 | 6.79 | 109428736 B | 262144 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 3.82 | 3.82 | 66355200 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 15.33 | 15.38 | 165888000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 24.63 | 24.92 | 165888000 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 102.02 | 103.02 | 398131200 B | 0 B | FAIL | PASS | FAIL |
| film_grain | 3840×2160 | 9.44 | 9.44 | 109166592 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 29.87 | 29.84 | 265420800 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 77.51 | 80.05 | 663552000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 161.62 | 161.85 | 663552000 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
