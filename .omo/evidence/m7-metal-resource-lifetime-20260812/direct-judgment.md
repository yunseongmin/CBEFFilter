# Direct M7 Metal lifetime verification

Date: 2026-08-11 UTC

## Scope and invocation

- Source ownership audit: `rg -n "ScopedMTLBuffer|newBuffer" src/metal/MetalRenderBackend.mm` and `rg -n "id<MTLBuffer> .*newBuffer" src/metal/MetalRenderBackend.mm`.
- Affected bundle build: `make -B build`.
- Focused regression suite: `make test-m1 test-m2 test-m3 test-m4 test-m5 test-m6`.

## Binary observables

- The raw-allocation audit exited successfully and reported `PASS: all source allocations use ScopedMTLBuffer`; all listed source allocations are `ScopedMTLBuffer` declarations.
- `make -B build` exited 0. Its compiler and linker output contains no `warning:` or `error:` diagnostics.
- All six requested binaries exited 0 and printed PASS:
  - `headless_render_contract: PASS (CPU + Metal M1 contract)`
  - `halation_render_contract: PASS (CPU + Metal M2 Halation)`
  - `film_grain_render_contract: PASS`
  - `mist_render_contract: PASS`
  - `optical_blur_render_contract: PASS (CPU + Metal M5 Optical Blur)`
  - `lens_reflections_render_contract: PASS (CPU + Metal M6 Lens Reflections)`

## Evidence files

- Raw source output: `direct-source-verification.log`
- Build output: `direct-build.log`
- Test output: `direct-tests-m1-m6.log`
- Combined output and PASS matching: `direct-verification-summary.log`

## Judgment

The scoped ownership implementation is directly verified for this attempt. Cached pipeline/library objects remain intentionally process-lifetime owned by the existing cache; no new temporary-resource residual was observed. M7 allocated-size steady-state measurement remains owned by the M7 benchmark because no dedicated test was added.
