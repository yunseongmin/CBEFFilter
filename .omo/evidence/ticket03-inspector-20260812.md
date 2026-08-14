# Ticket 03 Inspector metadata verification

Date: 2026-08-12
Toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

## Scenarios and observables

| Scenario | Invocation | Binary observable | Artifact |
|---|---|---|---|
| Typed settings and Inspector metadata contract | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-compile` followed by `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make build/tests/inspector_metadata_contract && ./build/tests/inspector_metadata_contract` | Both commands exited 0. The focused contract validates five stable IDs, Basic/Advanced/Diagnostics membership and order, hints/units/ranges, natural preset selection, Working Mode/Output View preservation, Custom transition, and lens-model conditional activation. | `build/tests/typed_compile_contract`, `build/tests/inspector_metadata_contract` |
| OFX descriptor build and metadata path | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-inspector` | Bundle linked successfully and the focused Inspector contract exited 0. The OFX adapter compiled the shared `ParameterDefinition` metadata into page/group descriptors, sorted display order, hints, secret flags, defaults, and conditional initial enablement. | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` |
| Stable OpenFX ABI and bundled Metal resource | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test` | `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)`; bundle and probe are arm64 Mach-O binaries. | `build/tests/plugin_abi_probe`, `build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib` |

## Hashes

```text
c9b171c0639fc8ca7c2e7a64cb7967460e444bf0e56fc21e5907275064d3ab6e  build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx
3e1d3214a2e782d7d990a962065c373e05e1e1de30ca06ed905b3be4e89d8927  build/tests/inspector_metadata_contract
a3982da690c04e51508cc8de819119449f495d2f59b2a384838ff3475f0e4dae  build/tests/plugin_abi_probe
```

## Scope note

The actual Resolve Inspector visual acceptance remains ticket 24/25 per project policy. This ticket verifies the shared metadata definition, OFX descriptor compilation path, typed settings behavior, and stable ABI without introducing a fake host.
