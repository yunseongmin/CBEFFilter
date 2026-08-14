# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket08-m7/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T05:01:05Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `1df54a2d7822e248b8f5217dedf0702d81c5287553cc88d8092135292fd2c8c8` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 16.34 | 16.35 | 16613376 B | 16613376 B | PASS | FAIL | FAIL |
| film_grain | 1920×1080 | 3.81 | 3.83 | 100352000 B | 100352000 B | PASS | FAIL | FAIL |
| optical_blur | 1920×1080 | 2.08 | 2.13 | 66355200 B | 66355200 B | PASS | FAIL | FAIL |
| lens_reflections | 1920×1080 | 9.57 | 9.70 | 99532800 B | 99532800 B | PASS | FAIL | FAIL |
| mist_diffusion | 1920×1080 | 12.67 | 12.70 | 0 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 111.12 | 111.29 | 0 B | 0 B | FAIL | PASS | FAIL |
| film_grain | 3840×2160 | 5.65 | 5.59 | 0 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 21.89 | 21.88 | 265420800 B | 265420800 B | PASS | FAIL | FAIL |
| lens_reflections | 3840×2160 | 43.24 | 43.19 | 398131200 B | 398131200 B | PASS | FAIL | FAIL |
| mist_diffusion | 3840×2160 | 88.84 | 89.03 | 0 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
