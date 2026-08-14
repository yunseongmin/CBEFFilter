# Ticket 08 verification run 2

Date: 2026-08-12

## Focused regression execution

Command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -j2 test-v2-halation-cpu test-v2-halation-metal test-frame-arena test-m1
```

Exit code: `0`.

Observed:

```text
halation_v2_metal_ticket08: PASS
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
frame_arena_contract: PASS
headless_render_contract: PASS (CPU + Metal M1 contract)
```

## M7 execution

Command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CBEF_M7_OUTPUT_DIR=.omo/evidence/ticket08-m7-verification-run2 \
CBEF_M7_BUNDLE=build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx \
build/tests/m7_performance_benchmark
```

Exit code: `1` because the benchmark's aggregate gate failed. The complete output is retained in [m7-performance.md](../ticket08-m7-verification-run2/m7-performance.md) and [m7-performance.json](../ticket08-m7-verification-run2/m7-performance.json).

Halation results on Apple M3 Pro, with three warmups and ten measured renders:

| Resolution | Median | Target | Result |
|---|---:|---:|---|
| 1920×1080 | 16.2312 ms | ≤ 41.67 ms | timing pass |
| 3840×2160 | 112.4554 ms | ≤ 83.33 ms | timing fail |

The UHD miss is 29.1254 ms. The bundle hash is `1df54a2d7822e248b8f5217dedf0702d81c5287553cc88d8092135292fd2c8c8`, matching the prior verification bundle. The ticket status remains `needs-triage`; this run does not support a completion claim.
