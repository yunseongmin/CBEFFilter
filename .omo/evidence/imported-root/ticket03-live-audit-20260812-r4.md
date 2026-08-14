# Ticket 03 live audit, workspace evidence

Date: 2026-08-12
Workspace root: `/Users/younseongmin/Documents/CBEF`
Project: `DaVinciFilmPlugin`

## Commands and results

Executed from the workspace root:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -C DaVinciFilmPlugin -B test-v2-inspector
INSPECTOR_EXIT_CODE=0
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -C DaVinciFilmPlugin -B test
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
ABI_EXIT_CODE=0
```

The affected build freshly compiled the shared render core, Inspector contract, OFX adapter, Metal backend, Frame Arena, OpenFX support, Metal source, and bundle. The Inspector contract ran as `build/tests/inspector_metadata_contract` and exited 0. The wrapper exited 0 because both recorded exit codes were 0.

## Artifacts

```text
build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx
build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib
build/tests/inspector_metadata_contract
build/tests/plugin_abi_probe
```

The ABI probe observed all five stable OpenFX descriptors and the bundled Metal library. Resolve visual Inspector acceptance remains reserved for the project host-acceptance stage.
