# Ticket 04 final independent re-verification

Date: 2026-08-12

All commands in this report were rerun in a fresh attempt with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Scenario | Command / artifact | Result |
|---|---|---|
| Full arm64 package build | `make -B build` | Exit 0; see `build.log` and `build.exit`. |
| Required typed + M1–M6 suite | `make -B build test-v2-compile test-m1 test-m2 test-m3 test-m4 test-m5 test-m6` | Exit 0; typed compile and all M1–M6 CPU/Metal contracts report PASS; see `focused.log` and `focused.exit`. |
| ABI probe | `make test` | Exit 0; `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)`; see `abi.log` and `abi.exit`. |
| Bundled metallib load | `CBEF_METALLIB_PATH=$PWD/build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib build/tests/headless_render_contract` | Exit 0; `PASS (CPU + Metal M1 contract)`, see `bundled-load.log` and `bundled-load.exit`. The Metal path would return `PipelineCreationFailed` if the URL load failed. |
| Runtime source compile removal | `rg` scan under `src/metal` | PASS: no `newLibraryWithSource`, `MTLCompileOptions`, raw kernel source symbols, or source loader remain; see `runtime-source-scan.log`. |
| Bundle artifact | `file`, `stat`, SHA-256 | Both bundle and test metallib are valid MetalLib files, 237249 bytes, identical SHA-256; see `artifact.log`. |

The issue remains `Status: resolved` in the ticket. All evidence files in this directory are non-empty.
