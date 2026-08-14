# Ticket 12 direct audit, rerun 3

Date: 2026-08-12
Working directory: `/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin`
Toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

## Current source and issue state

- Issue 12 is `Status: resolved`.
- The focused contract expects 19 parameters, with ticket 12 axes at indices 13–15 and ticket 13 axes at 16–18.
- The current metadata source uses Choice values for `stock_response`, `scan_sampling`, and `processing_modifier`.

## Executed validations

1. `make -B test-v2-grain-stock-cpu`

   Exit code: 0

   ```text
   grain_v2_stock_cpu_contract: PASS
   ```

   The command exercised expanded parameter ordinals/types, generic stock response ordering, capture/scan/processing separation, frame/subframe determinism, endpoint/HDR/alpha/crop behavior, and 8K data-window crop.

2. `make -B test-v2-inspector test`

   Exit code: 0

   ```text
   plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
   ```

   `inspector_metadata_contract` also completed successfully.

3. `make -B build`

   Exit code: 0. The arm64 OpenFX bundle and bundled Metal library rebuilt successfully.

## Residual warning

The focused compile reports one non-fatal warning for unused `kGrainStockSoftness` in `src/core/RenderCore.cpp`. No command failed, and this warning does not invalidate the ticket behavior evidence.

## Judgment

The prior metadata/type blocker and stale focused-test blocker are no longer present. Current evidence supports keeping issue 12 resolved. Ticket 13 remains a separate population/record scope and is not claimed here.
