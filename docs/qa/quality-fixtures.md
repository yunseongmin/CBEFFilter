# Quality fixture contract

`fixtures/quality/generate_fixtures.py` creates the P0 synthetic suite without
third-party codecs or downloaded camera originals. The output uses the
repository's equivalent float source format:

| Field | Contract |
|---|---|
| Header | `CBEF_RGBA32F` followed by `width height` |
| Samples | Interleaved little-endian RGBA `float32` |
| Domain | Scene-linear, no transfer function, unclamped negative and HDR RGB |
| Alpha | Straight alpha in `[0, 1]` |
| Reproduction | `python3 fixtures/quality/generate_fixtures.py` |

The manifest and sidecar masks are generated together. Every fixture entry
records its generator revision, scene-linear encoding, resolution, frame,
crop, frame hash, mask hash, semantic mask labels, and metric provenance.
The suite covers exposure/color ramp, flat fields, point-source sweep/grid,
slanted edge, thin lines, signage and RGB LED sources, alpha boundaries, and
center/corner field PSF points.

Metric provenance is one of `standard`, `measured`, `internal tolerance`, or
`placeholder`. A placeholder is a temporary calibration target and cannot be
used to approve a measured film, filter, or lens profile. Standard method
definitions and project pass envelopes remain separate in the manifest.

`fixtures/quality/render_report.py` validates and compares JSON reports emitted
by the top-level `RenderRequest`/`RenderSubmission` contract. It deliberately
does not expose internal kernels or introduce a fake host. A future effect
contract test can emit the same fields for v1 baseline and v2 candidate runs,
then use the bridge to produce one JSON or Markdown comparison.

External camera-original policy is local-only. The ignored
`fixtures/quality/local-assets/` directory is available for a developer's
private cache, while the manifest stores no external records by default. Any
future record must include official URL, SHA-256, acquisition date, download
terms, clip/frame, decode, color transform, and explicit redistribution
rights. No downloaded asset is part of the fixture suite or installation
bundle.

## Focused verification

```text
python3 -m unittest tests/quality_fixture_test.py -v
```

The test runs the generator twice in separate temporary directories, compares
the complete manifests and bytes, validates finite float and alpha safety,
checks every manifest and mask hash, and exercises the render-report bridge.
