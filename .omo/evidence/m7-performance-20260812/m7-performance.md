# M7 Metal performance benchmark

Status: passed

Machine-readable result: `.omo/evidence/m7-performance-20260812/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T10:00:25Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `3a9794afc848384c345c17e5bd4a7ffc0d0c86f8872ed713f339dfb25a480d3a` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| lens_reflections | 1920×1080 | 4.86 | 5.21 | 35618816 B | 35618816 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 10.80 | 10.72 | 141279232 B | 141279232 B | 0 B | PASS | PASS | PASS |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Grain scratch reserved < 64 MiB, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, Optical scratch reserved < 192 MiB, Lens scratch reserved < 256 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
