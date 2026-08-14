# Ticket 09 direct verification, hook rerun 2

Date: 2026-08-12
Workspace: `/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin`
Toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

The six required commands were executed afresh against the current worktree. Full stdout/stderr is stored in the numbered `.log` files and each command's observed status is in the adjacent `.exit` file.

| Check | Direct command | Observed result |
|---|---|---|
| v2 Mist CPU | `make -B test-v2-mist-cpu` | `mist_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 11)`; exit 0 |
| Legacy Mist CPU | `make -B test-m4-cpu` | `mist_render_contract: PASS`; exit 0 |
| Typed plan | `make -B test-v2-compile` | binary completed; exit 0 |
| Inspector metadata | `make -B test-v2-inspector` | binary completed; exit 0 |
| Plugin build | `make -B build` | bundle linked and metallib generated; exit 0 |
| ABI probe | `make -B test` | `plugin_abi_probe: PASS`; exit 0 |

Additional artifact checks also ran directly:

- `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` exists as an arm64 Mach-O bundle (359,360 bytes).
- `build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib` exists as a MetalLib executable (315,258 bytes).
- SHA-256 values were captured in `07-artifact-check.log`.
- Source contract vocabulary and the `markBasic` optional `ParameterRole` signature were captured by `08-contract-source-check.log`.
- Evidence integrity was independently checked by `09-evidence-integrity-check.log`: the verification record and artifact log are non-empty, and all eight `.exit` artifacts contain `EXIT: 0`.

## Judgment

All required commands and artifact checks returned exit code 0, with the expected PASS observables. Ticket 09 CPU scope is verified. Metal parity and UHD performance remain ticket 11 scope, not claimed here.

EVIDENCE_RECORDED: /Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin/.omo/evidence/ticket09-mist-glow-veil-20260812-hook-r2/verification.md
