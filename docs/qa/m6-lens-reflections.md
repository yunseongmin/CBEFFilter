# M6 Lens Reflections QA Evidence

Date: 2026-08-12

## Acceptance run

Invocation:

```sh
make -B test-m6
```

Current consolidated output: [`26-lens-metal.log`](../evidence/v2-final-20260812/26-lens-metal.log).

Observed result: `lens_reflections_render_contract: PASS (CPU + Metal M6 Lens Reflections)`.

| Scenario | Invocation / binary | Observable | Artifact |
|---|---|---|---|
| Affected Metal object and focused contract build | `make -B test-m6` → `build/obj/metal/MetalRenderBackend.o`, `build/tests/lens_reflections_render_contract` | exit 0 | [`26-lens-metal.log`](../evidence/v2-final-20260812/26-lens-metal.log) |
| M6 CPU + actual Metal contract | `build/tests/lens_reflections_render_contract` | CPU source matte, threshold knee, affine ghost mapping, model ratios, amount monotonicity, off-screen handling, alpha/HDR, resolution, crop/sentinel and same-queue Metal parity pass | [`26-lens-metal.log`](../evidence/v2-final-20260812/26-lens-metal.log) |

## M6 scenarios covered

- Scene-reactive source matte with a one-stop threshold knee and full-frame affine forward mapping.
- Energy-conserving bilinear scatter equivalent, off-screen discard without wrap, anisotropic Gaussian blur, tint normalization, model energy, Chroma and Amount order.
- Final, Reflection Component and Source Matte diagnostics, exact identity, alpha/HDR suppression, 1080p/4K scaling, threshold popping and ghost centroid/model-energy assertions.
- Actual supplied Metal command queue submission, same-queue completion barrier, non-zero data-window crop, destination sentinel preservation and CPU/Metal maximum channel error `<= 2e-4`.

No fixed flare bitmap or connected-component tracking was added. Resolve visual tuning and performance measurements remain owned by M7.
