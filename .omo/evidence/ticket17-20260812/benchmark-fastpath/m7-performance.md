# M7 Metal performance benchmark

Status: passed

Machine-readable result: `.omo/evidence/ticket17-20260812/benchmark-fastpath/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T09:27:16Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `7d1e23785dc86f66b7a6ecde922a0c211379ad538ea243d4c7a3b81d67342f83` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| optical_blur | 1920×1080 | 12.14 | 12.54 | 44072960 B | 44072960 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 48.71 | 48.99 | 176259072 B | 176259072 B | 0 B | PASS | PASS | PASS |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Grain scratch reserved < 64 MiB, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
