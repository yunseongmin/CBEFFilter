# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket08-m7-verification-run3/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T05:09:43Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `1df54a2d7822e248b8f5217dedf0702d81c5287553cc88d8092135292fd2c8c8` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 25.59 | 25.94 | 16613376 B | 16613376 B | PASS | FAIL | FAIL |
| film_grain | 1920×1080 | 4.77 | 4.76 | 100352000 B | 100352000 B | PASS | FAIL | FAIL |
| optical_blur | 1920×1080 | 3.14 | 3.15 | 66355200 B | 66355200 B | PASS | FAIL | FAIL |
| lens_reflections | 1920×1080 | 13.89 | 14.12 | 99532800 B | 99532800 B | PASS | FAIL | FAIL |
| mist_diffusion | 1920×1080 | 20.82 | 20.88 | 0 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 192.88 | 193.62 | 0 B | 0 B | FAIL | PASS | FAIL |
| film_grain | 3840×2160 | 7.40 | 7.34 | 0 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 30.17 | 30.04 | 265420800 B | 265420800 B | PASS | FAIL | FAIL |
| lens_reflections | 3840×2160 | 72.32 | 72.25 | 398131200 B | 398131200 B | PASS | FAIL | FAIL |
| mist_diffusion | 3840×2160 | 144.87 | 145.65 | 0 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
