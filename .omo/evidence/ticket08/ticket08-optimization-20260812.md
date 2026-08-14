# Ticket 08 optimization evidence

Date: 2026-08-12 (Asia/Seoul)

## Implemented path

- `src/metal/kernels/CBEFFilmEffects.metal`: added packed RG32 half/quarter/eighth planes, one prepare/horizontal/vertical dispatch per scale for all three channels, per-channel sigma factors `{1.20, 1.00, 0.82}`, alpha-normalized numerator/denominator, and one full-resolution composite for each Local/Global branch.
- `src/metal/MetalRenderBackend.mm`: added 256-byte aligned RG32 linear texture views and explicit row/plane strides. FrameArena scratch is reused across branches; no full-resolution per-scale RGBA scratch is allocated.
- `tests/halation_v2_metal_ticket08.mm`: added 1024×576 CPU/Metal energy+centroid parity, 1024×576 and 1025×577 odd-stride/crop checks, all three working modes, all five Halation output views, finite output and crop guards.
- `tests/m7_performance_benchmark.mm`: warm-up baseline is captured after 3 frames; JSON/Markdown now record `scratch_requested_peak`, `scratch_reserved_peak`, `arena_growth_after_warmup`, schema v2, and unavailable power/thermal/GPU-load provenance. Halation uses its dedicated 160 MiB scratch gate.

## RED reproduction and fix

Command before fix:

```text
MTL_DEBUG_LAYER=1 M7_OUTPUT_DIR=.omo/evidence/ticket08/m7-debug-20260812d DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make benchmark-m7
```

Observed failure:

```text
m7 debug nonfinite (1919,776) channel=0 source=0.244968 destination=nan
m7_performance_benchmark: FAIL
```

Cause: the C++ pair buffer length was converted to a radius as `pairs.size()*2-1`; even Gaussian radii then made the Metal pair loop read one element past the pair buffer. The final path uses `(pairs.size()-1)*2`, which keeps the loop count bounded for both odd and even source radii.

## Focused validation

Command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-halation-metal
```

Result:

```text
wide parity channel 0 energy cpu=106.79 metal=100 centroid cpu=(351.872,198.102) metal=(341,192)
wide parity channel 1 energy cpu=55.6792 metal=50 centroid cpu=(358.44,201.788) metal=(341,192)
wide parity channel 2 energy cpu=29.9151 metal=25 centroid cpu=(369.094,207.767) metal=(341,192)
halation_v2_metal_ticket08: PASS
EXIT_CODE:0
```

This run includes the small pixel parity gate, 1024×576 wide aggregate CPU/Metal energy+centroid parity, 1024×576 and 1025×577 odd-stride crop/no-wrap cases, working modes 0/1/2, output views Final/Halation Only/Source Mask/Local Only/Global Only, alpha/transparent guards, and finite output checks.
Captured stdout/stderr: `ticket08-focused-final.log` in this evidence directory.

Scoped regression command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -j3 test-v2-halation-cpu test-v2-halation-metal test-frame-arena test-m1 test-m2 test-v2-compile test-v2-inspector
```

Observed result lines:

```text
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
halation_v2_metal_ticket08: PASS
frame_arena_contract: PASS
headless_render_contract: PASS (CPU + Metal M1 contract)
```

`typed_compile_contract`, `inspector_metadata_contract`, and the affected-target `make build` completed with exit code 0.
Post-Source-Mask regression transcript: `ticket08-post-matte-regression.log`; command exit code was 0.

## M7 performance and memory

Command:

```text
M7_OUTPUT_DIR=.omo/evidence/ticket08/m7-optimization-run-20260812i DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make benchmark-m7
```

The complete M7 process exits non-zero because pre-existing Mist Diffusion 3840×2160 timing is 90.60 ms against its unrelated 83.33 ms gate. The Halation cases pass their dedicated gates:

| Case | Median / average | Scratch requested peak | Scratch reserved peak | Arena growth after warm-up | Result |
|---|---:|---:|---:|---:|---|
| Halation 1920×1080 | 8.7161 ms median | 41,304,064 B | 41,304,064 B | 0 B | PASS |
| Halation 3840×2160 | 50.3528 ms median | 149,323,776 B | 149,323,776 B | 0 B | PASS |

The 4K scratch value is below the Halation limit of 167,772,160 B (160 MiB); timing is below 83.33 ms. The machine-readable artifact is [m7-performance.json](../ticket08/m7-optimization-run-20260812i/m7-performance.json), with Markdown companion [m7-performance.md](../ticket08/m7-optimization-run-20260812i/m7-performance.md). Power/thermal/GPU load is explicitly recorded as unavailable on this host.

## Build artifact

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make build
```

Exit code: 0.
