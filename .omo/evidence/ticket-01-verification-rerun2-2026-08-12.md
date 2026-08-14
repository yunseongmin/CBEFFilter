# Ticket 01 direct verification rerun 2

Date: 2026-08-12

## Initial attempt and correction

The first command was accidentally launched from the parent directory
`/Users/younseongmin/Documents/CBEF`, so paths such as
`fixtures/quality/generate_fixtures.py` were not found and the unittest module
could not be imported. This was an execution-directory error, not a fixture
failure. The same verification was rerun from the owning repository
`/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin` and passed.

## Passing verification from the owning repository

```text
python3 -m py_compile fixtures/quality/generate_fixtures.py fixtures/quality/render_report.py tests/quality_fixture_test.py
python3 -m unittest tests.quality_fixture_test -v
test_checked_in_manifest_matches_generated_assets ... ok
test_reproducible_scene_linear_suite_and_provenance ... ok
test_top_level_render_contract_comparison ... ok

----------------------------------------------------------------------
Ran 3 tests in 0.410s

OK
```

Two fresh temporary runs were generated and compared byte-for-byte:

```text
generated 8 fixtures in /tmp/cbef-t01-a-F0FeKE/generated
generated 8 fixtures in /tmp/cbef-t01-b-UvaN37/generated
manifest_equal= true
fixture_ids= 8-required
frame_and_mask_bytes_equal= true
geometry_and_float_safety= true
```

The independent audit also verified the local cache and rights schema:

```text
fixtures/quality/local-assets/.gitignore
external_records= 0
rights_schema= complete
placeholder_gate= false
```

The ticket audit found `**Status:** resolved` and `## Answer`. The report CLI
also passed with one metric row and a `-0.039999999999999994` delta.

The failed parent-directory attempt and corrected passing attempt are both
recorded here so the evidence does not hide the initial invocation error.
