# M7 Metal performance benchmark

Status: passed

Machine-readable result: `.omo/evidence/ticket21/final/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-12T10:15:13Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Power / thermal / GPU load | unavailable |
| Bundle | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Bundle SHA-256 | `f3567a2e7bcd53ac0e7d77e430bcad2f098a2304cb90045068ea4081ad36c8e8` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---:|---|---|---|
| lens_reflections | 1920×1080 | 5.05 | 5.30 | 35618816 B | 35618816 B | 0 B | PASS | PASS | PASS |
| lens_reflections | 3840×2160 | 13.57 | 13.56 | 141279232 B | 141279232 B | 0 B | PASS | PASS | PASS |

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Grain scratch reserved < 64 MiB, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, Optical scratch reserved < 192 MiB, Lens scratch reserved < 256 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.
