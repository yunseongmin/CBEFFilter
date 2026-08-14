# Ticket 12 direct audit, rerun 2

Date: 2026-08-12
Toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

## Focused CPU contract

Command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-grain-stock-cpu
```

Result: exit 0, output ended with:

```text
grain_v2_stock_cpu_contract: PASS
```

The test now checks the expanded 19-parameter definition, appended indices 13–18, Choice scan sampling, generic stock/processing choices, determinism, crop/HDR/alpha/endpoints, and 8K data-window crop.

## Inspector and ABI

Command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-inspector test
```

Result: exit 0. `inspector_metadata_contract` completed and the ABI probe reported:

```text
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
```

## Affected build

Command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build
```

Result: exit 0. The arm64 bundle and bundled Metal library were rebuilt. One non-fatal warning remains for unused `kGrainStockSoftness` in `src/core/RenderCore.cpp`.

## Current issue state

The prior metadata/type divergence is resolved by the shared Grain update: `stock_response` is Choice Generic Fine/Balanced/Fast; `scan_sampling` is Choice 2K/4K/8K Equivalent; `processing_modifier` is Choice Generic Normal/Gentle/Generic Enhanced (Uncalibrated). The focused suite now passes, so the prior `needs-triage` blocker is no longer supported by current evidence; issue 12 should be updated to resolved by the owning workflow.
