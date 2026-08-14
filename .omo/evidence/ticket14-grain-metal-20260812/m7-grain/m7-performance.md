# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket14-grain-metal-20260812/m7-grain/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T07:56:49Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `fd5bf4b33fd3b6279d3c4284de9de5c3524184c76652927c532dd4e12a9616c3` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| film_grain | 1920×1080 | 2017.41 | 2037.76 | 0 B | 0 B | 0 B | FAIL | PASS | FAIL |
| film_grain | 3840×2160 | 7973.72 | 7976.32 | 0 B | 0 B | 0 B | FAIL | PASS | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
