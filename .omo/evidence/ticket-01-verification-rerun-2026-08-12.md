# Ticket 01 direct verification rerun

Date: 2026-08-12
Reason: independent stop-hook verification of the previous completion claim.

## Commands and results

```text
python3 -m py_compile fixtures/quality/generate_fixtures.py fixtures/quality/render_report.py tests/quality_fixture_test.py
```

Exit status: 0.

```text
python3 -m unittest tests/quality_fixture_test.py -v
test_checked_in_manifest_matches_generated_assets ... ok
test_reproducible_scene_linear_suite_and_provenance ... ok
test_top_level_render_contract_comparison ... ok

----------------------------------------------------------------------
Ran 3 tests in 0.398s

OK
```

Exit status: 0.

The independent manifest/hash audit opened all eight checked-in fixture
frames and masks, verified every manifest SHA-256, parsed the `CBEF_RGBA32F`
header, and checked that every sample is finite with alpha in `[0, 1]`:

```text
fixtures= 8
asset_root= fixtures/quality/generated
hashes= all-match
finite_rgba= all-finite-alpha-safe
provenance_classes= internal tolerance,measured,placeholder,standard
placeholder_metrics= [('field-psf', 'psf-energy', False)]
```

The report bridge was invoked with separate v1 and v2 JSON reports:

```text
compared field-psf -> /tmp/cbef-report-verify-SE135o/comparison.json
fixture= field-psf
rows= 2
centroid_delta= -0.039999999999999994
placeholder_policy= placeholder values are not measured-profile approval evidence
```

The ticket still contains `**Status:** resolved` and its `## Answer` section.
This ticket owns Python fixture infrastructure only; no C++/Metal affected
target was changed, so a plugin binary build is outside the affected-target
verification for this ticket.
