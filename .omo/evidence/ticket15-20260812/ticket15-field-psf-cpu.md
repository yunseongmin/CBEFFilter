# Ticket 15 CPU field PSF evidence

Date: 2026-08-12

The CPU reference keeps uniform defocus as the product scope and adds a generic field-dependent effective-pupil approximation. Canonical field coordinates use pixel centers normalized over the complete declared data window. The field kernel normalizes each output gather, applies a continuous rim clipping weight, and keeps Center/Rim bias separate from highlight response.

## Verification

| Scenario | Invocation | Observable |
|---|---|---|
| Field PSF contract | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-optical-field-cpu` | `optical_field_psf_cpu_contract: PASS`; center energy 1.004276, centroid (96.0002, 95.9996); corner energy 1.002827, centroid (23.8140, 23.8123); adjacent corner centroid (25.8189, 23.8120); cat-eye axis ratio 0.997569 → 0.868456 |
| Legacy M5 CPU + Metal regression | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-m5-cpu` | `optical_blur_render_contract: PASS (CPU + Metal M5 Optical Blur)`; this target invokes the Metal-enabled optical contract, and the legacy path explicitly zeros v2 field controls |
| Typed compiler and Inspector metadata | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-compile test-v2-inspector` | both binaries exit 0; appended Lens Profile, Center / Rim, Cat-eye and diagnostic choices are accepted |
| Bundle build and ABI | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test` | `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)` |
| Affected bundle build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build` | exit 0 with no compiler warnings in changed core/OFX/Metal objects |
| Fixture reproducibility/provenance | `python3 fixtures/quality/generate_fixtures.py --manifest-out fixtures/quality/manifest.json && python3 tests/quality_fixture_test.py` | 3 tests `OK`; field-PSF provenance records generator 1.1.0, canonical coordinates, second-moment and axis-ratio metrics |

The Metal optical path is intentionally unchanged; CPU/Metal v2 parity remains ticket 17 scope.

## Post-ticket-16 shared-tree reverification

Ticket 16 appended vignetting, coma, astigmatism, field curvature, chromatic aberration, and quality controls to the same Optical plan. The ticket 15 contract was updated to expect the resulting 19-parameter definition, while the legacy M5 contract explicitly zeros all v2 character controls.

| Recheck | Invocation | Artifact / result |
|---|---|---|
| Field CPU after ticket 16 append | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-optical-field-cpu` | [`reverify-field.log`](reverify-field.log); PASS. Center energy 1.003913, centroid (96.0001, 95.9995); corner energy 1.001220, centroid (23.9190, 23.9192); adjacent centroid (25.9215, 23.9194); Cat-eye axis 0.997569 → 0.868457 |
| Legacy CPU + Metal regression after ticket 16 append | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-m5-cpu` | [`reverify-m5.log`](reverify-m5.log); `optical_blur_render_contract: PASS (CPU + Metal M5 Optical Blur)` |
| Build, typed compiler, Inspector and ABI | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build test-v2-compile test-v2-inspector test` | [`reverify-build-abi.log`](reverify-build-abi.log); all exit 0, ABI PASS, no changed-source compiler warnings |
| Fixture regeneration and reproducibility | `python3 fixtures/quality/generate_fixtures.py --manifest-out fixtures/quality/manifest.json && python3 tests/quality_fixture_test.py` | [`reverify-fixture-generate.log`](reverify-fixture-generate.log), [`reverify-fixture-test.log`](reverify-fixture-test.log); 3 tests OK |

Independent hook-2 evidence bundle: [`hook2/reverification.md`](hook2/reverification.md), with non-empty raw logs for every command.
