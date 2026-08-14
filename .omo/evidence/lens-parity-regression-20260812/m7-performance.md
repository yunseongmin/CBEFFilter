# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/lens-parity-regression-20260812/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T21:22:13Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `29c89da940142293ab3b1b804868359e9de87767333b02093bb695ec9070b280` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 15.01 | 15.06 | 132710400 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 7.47 | 7.39 | 109428736 B | 262144 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 3.70 | 3.69 | 66355200 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 15.10 | 15.20 | 165888000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 18.55 | 18.90 | 165888000 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 78.79 | 79.29 | 530841600 B | 0 B | PASS | PASS | PASS |
| film_grain | 3840×2160 | 9.34 | 9.36 | 109166592 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 30.02 | 30.13 | 265420800 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 78.19 | 78.23 | 663552000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 121.61 | 122.20 | 663552000 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
