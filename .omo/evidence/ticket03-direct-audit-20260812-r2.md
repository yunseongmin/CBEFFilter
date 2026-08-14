# Ticket 03 direct audit, rerun 2

Date: 2026-08-12
Working directory: `/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin`
Toolchain prefix: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

## Direct command evidence

### Affected build and Inspector contract

Invocation:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-inspector
```

Observed final output:

```text
xcrun -sdk macosx metal -c "src/metal/kernels/CBEFFilmEffects.metal" -o "build/obj/metal/CBEFFilmEffects.air"
xcrun -sdk macosx metallib "build/obj/metal/CBEFFilmEffects.air" -o "build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib"
... -o "build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx" ...
"build/tests/inspector_metadata_contract"
```

The process exited 0. The focused binary completed silently, which is its success path. It validates the five stable IDs, Basic/Advanced/Diagnostics grouping and order, typed defaults/ranges/hints, natural preset selection, Working Mode/Output View preservation, Custom transition, and Lens Anamorphism activation condition.

### ABI probe

Invocation:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test
```

Observed final output:

```text
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
```

The process exited 0.

## Artifact identity

```text
c9b171c0639fc8ca7c2e7a64cb7967460e444bf0e56fc21e5907275064d3ab6e  build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx
8afe407f2d604ec34411c55cb43e0a4370b908cbcd5e778dc883f429f077f705  build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib
3e1d3214a2e782d7d990a962065c373e05e1e1de30ca06ed905b3be4e89d8927  build/tests/inspector_metadata_contract
a3982da690c04e51508cc8de819119449f495d2f59b2a384838ff3475f0e4dae  build/tests/plugin_abi_probe
```

`file` identified the bundle and test binaries as arm64 Mach-O and the resource as a MetalLib executable. Resolve visual Inspector acceptance remains outside this ticket and is reserved for the project’s host-acceptance stage.
