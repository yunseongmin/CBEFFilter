# M4 Mist Diffusion QA Evidence

Date: 2026-08-12

## Acceptance run

Invocation:

```sh
make build
make test-m1
make test-m2
make test-m3
make test-m4
```

Current consolidated output: [`17-mist-cpu.log`](../evidence/v2-final-20260812/17-mist-cpu.log)
and [`18-mist-metal.log`](../evidence/v2-final-20260812/18-mist-metal.log).

Observed results:

- The affected bundle build completed successfully.
- M1 headless, M2 Halation, and M3 Film Grain contracts passed.
- M4 Mist passed its CPU contract and actual Metal command-queue parity contract.

Evidence map:

| Scenario | Invocation / binary | Observable | Artifact |
|---|---|---|---|
| Affected bundle build | `make build` → `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx` | exit 0 and bundle binary produced | [`01-clean-build.log`](../evidence/v2-final-20260812/01-clean-build.log) |
| M4 CPU + Metal contract | `make test-m4` → `build/tests/mist_render_contract` | `mist_render_contract: PASS` | [`18-mist-metal.log`](../evidence/v2-final-20260812/18-mist-metal.log) |
| M1–M3 regression contracts | `make test-m1 test-m2 test-m3` → corresponding `build/tests/*` binaries | all three `PASS` | [최종 판정](../evidence/v2-final-20260812/verdict.md) |

## M4 scenarios covered

- Eight preset/parameter expansion, exact identity, diagnostics, and pre-Mix component behavior.
- Density energy monotonicity, Black/White radius ratio, shadow lift, MTF, texture monotonicity, and scaled-resolution checks.
- Signed HDR residual, transparent hidden RGB suppression, alpha preservation, crop/data-window edge clamping, and destination sentinel preservation.
- GPU two-scale alpha-weighted diffusion and bloom passes with CPU parity at maximum absolute error `<= 2e-4`.
- Metal identity bit copy, render-window crop parity, row-padding preservation, outside-window sentinel preservation, and alpha bit identity.

Resolve visual tuning and performance measurements remain owned by M7.
