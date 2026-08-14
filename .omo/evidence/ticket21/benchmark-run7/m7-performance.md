# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket21/benchmark-run7/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T09:52:42Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `66861f5bf645069c880878147ad39b40dea977aed379499babe85e8ae7d801e4` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| lens_reflections | 1920×1080 | 38.76 | 38.68 | 35291136 B | 35291136 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 138.32 | 137.56 | 141017088 B | 141017088 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Grain scratch reserved < 64 MiB, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, Optical scratch reserved < 192 MiB, Lens scratch reserved < 256 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
