# Ticket 12 verification

Date: 2026-08-12
Toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

## Implemented behavior

- Existing parameter storage IDs and ordinals remain stable. `format` is presented as Capture Format, `size` as Display Scale, and only `stock_response`, `scan_sampling`, and `processing_modifier` are appended at indices 13–15.
- Capture format controls the canonical capture diameter, scan sampling controls film-plane sampling, and Display Scale controls apparent diameter. Stock Response owns generic RMS/softness behavior and Processing Modifier owns generic push/pull gain. No measured manufacturer profile is claimed.
- CPU synthesis continues to use the public `render(RenderRequest, CpuRenderBackend)` seam, existing counter-based frame/seed determinism, half-away frame quantization, data-window height normalization, transparent alpha handling, signed/HDR preservation, and render-window bounds.

## Evidence commands and observables

| Scenario | Invocation | Observable |
|---|---|---|
| Focused v2 CPU contract | `make -B test-v2-grain-stock-cpu` | `grain_v2_stock_cpu_contract: PASS`; metadata, stock RMS ordering, format/scan independence, processing monotonicity, random seek/subframe quantization, endpoint/HDR/crop, and true 4320-line data-window crop pass |
| Existing Grain contract | `make -B test-m3-cpu` | `film_grain_render_contract: PASS`; 48-frame determinism/statistics, normalized resolution spectrum, alpha/crop/Metal parity remain green |
| Typed compilation | `make -B test-v2-compile` | `typed_compile_contract` exits 0 |
| Inspector metadata | `make -B test-v2-inspector` | `inspector_metadata_contract` exits 0 |
| Plugin build | `make -B build` | arm64 OpenFX bundle and bundled Metal library build successfully |
| ABI regression | `make -B test` | `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)` |

Raw combined output: `validation.log`; exit code: `validation.exit`.
