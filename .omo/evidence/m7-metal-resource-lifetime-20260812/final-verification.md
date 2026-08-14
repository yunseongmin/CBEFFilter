# Final direct verification

The following commands were executed against the current worktree on 2026-08-11 UTC:

```text
rg -n 'newBuffer(WithLength|WithBytes)' src/metal/MetalRenderBackend.mm
rg -n 'id<MTLBuffer> .*newBuffer' src/metal/MetalRenderBackend.mm
make -B build
make test-m1 test-m2 test-m3 test-m4 test-m5 test-m6
```

Observed results:

- Source audit counted 22 owning allocation sites and 22 `ScopedMTLBuffer` sites. The raw-owner search returned no matches.
- `make -B build` completed successfully and emitted no `warning:` or `error:` diagnostics.
- All requested tests completed successfully and printed PASS for M1 headless, M2 Halation, M3 Grain, M4 Mist, M5 Optical Blur, and M6 Lens Reflections.

The first wrapper command had a post-run shell bookkeeping typo (`status` is readonly in zsh) after the build and tests had already passed; this did not affect the command results. The captured run is in `final-verification-run.log`. The source, build, and test outputs are preserved in this directory.

Clean reruns with no wrapper bookkeeping error are captured in `final-build-rerun.log` and `final-tests-rerun.log`; their status files report `build_rerun=PASS` and `tests_m1_m6_rerun=PASS`.

Conclusion: the resource-lifetime change and required regression checks pass. Cached Metal pipeline/library objects remain intentionally process-lifetime owned; M7 allocated-size measurement remains a benchmark concern.
