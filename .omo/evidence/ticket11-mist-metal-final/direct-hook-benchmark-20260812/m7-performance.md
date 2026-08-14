# M7 Metal performance benchmark

Status: passed

Machine-readable result: `.omo/evidence/ticket11-mist-metal-final/direct-hook-benchmark-20260812/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T07:12:12Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `ee42b6743a3c9e10ca7fe858c69f6ace41c49886bc9cd4c76b7b3558e72a1f0b` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| mist_diffusion | 1920×1080 | 5.78 | 5.79 | 25804800 B | 25804800 B | 0 B | PASS | PASS | PASS |
| mist_diffusion | 3840×2160 | 12.57 | 12.68 | 103219200 B | 103219200 B | 0 B | PASS | PASS | PASS |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
