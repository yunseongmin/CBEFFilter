# Ticket 07 verification

Date: 2026-08-12
Scope: CPU reference Halation global branch and profile-relative channel response.

## Toolchain

- Scenario: resolve the installed Metal compiler and linker tools.
- Invocation: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --find metal` and `... xcrun --find metallib`.
- Observable: both tools resolved from the installed Xcode Metal toolchain.
- Artifact: `build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib`.

## Affected build

- Scenario: rebuild the changed CPU core, OFX bundle, and bundled Metal library.
- Invocation: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-compile test-v2-inspector`.
- Observable: clang++ compiled `src/core/RenderCore.cpp`, the OFX bundle linked as arm64, `metal`/`metallib` produced the resource, and both typed and inspector binaries exited 0.
- Artifacts: `build/obj/core/RenderCore.o`, `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx`, `build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib`, `build/tests/typed_compile_contract`, `build/tests/inspector_metadata_contract`.

## Ticket 06 and 07 CPU focused suite

- Scenario: neutral, tungsten, blue LED, saturated red source sweep; source mask continuity; local/core/background behavior; Local Only + Global Only reconstruction; global-only far-field energy; profile-relative red-dominant response; strong-setting core/white-veil guard; HDR/signed RGB, alpha, crop, no-wrap, and resolution invariants.
- Invocation: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-halation-cpu`.
- Observable: `halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)`.
- Artifact: `build/tests/halation_v2_cpu_contract`.

## ABI regression

- Scenario: load the rebuilt bundle and inspect all five stable OpenFX effect descriptors plus the bundled Metal library.
- Invocation: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test`.
- Observable: `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)`.
- Artifact: `build/tests/plugin_abi_probe`.

Metal v2 parity was not asserted here; it remains ticket 08.
