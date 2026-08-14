# Ticket 08 verification run 3

Date: 2026-08-12

## Focused tests

Command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -j2 test-v2-halation-cpu test-v2-halation-metal test-frame-arena test-m1
```

Exit code: `0`.

Observed pass lines:

```text
halation_v2_metal_ticket08: PASS
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
frame_arena_contract: PASS
headless_render_contract: PASS (CPU + Metal M1 contract)
```

## Performance test

Command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CBEF_M7_OUTPUT_DIR=.omo/evidence/ticket08-m7-verification-run3 \
CBEF_M7_BUNDLE=build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx \
build/tests/m7_performance_benchmark
```

Exit code: `1` because the aggregate benchmark gate failed. The raw artifacts are [m7-performance.md](../ticket08-m7-verification-run3/m7-performance.md) and [m7-performance.json](../ticket08-m7-verification-run3/m7-performance.json).

Observed Halation medians:

| Resolution | Median | Target | Timing result |
|---|---:|---:|---|
| 1920×1080 | 25.5911 ms | ≤ 41.67 ms | pass |
| 3840×2160 | 192.8765 ms | ≤ 83.33 ms | fail |

`all_pass` is `false`; the UHD miss is 109.5465 ms. The ticket remains `needs-triage`, and no completion or quality-gate claim is made.
