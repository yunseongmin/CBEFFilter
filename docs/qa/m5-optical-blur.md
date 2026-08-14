# M5 Optical Blur QA Evidence

Date: 2026-08-12

## Acceptance run

Invocation:

```sh
make -B test-m5
```

Current consolidated output: [`21-optical-metal.log`](../evidence/v2-final-20260812/21-optical-metal.log).

Observed result: `optical_blur_render_contract: PASS (CPU + Metal M5 Optical Blur)`.

| Scenario | Invocation / binary | Observable | Artifact |
|---|---|---|---|
| Affected Metal object and focused contract build | `make -B test-m5` → `build/obj/metal/MetalRenderBackend.o`, `build/tests/optical_blur_render_contract` | exit 0 | [`21-optical-metal.log`](../evidence/v2-final-20260812/21-optical-metal.log) |
| M5 CPU + Metal contract | `build/tests/optical_blur_render_contract` | CPU aperture, identity, alpha/HDR, crop and same-queue Metal parity pass | [`21-optical-metal.log`](../evidence/v2-final-20260812/21-optical-metal.log) |

## M5 scenarios covered

- Four-by-four subpixel coverage unit-sum aperture, polygon/circle curvature, blades, rotation, anamorphism, centroid and analytic-support IoU.
- Constant-image preservation, resolution-scaled radius/energy, highlight-response monotonicity, and full-image/component views.
- Signed HDR values, transparent hidden RGB suppression, alpha bit preservation, data-window origin and render-window crop with destination sentinel preservation.
- Actual supplied Metal command queue submission, same-queue completion barrier, and CPU/Metal maximum channel error `<= 2e-4`.

Resolve visual tuning and performance measurements remain owned by M7.
