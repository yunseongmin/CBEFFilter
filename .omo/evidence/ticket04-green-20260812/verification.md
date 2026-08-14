# Ticket 04 final verification

Date: 2026-08-12

## RED reproduced and fixed

The full-Xcode RED build is preserved in `../ticket04-red-20260812/full-build-red.log`.
It reported a missing closing brace at the transition from `cbef_grain_final` to the mist
kernels, then the same extraction defect at `cbef_mist_prepare`. Restoring those two braces
made the Metal source syntactically complete; the follow-up build log is
`../ticket04-red-20260812/full-build-after-mist-brace.log` with exit 0.

## Green checks

| Scenario | Invocation | Observable |
|---|---|---|
| Full package build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build` | Exit 0; AIR and `Contents/Resources/CBEFFilmEffects.metallib` generated. |
| Required focused suite | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build test-v2-compile test-m1 test-m2 test-m3 test-m4 test-m5 test-m6` | Typed compile and M1–M6 CPU/Metal contracts all PASS. |
| Focused rerun exit | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-compile test-m1 test-m2 test-m3 test-m4 test-m5 test-m6` | `make_exit=0`; see `focused-rerun.log` and `focused-rerun.exit`. |
| ABI and bundle resource | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test` | `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)`, exit 0; see `abi-rerun.log`. |
| Bundled metallib runtime load | `CBEF_METALLIB_PATH=$PWD/build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib build/tests/headless_render_contract` | `PASS (CPU + Metal M1 contract)`, exit 0; see `bundled-load.log` and `bundled-load.exit`. The Metal path would fail with `PipelineCreationFailed` if the URL load failed. |

## Artifacts

- `build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib`: MetalLib executable, 237249 bytes.
- `build/obj/metal/CBEFFilmEffects.air`: LLVM bitcode wrapper, 72848 bytes.
- `build/tests/CBEFFilmEffects.metallib`: copied test resource.
- Runtime source scan remains clean: no `newLibraryWithSource`, `MTLCompileOptions`, or raw shader source symbols.

Ticket 04 is resolved.
