# Ticket 04 verification — precompiled Metal library

Date: 2026-08-12

## Implemented contract

- `src/metal/kernels/CBEFFilmEffects.metal` is the single Metal shader source.
- `src/metal/MetalRenderBackend.mm` loads `CBEFFilmEffects.metallib` with `newLibraryWithURL:` and caches one `MTLLibrary` and one pipeline per device/function pair.
- No runtime source compilation path remains (`newLibraryWithSource`, `MTLCompileOptions`, and the old raw-string shader symbols are absent).
- `Makefile` compiles the source with `xcrun -sdk macosx metal`, links it with `xcrun -sdk macosx metallib`, places it in `Contents/Resources`, and copies it beside focused test binaries.
- The ABI probe checks that the final bundle contains a non-empty `Contents/Resources/CBEFFilmEffects.metallib` before validating all five stable OpenFX identifiers.

## Evidence

| Scenario | Invocation | Observable | Artifact |
|---|---|---|---|
| Affected arm64 object build | `make -B build` | C++/Objective-C++ sources compiled, then build stopped because this machine has only Command Line Tools and no Apple `metal` utility (`xcrun` error 72). | [build.log](build.log) |
| Runtime source compile removal | `rg -n 'newLibraryWithSource|newLibraryWithData|MTLCompileOptions|kernel_source' src/metal` | No matches. | [runtime-source-scan.log](runtime-source-scan.log) |
| ABI probe source build | `xcrun clang++ ... tests/plugin_abi_probe.cpp -o /tmp/cbef_plugin_abi_probe` | arm64 probe executable created. | [abi-probe-build.log](abi-probe-build.log) |
| M1 CPU contract | `/tmp/cbef-headless_render_contract-cpu` | `PASS (CPU M1 contract)` | [headless_render_contract.log](cpu/headless_render_contract.log) |
| M2 CPU contract | `/tmp/cbef-halation_render_contract-cpu` | `PASS (CPU + Metal M2 Halation)` test's CPU path | [halation_render_contract.log](cpu/halation_render_contract.log) |
| M3 CPU contract | `/tmp/cbef-film_grain_render_contract-cpu` | `PASS` | [film_grain_render_contract.log](cpu/film_grain_render_contract.log) |
| M4 CPU contract | `/tmp/cbef-mist_render_contract-cpu` | `PASS` | [mist_render_contract.log](cpu/mist_render_contract.log) |
| M5 CPU contract | `/tmp/cbef-optical_blur_render_contract-cpu` | `PASS` | [optical_blur_render_contract.log](cpu/optical_blur_render_contract.log) |
| M6 CPU contract | `/tmp/cbef-lens_reflections_render_contract-cpu` | `PASS (CPU M6 Lens Reflections)` | [lens_reflections_render_contract.log](cpu/lens_reflections_render_contract.log) |

## Blocking environment condition

The full package build and GPU parity/ABI execution cannot be completed on this machine because
`xcrun --find metal` and `xcrun --find metallib` both report that the utilities are unavailable.
The implementation deliberately fails the package build rather than falling back to runtime source
compilation. Re-run `make -B build`, `make test`, and the M1–M6 targets on a Mac with the full Xcode
Metal toolchain; the generated bundle resource is then required by the ABI probe and test loader.
