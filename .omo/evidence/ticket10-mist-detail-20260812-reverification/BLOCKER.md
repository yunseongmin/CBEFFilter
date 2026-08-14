# Ticket10 re-audit blocker

Date: 2026-08-12

Direct commands were rerun against the current shared worktree:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-mist-cpu`: PASS (`mist_v2_cpu_contract: PASS`).
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-m4-cpu`: FAIL, exit 2, at `CPU and Metal Mist must agree within 2e-4`.

The current Metal Mist adapter does not yet consume the appended CPU ticket10 detail/profile coefficients. The failure is therefore not silently waived; it is owned by ticket11 Metal parity. Ticket10 cannot be reported as fully complete until the ticket11 adapter update makes M4 parity pass.

Raw output: `current-reaudit.log`.
