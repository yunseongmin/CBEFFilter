# Ticket 04 independent verification

Date: 2026-08-12

## Direct results

| Check | Result | Evidence |
|---|---|---|
| Runtime Metal source-compilation scan | PASS: no `newLibraryWithSource`, `MTLCompileOptions`, raw shader symbols, or source loader remain under `src/metal` | [runtime-source-scan.log](runtime-source-scan.log) |
| Affected arm64 core/Metal object build | PASS, exit 0 | [object-build.log](object-build.log) |
| M1 CPU render contract | PASS, build/run exit 0 | [cpu/headless_render_contract.log](cpu/headless_render_contract.log) |
| M2 CPU render contract | PASS, build/run exit 0 | [cpu/halation_render_contract.log](cpu/halation_render_contract.log) |
| M3 CPU render contract | PASS, build/run exit 0 | [cpu/film_grain_render_contract.log](cpu/film_grain_render_contract.log) |
| M4 CPU render contract | PASS, build/run exit 0 | [cpu/mist_render_contract.log](cpu/mist_render_contract.log) |
| M5 CPU render contract | PASS, build/run exit 0 | [cpu/optical_blur_render_contract.log](cpu/optical_blur_render_contract.log) |
| M6 CPU render contract | PASS, build/run exit 0 | [cpu/lens_reflections_render_contract.log](cpu/lens_reflections_render_contract.log) |
| ABI probe compilation | PASS, arm64 executable | [abi-probe-build.log](abi-probe-build.log) |
| ABI probe against current bundle | FAIL as required: current bundle has no generated `CBEFFilmEffects.metallib` | [abi-probe-run.log](abi-probe-run.log) |
| Full package build | FAIL, exit 2: `xcrun` cannot find `metal` | [full-build.log](full-build.log) |

## Environment blocker

`xcrun --find metal` and `xcrun --find metallib` both exit 72 because this host has only
Command Line Tools, not the full Xcode Metal toolchain. The package build therefore stops at
the precompile step. This is intentional: no runtime source-compilation fallback remains.

## State conclusion

The implementation changes and CPU/object checks are verified, but Ticket 04 is **not resolved**.
The arm64 metallib generation, final bundle resource check, GPU M1–M6 parity, and successful ABI
probe must be rerun on a Mac with the full Xcode Metal tools. The issue remains `claimed`.
