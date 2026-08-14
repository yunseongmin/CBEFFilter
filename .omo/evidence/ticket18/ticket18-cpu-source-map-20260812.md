# Ticket 18 — Lens source map and manual source

Date: 2026-08-12

## Implementation surface

- `src/core/RenderPlan.h` appends source-mode, metric, gamma, knee, morphology, manual source, optical-center, background adaptation, veil, and element-solo fields while retaining the existing Lens parameter prefix.
- `src/core/RenderCore.cpp` implements scene-linear positive-RGB source metrics, softened threshold, gamma, bounded morphology, deterministic 8x8 tile energy and top-8 spatial NMS, uses the selected maxima for Source Map diagnostics, and keeps an analytic off-screen-capable manual ellipse, Mix-independent source-map diagnostics, optical-center pivot, background adaptation, veil, and element-solo filtering.
- `fixtures/quality/generate_fixtures.py` adds source precision/recall/centroid/energy/continuity and saturated signage channel/determinism metrics with internal-tolerance provenance; generated manifest uses generator version 1.2.0.
- `tests/lens_source_map_cpu_contract.cpp` and `Makefile` add the public CPU source-map/manual-source contract.

## Verification

Command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-lens-source-cpu test-v2-compile test-v2-inspector test-m6-cpu test
python3 -m unittest tests/quality_fixture_test.py
```

Observed binary outputs:

- `lens_source_map_cpu_contract: PASS (v2 CPU source map + manual source)`
- `typed_compile_contract: PASS`
- `inspector_metadata_contract: PASS`
- `lens_reflections_render_contract: PASS (CPU + Metal M6 Lens Reflections)`
- `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)`
- `Ran 3 tests ... OK` for `tests/quality_fixture_test.py`

The build completed with only existing unused-constant/variable warnings in the grain and Metal paths. The CPU focused contract covers independent multi-source detection, source-map output at Mix 0, dark-background rejection, per-source centroid tolerance, threshold continuity, manual centroid tolerance, manual intensity monotonicity, same-frame byte determinism, and off-screen no-wrap.
