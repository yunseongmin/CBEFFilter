# M2 Halation

Status: passed

Artifact: `m2-halation-2026-08-12`

| Check | Evidence |
|---|---|
| Affected build | `make build` exited 0 for the arm64 bundle. |
| M1 regression | `make test-m1` exited 0: `headless_render_contract: PASS (CPU + Metal M1 contract)`. |
| Focused suite | `make test-m2` exited 0: `halation_render_contract: PASS (CPU + Metal M2 Halation)`. |
| Criteria 1: definition and presets | The focused definition checks six Halation parameters, three presets, default Subtle 35, preset expansion, and common parameter count. |
| Criteria 2: linear Halation math | Shape, threshold, warm colour, three-scale blur, core subtraction, and HDR fixtures exercise the canonical linear path. |
| Criteria 3: identity and diagnostics | Amount-zero identity, component output, highlight matte, and Mix-independent diagnostics are covered. |
| Criteria 4: matte/profile/colour gates | Threshold knee, non-negative halo, monotonic exterior profile, warm channel order, and core limit assertions pass. |
| Criteria 5: edge/alpha/HDR safety | Partial-window edge, straight and premultiplied alpha, negative residual, HDR, hidden RGB, and finite-output assertions pass. |
| Criteria 6: resolution invariance | The 1080p/4K PSNR, half-radius, and low-frequency energy fixture passes. |
| Criteria 7: CPU/Metal parity | Actual Metal queue execution and CPU parity are checked within `2e-4` by the focused suite. |
| Metal completion | The backend uses the supplied host `MTLCommandQueue`, commits the Halation command buffer, and returns `Enqueued`; the suite proves completion with a same-queue sentinel. |
| Pixel parity | The actual Metal Halation path uses three alpha-weighted separable Gaussian scales, matte/core subtraction, warm chroma, diagnostics, and re-association. CPU and Metal parity is checked at `2e-4`; straight/premultiplied alpha, HDR, hidden RGB, edge, resolution, and identity fixtures pass. |

Resolve was not launched; M2 is limited to the headless contract and actual Metal queue execution.
