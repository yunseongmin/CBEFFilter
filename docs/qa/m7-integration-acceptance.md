# M7 integration acceptance

Status: passed.

## Acceptance summary

| Gate | Result |
|---|---|
| arm64 bundle and five stable effect IDs | PASS |
| CPU + actual Metal render contracts M1–M6 | PASS |
| Resolve Free loads all five effects | PASS |
| Color node application and live parameter panel | PASS |
| Studio badge, watermark, or DCTL dependency | Not observed |
| 1080p timing gates | PASS for all five effects |
| 4K timing gates | PASS for all five effects |
| 4K temporary and steady memory gates | PASS for all five effects |

## Performance evidence

The final benchmark used three warm-up frames and ten measured frames on an Apple M3 Pro. The machine-readable and Markdown reports are:

- [`m7-performance.json`](../evidence/v2-final-20260812/performance/m7-performance.json)
- [`m7-performance.md`](../evidence/v2-final-20260812/performance/m7-performance.md)

The UHD medians are Halation 50.92 ms, Film Grain 10.39 ms, Optical Blur 47.07 ms,
Lens Reflections 10.86 ms, and Mist Diffusion 9.95 ms. Every effect is below its timing and scratch limit,
with zero Frame Arena growth after warm-up.

## Host evidence

Resolve Free 21.0.4 loaded the five registered IDs from the user-level OpenFX bundle. A synthetic QA clip and timeline were created, the five-effect group was observed, and Halation was applied to a Color node with its controls visible.

The written [host run](../evidence/host-acceptance/host-run-20260812.md) and
[camera-original visual QA](../evidence/host-acceptance/visual-qa-20260812.md) are retained. Large screenshot
attachments were removed after acceptance.

Camera-original visual QA on five BRAW scenes also passed. The detailed observations and the two real-host
defects found and corrected during that pass are in the [host acceptance report](../evidence/host-acceptance/visual-qa-20260812.md).
