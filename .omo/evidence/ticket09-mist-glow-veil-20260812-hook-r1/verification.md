# Ticket 09 direct verification

Date: 2026-08-12
Workspace: `/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin`
Toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

This record was created after the stop-hook rejected an earlier completion claim. Every command below was executed directly against the current shared worktree; the adjacent `.log` file contains the complete command output and the `.exit` file contains its observed exit code.

| Scenario | Invocation | Observable | Artifact |
|---|---|---|---|
| v2 Mist CPU contract | `make -B test-v2-mist-cpu` | `mist_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 11)`; exit 0 | `01-mist-v2-cpu.log` / `.exit` |
| Legacy Mist CPU contract | `make -B test-m4-cpu` | `mist_render_contract: PASS`; exit 0 | `02-legacy-m4-cpu.log` / `.exit` |
| Typed plan contract | `make -B test-v2-compile` | test binary completed; exit 0 | `03-typed-compile.log` / `.exit` |
| Inspector metadata contract | `make -B test-v2-inspector` | inspector binary completed; exit 0 | `04-inspector.log` / `.exit` |
| Affected plugin build | `make -B build` | OpenFX bundle and bundled Metal library linked; exit 0 | `05-build.log` / `.exit` |
| ABI and bundled-library probe | `make -B test` | `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)`; exit 0 | `06-abi.log` / `.exit` |

The focused v2 contract exercises Generic Black/White vocabulary and presets, Grade direction, independent Glow/Veil branches, Glow Only/Veil Only/Source Mask diagnostics, reconstruction with neutral detail, dark-patch retention, neutral-source safety, signed HDR, straight alpha, transparent hidden RGB suppression, crop/non-zero origin, edge handling, and finite output.

The current metadata helper was also inspected during this verification: `src/core/RenderCore.cpp:193-203` defines `markBasic` with an optional `ParameterRole` argument, so the Mist calls at lines 262-263 compile cleanly without weakening the metadata contract.

## Verdict

All six required scenarios passed with exit code 0. Ticket 09 CPU scope is verified and resolved. Metal parity/UHD performance remain explicitly delegated to ticket 11.

EVIDENCE_RECORDED: /Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin/.omo/evidence/ticket09-mist-glow-veil-20260812-hook-r1/verification.md
