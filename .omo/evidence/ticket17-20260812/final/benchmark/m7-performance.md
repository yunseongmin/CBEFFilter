# M7 Metal performance benchmark

Status: passed

Machine-readable result: `.omo/evidence/ticket17-20260812/final/benchmark/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T09:32:25Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `57a1de0b3a9fa075893d81eff945590cccd30c00572f2e4a7d193554474a503e` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| optical_blur | 1920×1080 | 12.10 | 12.70 | 44072960 B | 44072960 B | 0 B | PASS | PASS | PASS |
| optical_blur | 3840×2160 | 48.58 | 48.59 | 176259072 B | 176259072 B | 0 B | PASS | PASS | PASS |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Grain scratch reserved < 64 MiB, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, Optical scratch reserved < 192 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
