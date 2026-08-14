# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/m7-performance-20260812-native-fused-tiled/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T20:20:50Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `a0fb40aa25a54ffee90388d3d8b9fffbf3dee95688dcd5f566c619bfdc081415` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 17.15 | 17.29 | 200540160 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 6.55 | 6.56 | 109428736 B | 262144 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 3.62 | 3.61 | 66355200 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 14.90 | 14.95 | 165888000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 27.85 | 27.84 | 267386880 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 122.81 | 121.92 | 802160640 B | 0 B | FAIL | PASS | FAIL |
| film_grain | 3840×2160 | 9.43 | 9.43 | 109166592 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 30.67 | 30.62 | 265420800 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 75.85 | 76.32 | 663552000 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 188.18 | 187.48 | 1069547520 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
