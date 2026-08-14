# M3 Film Grain QA Evidence

Date: 2026-08-12

## Acceptance run

Invocation:

```sh
make build
make test-m1
make test-m2
make test-m3
```

Current consolidated output: [`13-grain-48-frame.log`](../evidence/v2-final-20260812/13-grain-48-frame.log)
and [`15-grain-metal.log`](../evidence/v2-final-20260812/15-grain-metal.log).

Observed results:

- `make build` completed and produced `build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx`.
- M1 headless contract passed with CPU + Metal.
- M2 Halation contract passed with CPU + Metal.
- M3 Film Grain contract passed with the 48-frame CPU statistical suite and the actual Metal parity suite.

## M3 scenarios covered

- Deterministic same-frame and half-away rounded subframe output.
- 48-frame bias, RMS, neighbor correlation, resolution/diameter, radial spectrum, axis balance, local non-DC spike, and channel-correlation gates.
- Metal GPU submission on the supplied `MTLCommandQueue`, CPU parity within `2e-4`, signed/HDR and transparent-alpha handling.
- Crop render-window canonical scaling against the full data-window height.
- Exact Metal identity copy and destination sentinel preservation outside the render window and row padding.
