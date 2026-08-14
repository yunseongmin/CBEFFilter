# Ticket 08 direct verification run 6 summary

Fresh validation was rerun without M7, as instructed.

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make build
BUILD_EXIT_CODE:0

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-halation-cpu test-v2-halation-metal
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
wide parity channel 0 energy cpu=106.79 metal=100 centroid cpu=(351.872,198.102) metal=(341,192)
wide parity channel 1 energy cpu=55.6792 metal=50 centroid cpu=(358.44,201.788) metal=(341,192)
wide parity channel 2 energy cpu=29.9151 metal=25 centroid cpu=(369.094,207.767) metal=(341,192)
halation_v2_metal_ticket08: PASS
FOCUSED_EXIT_CODE:0

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -j3 test-frame-arena test-m1 test-m2 test-v2-compile test-v2-inspector
frame_arena_contract: PASS
headless_render_contract: PASS (CPU + Metal M1 contract)
halation_render_contract: PASS (CPU + Metal M2 Halation)
REGRESSION_EXIT_CODE:0
```

Source gate confirmed `markBasic` accepts the optional `ParameterRole` argument. Ticket 08 remains `resolved`. Existing M7 performance/memory evidence is intentionally reused from the previous direct run because M7 was not rerun in this continuation.
