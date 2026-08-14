# M3 Film Grain CPU evidence

- Scenario: production build of the CBEF bundle after the Film Grain CPU implementation.
  - Invocation: `make build`
  - Observable: exit status 0; bundle link and arm64 objects produced.
- Scenario: focused public RenderCore CPU contract.
  - Invocation: `make test-m3-cpu`
  - Observable: `film_grain_render_contract: PASS`.
  - Coverage: definition/defaults/presets, exact identity bits, deterministic rerender and half-away subframe reuse, 48-frame bias and ±5% sigma-stop RMS, neighbor-frame correlation, expected channel correlation `1-q`, H=1080/2160 canonical particle/spectrum comparison, horizontal/vertical spectrum energy, and non-DC spike gate.

Metal Film Grain remains pending in `src/metal/MetalRenderBackend.mm` and was intentionally not changed for this CPU slice.
