# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket08/m7-optimization-run-20260812f/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T05:30:55Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `4dd120e53bb12816af512f3cfcdf0f2b9237ff25786e4bfc2eb02322b6fbe1bd` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 8.61 | 8.65 | 41304064 B | 41304064 B | PASS | FAIL | FAIL |
| film_grain | 1920×1080 | 3.91 | 4.01 | 91537408 B | 91537408 B | PASS | FAIL | FAIL |
| optical_blur | 1920×1080 | 2.19 | 2.23 | 66355200 B | 66355200 B | PASS | FAIL | FAIL |
| lens_reflections | 1920×1080 | 9.94 | 9.86 | 99532800 B | 99532800 B | PASS | FAIL | FAIL |
| mist_diffusion | 1920×1080 | 13.07 | 13.05 | 0 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 49.95 | 49.80 | 149323776 B | 149323776 B | PASS | FAIL | FAIL |
| film_grain | 3840×2160 | 5.73 | 5.84 | 0 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 22.18 | 22.16 | 265420800 B | 265420800 B | PASS | FAIL | FAIL |
| lens_reflections | 3840×2160 | 44.82 | 44.71 | 398131200 B | 398131200 B | PASS | FAIL | FAIL |
| mist_diffusion | 3840×2160 | 89.73 | 89.76 | 0 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
