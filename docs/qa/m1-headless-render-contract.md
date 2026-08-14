# M1 Headless Render Contract

Status: passed

Artifact: `m1-headless-render-contract-2026-08-12`

| Item | Evidence |
|---|---|
| Affected build | `make build` exited 0 with no compiler warnings. The arm64 OpenFX bundle links the Render Core and Metal backend with Foundation and Metal. |
| Focused suite | `make test-m1` exited 0 and printed `headless_render_contract: PASS (CPU + Metal M1 contract)`. |
| Metal execution | The test provides real shared `MTLBuffer` source/destination storage and a test-owned `MTLCommandQueue`. The backend returns `Enqueued` only after encoder end and command-buffer commit; a subsequent same-queue sentinel is the sole completion wait. |
| Pixel contract | The suite compares CPU and actual Metal output at `2e-4` maximum error, checks finite RGB, exact alpha bits, a non-zero data-window origin, padded stride, partial render-window byte preservation, and exact Metal identity copying. The parity request exercises premultiplied alpha. |
| OFX adapter | Five stable Filter/float RGBA effect registrations expose Core Definition parameter IDs, ranges, defaults, choices, presets, and Custom tracking. Host image bounds/stride/window/time/render scale/premultiplication and the host Metal queue become `RenderRequest` fields. |

## Scope boundary

No Resolve session was started: M1 is limited to the Headless Render Contract. The shared scaffold is intentionally the only effect math in this milestone; Halation, Grain, Mist, Optical Blur, and Lens Reflections algorithms remain owned by M2–M6.
