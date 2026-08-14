# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/m7-performance-mps-poc-20260812/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T20:39:19Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `c81fd617cb57f8dd9aeecda25b78789114afb3a2f3a20fc0ee0c36170de01ec5` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 17.09 | 17.12 | 132710400 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 8.69 | 8.85 | 109428736 B | 262144 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 4.08 | 4.09 | 66355200 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 15.23 | 15.29 | 165888000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 18.61 | 18.60 | 165888000 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 78.69 | 78.66 | 530841600 B | 0 B | PASS | PASS | PASS |
| film_grain | 3840×2160 | 9.43 | 9.42 | 109166592 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 29.93 | 29.91 | 265420800 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 78.73 | 78.92 | 663552000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 121.92 | 122.28 | 663552000 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
