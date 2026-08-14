# Ticket 09 direct verification, hook rerun 3

Date: 2026-08-12
Workspace: `/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin`
Toolchain: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`

The current worktree was tested directly again. Each command's complete output is in the matching `.log` file and its observed exit code is in the matching `.exit` file.

| Scenario | Invocation | Result |
|---|---|---|
| v2 Mist CPU public contract | `make -B test-v2-mist-cpu` | `mist_v2_cpu_contract: PASS`; exit 0 |
| Legacy Mist CPU contract | `make -B test-m4-cpu` | `mist_render_contract: PASS`; exit 0 |
| Typed compile contract | `make -B test-v2-compile` | completed; exit 0 |
| Inspector metadata contract | `make -B test-v2-inspector` | completed; exit 0 |
| Affected plugin build | `make -B build` | bundle linked/metallib generated; exit 0 |
| ABI/bundle probe | `make -B test` | `plugin_abi_probe: PASS`; exit 0 |
| Artifact inspection | `ls`, `file`, `shasum -a 256` on OFX and metallib | arm64 Mach-O bundle and MetalLib executable present; exit 0 |

The v2 Mist contract directly exercises Generic Black/White naming and presets, Grade progression, independent Glow and Veil, Glow Only/Veil Only/Source Mask, branch reconstruction, Black/White direction, neutral safety, signed HDR, alpha/crop/edge handling, and transparent hidden-RGB suppression.

The generated artifacts are:

- `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` — Mach-O 64-bit bundle arm64, 359,360 bytes.
- `build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib` — MetalLib executable, 315,258 bytes.

SHA-256 and complete artifact output are in `07-artifacts.log`.

Evidence integrity was checked after writing this record: `08-evidence-integrity.log` confirms the verification file is non-empty and all seven command `.exit` files contain `EXIT: 0`.

## Judgment

All seven direct checks returned exit code 0 with the expected PASS observables. Ticket 09 CPU scope remains verified. Metal parity/UHD performance are explicitly ticket 11 scope.

EVIDENCE_RECORDED: /Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin/.omo/evidence/ticket09-mist-glow-veil-20260812-hook-r3/verification.md
