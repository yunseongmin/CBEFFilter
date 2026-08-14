# Ticket 11 direct completion-hook verification

Date: 2026-08-12 UTC

## Structural check

Command:

```sh
rg -n 'MistFusedArguments|mist_.*dual_buffer|if \(false' src/metal || true
```

Observed output: no matches. The active metallib contains the Mist pyramid symbols used by the backend.

## Focused tests

Command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-mist-metal test-m4
```

Observed output:

```text
mist_v2_metal_ticket11: PASS
mist_render_contract: PASS
```

Full log: `direct-hook-verification-20260812.log`.

## Clean performance benchmark

Command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
M7_OUTPUT_DIR=.omo/evidence/ticket11-mist-metal-final/direct-hook-benchmark-20260812 \
make benchmark-mist
```

Observed output: `m7_performance_benchmark: PASS` with 3 warmups and 10 measured samples per resolution.

| Size | Median | Scratch requested/reserved | Arena growth | Result |
|---|---:|---:|---:|---|
| 1920×1080 | 5.7758 ms | 25,804,800 B | 0 B | PASS |
| 3840×2160 | 12.5684 ms | 103,219,200 B | 0 B | PASS |

Machine-readable artifact: `direct-hook-benchmark-20260812/m7-performance.json` (`all_pass: true`). Bundle SHA-256: `ee42b6743a3c9e10ca7fe858c69f6ace41c49886bc9cd4c76b7b3558e72a1f0b`.
