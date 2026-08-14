# Ticket 15 independent hook-2 reverification

Date: 2026-08-12 UTC

All commands below were executed directly in the shared worktree after the ticket 16 Optical extensions were present.

| Check | Command | Result | Raw artifact |
|---|---|---|---|
| CPU field PSF | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-optical-field-cpu` | PASS. Center energy 1.003913, centroid `(96.0001,95.9995)`; corner energy 1.001220, centroid `(23.9190,23.9192)`; adjacent centroid `(25.9215,23.9194)`; Cat-eye axis `0.997569 -> 0.868457`; ticket 16 aberration/quality output also passed. | `field.log` |
| Legacy optical CPU + Metal | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-m5-cpu` | PASS: `optical_blur_render_contract: PASS (CPU + Metal M5 Optical Blur)` | `m5.log` |
| Build, typed compiler, Inspector, ABI | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build test-v2-compile test-v2-inspector test` | All targets exit 0; ABI probe PASS; no compiler warnings in changed objects. | `build-abi.log` |
| Fixture provenance/reproducibility | `python3 fixtures/quality/generate_fixtures.py --manifest-out fixtures/quality/manifest.json && python3 tests/quality_fixture_test.py` | 10 fixtures generated; 3 tests `OK`. | `fixture-generate.log`, `fixture-test.log` |

All six raw artifacts are non-empty. The Metal v2 optical implementation remains ticket 17 scope; the Metal check above is the legacy contract with v2 controls disabled.
