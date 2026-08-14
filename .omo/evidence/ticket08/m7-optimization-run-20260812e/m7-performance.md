# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket08/m7-optimization-run-20260812e/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T05:28:15Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `96ae57e0ae102b451173377dca6b1dd2ff6d6a152a1a833c84afc2bf6f6a24c5` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 19.36 | 19.34 | 24723456 B | 24723456 B | PASS | FAIL | FAIL |
| film_grain | 1920×1080 | 5.25 | 5.22 | 96681984 B | 96681984 B | PASS | FAIL | FAIL |
| optical_blur | 1920×1080 | 2.98 | 3.15 | 66355200 B | 66355200 B | PASS | FAIL | FAIL |
| lens_reflections | 1920×1080 | 14.97 | 15.09 | 99532800 B | 99532800 B | PASS | FAIL | FAIL |
| mist_diffusion | 1920×1080 | 23.54 | 23.51 | 0 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 109.98 | 109.98 | 49774592 B | 49774592 B | FAIL | FAIL | FAIL |
| film_grain | 3840×2160 | 7.81 | 7.91 | 0 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 33.27 | 33.44 | 265420800 B | 265420800 B | PASS | FAIL | FAIL |
| lens_reflections | 3840×2160 | 74.37 | 74.70 | 398131200 B | 398131200 B | PASS | FAIL | FAIL |
| mist_diffusion | 3840×2160 | 151.00 | 151.27 | 0 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
