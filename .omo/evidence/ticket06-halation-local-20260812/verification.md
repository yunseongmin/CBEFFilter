# Ticket 06 — Halation Local CPU Reference Verification

Date: 2026-08-12

## Scope

Ticket 06 adds scene-reactive source isolation, background-aware local halo composition, and CPU-only diagnostic behavior. Metal v2 implementation and CPU/Metal parity are intentionally deferred to ticket 08.

## Observed scenarios

| Scenario | Invocation | Binary observable | Result |
|---|---|---|---|
| Source controls and diagnostics | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-halation-cpu` | `build/tests/halation_v2_cpu_contract` checks Basic/Advanced controls, Generic/Uncalibrated preset labels, Source Mask and Local Only entries | PASS |
| Source response | same invocation | Neutral, tungsten, blue LED, saturated red exposure sweeps are monotonic and each reaches the Source Mask without a threshold jump above the internal continuity envelope | PASS |
| Local composition | same invocation | Local Only has exterior energy, protected neutral core energy is at most 10% of the exterior probe, and Halation Only equals Local Only while global remains deferred | PASS |
| Background adaptation | same invocation | The same source has lower annulus energy against a bright background than a dark background | PASS |
| CPU safety and scale | same invocation | signed HDR, premultiplied alpha, transparent RGB, non-zero origin, crop, row padding, no-wrap edge and two resolution renders complete with finite RGB and bit-identical alpha | PASS |
| Typed compiler regression | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-compile` | `build/tests/typed_compile_contract` exits 0 | PASS |
| Inspector and affected bundle | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-inspector` | `build/tests/inspector_metadata_contract` exits 0 and `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` links | PASS |
| Affected package build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make build` | `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` remains buildable | PASS |

## Focused suite output

```text
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
```

## Completion re-verification

The following command was rerun after the completion check requested fresh evidence:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-halation-cpu && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-compile && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-inspector && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make build
```

Exit status: `0`

Captured stdout:

```text
"build/tests/halation_v2_cpu_contract"
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
"build/tests/typed_compile_contract"
"build/tests/inspector_metadata_contract"
```

The final `make build` target was up to date and emitted no additional stdout; a zero exit status is the successful package-build observable. The verified binaries are `build/tests/halation_v2_cpu_contract` and `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx`, both arm64 Mach-O artifacts.

## Forced rebuild re-verification

To rule out a cache-only pass, the related targets were rebuilt with `-B` and exited with status `0`:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-halation-cpu test-v2-compile test-v2-inspector build
```

Key captured output:

```text
xcrun clang++ ... -c "src/core/RenderCore.cpp" -o "build/obj/core/RenderCore.o"
xcrun clang++ ... "tests/halation_v2_cpu_contract.cpp" "build/obj/core/RenderCore.o" -o "build/tests/halation_v2_cpu_contract"
"build/tests/halation_v2_cpu_contract"
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
xcrun clang++ ... "tests/typed_compile_contract.cpp" "build/obj/core/RenderCore.o" -o "build/tests/typed_compile_contract"
"build/tests/typed_compile_contract"
xcrun clang++ ... "tests/inspector_metadata_contract.cpp" "build/obj/core/RenderCore.o" -o "build/tests/inspector_metadata_contract"
xcrun -sdk macosx metal -c "src/metal/kernels/CBEFFilmEffects.metal" -o "build/obj/metal/CBEFFilmEffects.air"
xcrun -sdk macosx metallib "build/obj/metal/CBEFFilmEffects.air" -o "build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib"
xcrun clang++ ... -o "build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx" -bundle -arch arm64 -Wl,-dead_strip -framework Foundation -framework Metal
"build/tests/inspector_metadata_contract"
make: Nothing to be done for `build'.
```

Judgment: the CPU-focused test executable was rebuilt and passed; the typed and Inspector executables both ran successfully; and the arm64 bundle plus Metal library were rebuilt from source without a compiler or linker error.

## Bundle load re-verification

The installed-format bundle was loaded through its real ABI probe after the forced rebuild:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test
```

Exit status: `0`

Captured output:

```text
"build/tests/plugin_abi_probe" "build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx"
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx:          Mach-O 64-bit bundle arm64
build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib: MetalLib executable (MacOS), version 1.2.9
```

Judgment: the resulting arm64 OpenFX bundle can be dynamically loaded by the ABI probe, exposes all five stable descriptors, and contains a readable bundled Metal library. This is a bundle regression check only; ticket 08 still owns the v2 Halation Metal parity behavior.

## Debug cleanup

During focused-contract authoring, the original exterior probe was at x+5 for a 65px-high 1%-radius fixture. Runtime instrumentation observed x+2 energy `0.851577`, x+3 energy `0.0832628`, x+5 energy `0`, core energy `0`, and total annulus energy `11.0539`. The assertion now probes the actual local lobe at x+2. Temporary print instrumentation and its journal are removed before completion.
