# Ticket 01 direct verification rerun 3

Date: 2026-08-12

## Fixture verification

From `/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin`:

```text
python3 -m py_compile fixtures/quality/generate_fixtures.py fixtures/quality/render_report.py tests/quality_fixture_test.py
python3 -m unittest tests.quality_fixture_test -v
test_checked_in_manifest_matches_generated_assets ... ok
test_reproducible_scene_linear_suite_and_provenance ... ok
test_top_level_render_contract_comparison ... ok

----------------------------------------------------------------------
Ran 3 tests in 0.389s

OK
```

An independent checked-in artifact audit also passed:

```text
fixtures=8 hashes=all-match finite_rgba=all-finite-alpha-safe
```

## Build/contract verification and blocker

The existing CPU contract target was invoked because the user requested build
and test continuation:

```text
make test-m1-cpu
xcrun -sdk macosx metal -c "src/metal/kernels/CBEFFilmEffects.metal" -o "build/obj/metal/CBEFFilmEffects.air"
xcrun: error: unable to find utility "metal", not a developer tool or in PATH
make: *** [build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib] Error 72
```

The checked-in `build/tests/headless_render_contract` binary was then invoked
directly:

```text
headless_render_contract: Metal must return Enqueued after committing work to the supplied queue
```

These are not fixture failures. The first is a machine/toolchain blocker: the
Metal compiler is unavailable. The second is an existing Metal contract
failure outside this ticket's ownership; this ticket changed only Python
fixture/report infrastructure, generated synthetic assets, tests, and docs.
No C++/Metal file was modified to mask or weaken that failure.

The ticket remains `resolved` for its own acceptance criteria. Full plugin
build/Metal contract evidence must be handled by the owning Metal/integration
tickets once the toolchain and shared implementation are ready.
