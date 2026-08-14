# Third direct re-audit

Date: 2026-08-12

The current shared tree was inspected and exercised again.

- Metal audit still shows the legacy `MistArguments` path (`sizeof == 96`, fields only through `texture`) and no `detail_fine`/`detail_mid` consumption in `MetalRenderBackend.mm` or `CBEFFilmEffects.metal`.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-mist-cpu`: PASS.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-m4-cpu`: FAIL, exit 2, at `CPU and Metal Mist must agree within 2e-4`.

This remains a real blocker owned by ticket11 Metal parity. Ticket10 is not fully complete and is not being reported as complete.

Raw output: `third-reaudit.log`.
