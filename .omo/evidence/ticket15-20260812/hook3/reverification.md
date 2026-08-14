# Ticket 15 hook-3 direct verification

Executed at 2026-08-12T07:47:32Z in the shared worktree. Every command was run independently; `status.tsv` records exit code and raw-log byte count.

| Command | Exit | Raw log |
|---|---:|---|
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-optical-field-cpu` | 0 | `field.log` (784 bytes) |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-m5-cpu` | 0 | `m5.log` (1,372 bytes) |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build test-v2-compile test-v2-inspector test` | 0 | `build_abi.log` (4,871 bytes) |
| `python3 fixtures/quality/generate_fixtures.py --manifest-out fixtures/quality/manifest.json` | 0 | `fixture_generate.log` (93 bytes) |
| `python3 tests/quality_fixture_test.py` | 0 | `fixture_test.log` (101 bytes) |

Observed PASS strings and field metrics are present in the raw logs. SHA-256 values and non-empty checks are recorded in `summary.txt`; the bundle ABI probe reports five stable OpenFX descriptors and the bundled Metal library.
