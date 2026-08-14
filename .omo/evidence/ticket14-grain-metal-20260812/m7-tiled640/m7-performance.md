# M7 Metal performance benchmark

Status: passed

Machine-readable result: `.omo/evidence/ticket14-grain-metal-20260812/m7-tiled640/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T08:10:08Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `b0a150ed6e4c48d30d7b15cf5edd6b98d5598067d8971c16ad091ed121be3c2e` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| film_grain | 1920×1080 | 8.06 | 9.64 | 24231936 B | 24231936 B | 0 B | PASS | PASS | PASS |
| film_grain | 3840×2160 | 21.77 | 20.88 | 0 B | 0 B | 0 B | PASS | PASS | PASS |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
