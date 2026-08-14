# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/m7-hybrid-poc-20260812-r2/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T21:00:40Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `980593cbd7b85b3383f5e5ce7d30665368179f408f8ed21bd3719a01c46308b5` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 13.75 | 14.16 | 132710400 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 7.50 | 7.47 | 109428736 B | 262144 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 1.19 | 1.11 | 0 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 0.75 | 1.04 | 0 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 13.13 | 13.11 | 165937152 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 79.10 | 79.83 | 530841600 B | 0 B | PASS | PASS | PASS |
| film_grain | 3840×2160 | 9.44 | 9.47 | 109166592 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 2.81 | 2.78 | 0 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 2.87 | 2.81 | 0 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 91.13 | 91.39 | 663552000 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
