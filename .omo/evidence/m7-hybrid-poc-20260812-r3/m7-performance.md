# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/m7-hybrid-poc-20260812-r3/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T21:02:23Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `991cb976971168c42ef77e7d4ab2126cc87f4a4934966b92e82edeef9a94cb79` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 17.41 | 17.56 | 132710400 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 10.40 | 10.41 | 109428736 B | 262144 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 1.35 | 1.22 | 0 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 0.83 | 0.98 | 0 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 20.57 | 20.75 | 165937152 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 81.04 | 81.20 | 530841600 B | 0 B | PASS | PASS | PASS |
| film_grain | 3840×2160 | 9.39 | 9.41 | 109166592 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 2.85 | 2.84 | 0 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 2.86 | 2.83 | 0 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 86.14 | 85.64 | 663552000 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
