# Ticket 03 direct audit, rerun 3

Date: 2026-08-12
Working directory: `/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin`
Toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

## Executed commands

The following wrapper ran both commands and returned a combined exit code of 0:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-inspector
INSPECTOR_EXIT_CODE=0
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test
ABI_EXIT_CODE=0
```

The Inspector build output included fresh compilation of `RenderCore.cpp`, `inspector_metadata_contract.cpp`, `CBEFFilmEffects.cpp`, Metal backend, Frame Arena, OpenFX support, Metal source compilation, bundle linking, and execution of `build/tests/inspector_metadata_contract`. The focused contract exited 0.

The ABI output ended with:

```text
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
ABI_EXIT_CODE=0
```

## Artifact hashes

```text
efbeee35f641ff6314382b54224d2831a06de4299e42d006fc85f532b2caa2ed  build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx
8afe407f2d604ec34411c55cb43e0a4370b908cbcd5e778dc883f429f077f705  build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib
3e1d3214a2e782d7d990a962065c373e05e1e1de30ca06ed905b3be4e89d8927  build/tests/inspector_metadata_contract
a3982da690c04e51508cc8de819119449f495d2f59b2a384838ff3475f0e4dae  build/tests/plugin_abi_probe
```

The focused contract covers shared metadata and typed-setting behavior; the ABI probe covers all five stable effect identifiers and the bundled Metal resource. Actual Resolve visual Inspector acceptance remains reserved for the host-acceptance ticket.
