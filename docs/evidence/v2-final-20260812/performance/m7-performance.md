# M7 Metal performance benchmark

Status: passed

Machine-readable result: [`m7-performance.json`](m7-performance.json)

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T14:42:16Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `895d9019d5e65fc6cbf6b9a7931f5c0bd33d620e59d726b75604513d89672e0d` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| halation | 1920×1080 | 9.72 | 9.80 | 41304064 B | 41304064 B | 0 B | PASS | PASS | PASS |
| film_grain | 1920×1080 | 6.96 | 7.03 | 10715136 B | 10715136 B | 0 B | PASS | PASS | PASS |
| optical_blur | 1920×1080 | 11.67 | 11.72 | 33177600 B | 33177600 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 1920×1080 | 3.20 | 3.23 | 262144 B | 262144 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 1920×1080 | 2.21 | 2.29 | 7372800 B | 7372800 B | 0 B | PASS | PASS | PASS |
| halation | 3840×2160 | 50.92 | 50.86 | 164888576 B | 164888576 B | 0 B | PASS | PASS | PASS |
| film_grain | 3840×2160 | 10.39 | 10.35 | 2801664 B | 2801664 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 47.07 | 47.07 | 132710400 B | 132710400 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 10.86 | 10.85 | 0 B | 0 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 9.95 | 9.74 | 44236800 B | 44236800 B | 0 B | PASS | PASS | PASS |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Grain scratch reserved < 64 MiB, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, Optical scratch reserved < 192 MiB, Lens scratch reserved < 256 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
