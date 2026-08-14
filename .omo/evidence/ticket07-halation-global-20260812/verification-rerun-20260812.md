# Ticket 07 direct verification rerun

This record was created after the completion report was challenged. All commands below were run against the current shared worktree.

## Commands and observed results

1. Toolchain resolution

   Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --find metal` and `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --find metallib`

   Result: both resolved to the installed Xcode Metal toolchain under `/var/run/com.apple.security.cryptexd/.../Metal.xctoolchain/usr/bin`.

2. Halation CPU focused contract

   Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-halation-cpu`

   Result: compilation succeeded and the executable printed `halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)`.

   Artifact: `build/tests/halation_v2_cpu_contract` (non-empty).

3. Typed compiler and Inspector contracts plus affected bundle build

   Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-compile test-v2-inspector`

   Result: typed contract exited 0, Inspector contract exited 0, arm64 OFX bundle linked, and `metal`/`metallib` compiled the bundled library.

   Artifacts: `build/tests/typed_compile_contract`, `build/tests/inspector_metadata_contract`, `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx`, `build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib` (all non-empty).

4. ABI regression

   Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test`

   Result: `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)`.

   Artifact: `build/tests/plugin_abi_probe` (non-empty).

5. Binary format checks

   Command: `file build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib`

   Result: the plugin is a `Mach-O 64-bit bundle arm64`; the resource is a `MetalLib executable (MacOS), version 1.2.9`.

## Judgment

The ticket 07 CPU, typed, Inspector, affected bundle, and ABI checks passed in this rerun. This is CPU-reference evidence only; Metal v2 effect parity and Resolve host acceptance remain later tickets.
