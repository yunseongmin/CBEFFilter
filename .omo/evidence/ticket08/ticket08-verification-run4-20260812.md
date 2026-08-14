# Ticket 08 direct verification run 4

Date: 2026-08-12

## Build and focused suites

Command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-halation-metal
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-halation-cpu
```

Observed:

```text
BUILD_EXIT_CODE:0
wide parity channel 0 energy cpu=106.79 metal=100 centroid cpu=(351.872,198.102) metal=(341,192)
wide parity channel 1 energy cpu=55.6792 metal=50 centroid cpu=(358.44,201.788) metal=(341,192)
wide parity channel 2 energy cpu=29.9151 metal=25 centroid cpu=(369.094,207.767) metal=(341,192)
halation_v2_metal_ticket08: PASS
METAL_EXIT_CODE:0
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
CPU_EXIT_CODE:0
```

Full stdout/stderr is in `ticket08-verification-run4-20260812.md` (this file is the captured transcript).

## M7

Command:

```text
M7_OUTPUT_DIR=.omo/evidence/ticket08/m7-verification-run4-20260812 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make benchmark-m7
```

`make` returned exit code 2 because the complete suite includes the pre-existing Mist 3840×2160 timing failure. Direct JSON inspection produced:

```text
SCHEMA_VERSION: 2
POWER_THERMAL_GPU_LOAD: unavailable
ALL_PASS: False
HALATION 1920 1080 MEDIAN_MS 8.9474 SCRATCH_REQUESTED 41304064 SCRATCH_RESERVED 41304064 ARENA_GROWTH 0 PASS True
HALATION 3840 2160 MEDIAN_MS 50.5454 SCRATCH_REQUESTED 149323776 SCRATCH_RESERVED 149323776 ARENA_GROWTH 0 PASS True
MIST_4K_MEDIAN_MS 94.778 PASS False
```

Raw benchmark JSON/Markdown: `.omo/evidence/ticket08/m7-verification-run4-20260812/m7-performance.json` and `.omo/evidence/ticket08/m7-verification-run4-20260812/m7-performance.md`. The shell transcript was captured during this verification run.

## Existing regression binaries

Command:

```text
build/tests/frame_arena_contract
build/tests/headless_render_contract
build/tests/halation_render_contract
build/tests/typed_compile_contract
build/tests/inspector_metadata_contract
```

All five existing binaries returned exit code 0. The M2 Halation binary took several minutes of CPU time and was allowed to complete; it ended with:

```text
halation_render_contract: PASS (CPU + Metal M2 Halation)
EXIT_CODE:0
```

## Current build blocker discovered during regression rebuild

The attempted parallel rebuild command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -j3 test-frame-arena test-m1 test-m2 test-v2-compile test-v2-inspector
```

returned exit code 2 due unrelated current `src/core/RenderCore.cpp` errors:

```text
src/core/RenderCore.cpp:260:9: error: no matching function for call to object of type 'const (lambda at src/core/RenderCore.cpp:193:28)'
src/core/RenderCore.cpp:261:9: error: no matching function for call to object of type 'const (lambda at src/core/RenderCore.cpp:193:28)'
```

The failing calls pass a third `ParameterRole::Quality` argument to `markBasic`, whose current lambda accepts only `(const char*, int)`. This is outside Ticket 08 ownership and was not modified. Existing binaries above still pass, but a fresh full rebuild cannot be claimed green until that external compile error is resolved.
