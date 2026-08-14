# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket08/m7-optimization-run-20260812h/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T05:38:24Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `4dd120e53bb12816af512f3cfcdf0f2b9237ff25786e4bfc2eb02322b6fbe1bd` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 9.43 | 9.61 | 41304064 B | 41304064 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 3.82 | 3.94 | 91537408 B | 91537408 B | 0 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 2.10 | 2.18 | 66355200 B | 66355200 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 9.76 | 9.64 | 99532800 B | 99532800 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 12.94 | 12.89 | 0 B | 0 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 49.68 | 49.59 | 149323776 B | 149323776 B | 0 B | PASS | PASS | PASS |
| film_grain | 3840×2160 | 5.97 | 5.96 | 0 B | 0 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 22.03 | 21.93 | 265420800 B | 265420800 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 44.40 | 44.43 | 398131200 B | 398131200 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 91.72 | 91.67 | 0 B | 0 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Halation scratch reserved < 160 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
