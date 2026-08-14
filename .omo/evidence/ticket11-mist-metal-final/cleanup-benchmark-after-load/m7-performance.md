# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket11-mist-metal-final/cleanup-benchmark-after-load/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T07:06:27Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `e86af1c4a9d5207f19ca379c8ae4c92c27cf64e0cd33242ce30cb96914de3c5d` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| mist_diffusion | 1920×1080 | 22.42 | 22.61 | 25804800 B | 25804800 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 171.37 | 171.88 | 103219200 B | 103219200 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
