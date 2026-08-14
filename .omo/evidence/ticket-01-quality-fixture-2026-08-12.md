# Ticket 01 evidence: quality fixtures and provenance

Date: 2026-08-12
Scope: synthetic fixture generator, checked-in manifest/masks, top-level render-report bridge, focused tests and policy docs.

## Acceptance evidence

| Criterion | Scenario and invocation | Binary observable | Artifact |
|---|---|---|---|
| Synthetic scene-linear suite | `python3 fixtures/quality/generate_fixtures.py --output-dir /tmp/cbef-quality-ticket01 --manifest-out /tmp/cbef-quality-ticket01/manifest.json` | `generated 8 fixtures`; manifest summary reports `fixtures= 8`, `asset_root= fixtures/quality/generated`, and `external_records= 0` | [`fixtures/quality/manifest.json`](../../fixtures/quality/manifest.json) and [`fixtures/quality/generated`](../../fixtures/quality/generated) |
| Determinism, masks, hashes, safety | `python3 -m unittest tests/quality_fixture_test.py -v` | 3 tests pass: checked-in manifest, two-run byte reproducibility with finite float/alpha checks and provenance checks, and render-report comparison | [`tests/quality_fixture_test.py`](../../tests/quality_fixture_test.py) |
| Render contract comparison | `python3 fixtures/quality/render_report.py <v1.json> <v2.json> --output <comparison.json> --markdown <comparison.md>` | `compared field-psf`; 2 metric rows; centroid delta `-0.039999999999999994`; placeholder policy preserved | [`fixtures/quality/render_report.py`](../../fixtures/quality/render_report.py) |
| External asset rights boundary | Manifest summary and checked-in cache policy | `external_records= 0`; records require official URL, SHA-256, acquisition date, terms, clip/frame, decode, color transform and explicit redistribution rights; local cache is ignored | [`fixtures/quality/local-assets/.gitignore`](../../fixtures/quality/local-assets/.gitignore), [`docs/qa/quality-fixtures.md`](../../docs/qa/quality-fixtures.md) |

## Fixture inventory

The generated suite contains exposure/color ramp, flat fields, point-source
sweep/grid, slanted edge, thin line, signage/RGB LED, alpha edge and field PSF
fixtures. Each frame is 192x128 interleaved little-endian RGBA float32 in the
scene-linear `CBEF_RGBA32F` equivalent source format. Each fixture has a
semantic mask sidecar and manifest frame/mask SHA-256. Placeholder metrics also
carry `measured_profile_gate: false` in the manifest.

## Validation output

```text
test_checked_in_manifest_matches_generated_assets ... ok
test_reproducible_scene_linear_suite_and_provenance ... ok
test_top_level_render_contract_comparison ... ok

----------------------------------------------------------------------
Ran 3 tests in 0.408s

OK

generated 8 fixtures in /tmp/cbef-quality-ticket01
fixtures= 8
asset_root= fixtures/quality/generated
external_records= 0
provenance= internal tolerance, measured, placeholder, standard
```

The implementation is Python-only fixture infrastructure, so no C++ or Metal
target was changed and no plugin binary rebuild is part of this ticket's
affected-target verification. The existing render contract remains the
consumer boundary for future v1/v2 effect reports.
