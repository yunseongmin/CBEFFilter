# Ticket 07 direct verification rerun 2

The second stop-hook challenge was handled by executing the affected checks again, without relying on the prior report.

## Executed scenarios

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --find metal`
  - Resolved to the installed Xcode Metal toolchain.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun --find metallib`
  - Resolved to the installed Xcode Metal toolchain.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-halation-cpu`
  - `halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)`.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-compile test-v2-inspector`
  - Both typed and Inspector executables ran successfully.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test`
  - `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)`.

## Artifact evidence

The command checked non-zero byte sizes and SHA-256 hashes for:

- `build/tests/halation_v2_cpu_contract` — 116760 bytes
- `build/tests/typed_compile_contract` — 115864 bytes
- `build/tests/inspector_metadata_contract` — 116344 bytes
- `build/tests/plugin_abi_probe` — 38016 bytes
- `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` — 342160 bytes
- `build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib` — 237249 bytes

Observed SHA-256 values were captured in the command output for each artifact. Judgment: all rerun scenarios passed; this record still makes no Metal v2 effect-parity claim.
