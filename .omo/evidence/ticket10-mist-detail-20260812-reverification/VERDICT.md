# Ticket10 direct reverification

Date: 2026-08-12

- `python3 fixtures/quality/generate_fixtures.py --output-dir /tmp/cbef-ticket10-fixtures --manifest-out /tmp/cbef-ticket10-fixtures/manifest.json`: generated 9 fixtures.
- `python3 tests/quality_fixture_test.py`: 3 tests passed.
- `fixtures/quality/manifest.json`: `mist-detail-frequency` contains 5 metrics and every `measured_profile_gate` is `false`.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-mist-cpu`: passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-compile`: passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-inspector`: passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build`: passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test`: `plugin_abi_probe: PASS`.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-m4-cpu`: fails only at CPU/Metal Mist parity (`CPU and Metal Mist must agree within 2e-4`); this is explicitly deferred to ticket11, which owns Metal projection of the ticket10 CPU profile.

Raw command output is in `direct-verification.log`, `final-rerun.log`, and `verified-statuses.log`.
