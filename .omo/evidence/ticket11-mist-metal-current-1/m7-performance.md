# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/ticket11-mist-metal-current-1/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T06:39:54Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `febad3933b83887e566469842bb013a84d028e1dfa093b37f8d0acf0de0f12be` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| mist_diffusion | 1920×1080 | 15.51 | 15.57 | 232243200 B | 232243200 B | 0 B | PASS | FAIL | FAIL |
| mist_diffusion | 3840×2160 | 92.50 | 92.53 | 928972800 B | 928972800 B | 0 B | FAIL | FAIL | FAIL |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
