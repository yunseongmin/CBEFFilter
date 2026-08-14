# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket08/m7-optimization-run-20260812i/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T05:43:32Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `70ce15c3f11841f9da78531b4f02212f7776c1462449cb8b3469a46717241ebf` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 8.72 | 8.66 | 41304064 B | 41304064 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 3.92 | 4.01 | 91537408 B | 91537408 B | 0 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 2.12 | 2.18 | 66355200 B | 66355200 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 10.05 | 9.88 | 99532800 B | 99532800 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 13.02 | 13.01 | 0 B | 0 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 50.35 | 50.37 | 149323776 B | 149323776 B | 0 B | PASS | PASS | PASS |
| film_grain | 3840×2160 | 5.76 | 5.80 | 0 B | 0 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 22.44 | 22.37 | 265420800 B | 265420800 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 44.85 | 44.67 | 398131200 B | 398131200 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 90.60 | 90.72 | 0 B | 0 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Halation scratch reserved < 160 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
