# Ticket 11 direct completion-hook verification 3

Date: 2026-08-12 UTC

## Focused test command

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-mist-metal test-m4
```

Observed output:

```text
mist_v2_metal_ticket11: PASS
mist_render_contract: PASS
```

## Benchmark command

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
M7_OUTPUT_DIR=.omo/evidence/ticket11-mist-metal-final/direct-hook-benchmark-3-20260812 \
make benchmark-mist
```

Observed output: `m7_performance_benchmark: PASS`, with 3 warmups and 10 measured samples per resolution.

| Size | Median | Scratch requested/reserved | Arena growth | Result |
|---|---:|---:|---:|---|
| 1920×1080 | 5.7841 ms | 25,804,800 B | 0 B | PASS |
| 3840×2160 | 12.8275 ms | 103,219,200 B | 0 B | PASS |

Machine-readable artifact: `direct-hook-benchmark-3-20260812/m7-performance.json` (`all_pass: true`). Bundle SHA-256: `46756dad24743ce5871adecbb270d105be51a42c61be4cf1f50382dd6b6d562c`.

Raw logs: `direct-hook-verification-3-20260812.log`, `direct-hook-benchmark-3-20260812.log`.
