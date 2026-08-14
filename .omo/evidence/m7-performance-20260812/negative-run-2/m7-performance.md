# M7 Metal performance benchmark

Status: failed

Machine-readable result: `.omo/evidence/m7-performance-20260812/negative-run-2/m7-performance.json`

| Item | Value |
|---|---|
| Generated (UTC) | 2026-08-11T19:32:28Z |
| macOS | 26.5.2 |
| GPU | Apple M3 Pro |
| Bundle | `.omo/evidence/m7-performance-20260812/negative-run-2/missing.ofx` |
| Bundle SHA-256 | `missing` |

Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.

| Effect | Size | Median (ms) | Average (ms) | Temp peak | Steady delta | Timing | Memory | Pass |
|---|---:|---:|---:|---:|---:|---|---|---|

Failure: `bundle binary is missing; build the bundle before running M7 benchmark`

Thresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, temporary peak < 1 GiB, steady allocation increase ≤ 8 MiB.
