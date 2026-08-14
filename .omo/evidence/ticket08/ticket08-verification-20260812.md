# Ticket 08 direct verification

Verification date: 2026-08-12

## Regression/build command

Invocation:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -j2 build test-v2-halation-cpu test-v2-halation-metal test-frame-arena test-m1 test-v2-compile test-v2-inspector test
```

Observed command result: `EXIT_CODE:0`.

Observed pass lines:

```text
halation_v2_metal_ticket08: PASS
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
frame_arena_contract: PASS
headless_render_contract: PASS (CPU + Metal M1 contract)
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
```

## Direct M7 performance command

Invocation:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CBEF_M7_OUTPUT_DIR=.omo/evidence/ticket08-m7-verification \
CBEF_M7_BUNDLE=build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx \
build/tests/m7_performance_benchmark
```

Observed command result: `EXIT_CODE:1`; the benchmark correctly reports `m7_performance_benchmark: FAIL`.

The benchmark output itself is retained at [m7-performance.md](../ticket08-m7-verification/m7-performance.md) and [m7-performance.json](../ticket08-m7-verification/m7-performance.json). It confirms three warmups and ten measured renders on Apple M3 Pro. Halation median was 17.1343 ms at 1920×1080 and 131.2731 ms at 3840×2160. The UHD target is 83.33 ms, so the timing gate fails by 47.9431 ms. `all_pass` is `false`.

## Judgment

The implementation and focused safety/parity checks are reproducibly green, but the ticket is not complete because the required UHD Halation timing gate is not met. The ticket remains `needs-triage`; no performance or quality gate was weakened.
