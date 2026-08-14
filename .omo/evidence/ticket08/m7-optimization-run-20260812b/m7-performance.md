# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket08/m7-optimization-run-20260812b/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T05:25:29Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `198a68a0e5492ce1f334bdeb5f7bf584f39719e399caeb204e4adca1cf3b73a7` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 19.12 | 19.18 | 24723456 B | 24723456 B | PASS | FAIL | FAIL |
| film_grain | 1920×1080 | 5.04 | 5.08 | 96681984 B | 96681984 B | PASS | FAIL | FAIL |
| optical_blur | 1920×1080 | 3.14 | 3.14 | 66355200 B | 66355200 B | PASS | FAIL | FAIL |
| lens_reflections | 1920×1080 | 15.11 | 15.08 | 99532800 B | 99532800 B | PASS | FAIL | FAIL |
| mist_diffusion | 1920×1080 | 24.22 | 24.28 | 0 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 0.00 | 0.00 | 0 B | 0 B | FAIL | FAIL | FAIL |

Failure: `Halation 3840x2160: Metal output was non-finite or unchanged at sampled pixels`

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
