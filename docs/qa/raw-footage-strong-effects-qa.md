# Official RAW footage strong-effects QA

**Date:** 2026-08-12  
**Host:** DaVinci Resolve Free 21.0.4.5  
**Source:** official Blackmagic RAW `A002_05241837_C028.braw` (12288 x 6480, 24 fps)  
**Result:** PASS

## Purpose

The first RAW check used production-oriented presets whose changes could be difficult to see in a small chat preview. This pass deliberately uses stronger settings and a 3x enlarged viewer crop. These are visibility/proof settings, not recommended grading defaults.

All captures use the same timeline frame and `Rec.709 Gamma 2.4` working mode. Each effect was removed before the next test.

## Strong settings and measured viewer changes

| Effect | Strong setting | Viewer MAE | Max channel delta | Channels changed by >=2 | Result |
|---|---|---:|---:|---:|---|
| Halation | Strong Edge, Amount 100 | 0.529 | 8 | 17,202 | PASS |
| Film Grain | 16mm, Amount 100 | 1.217 | 13 | 48,981 | PASS |
| Lens Reflections | Anamorphic, Amount 70 | 10.568 | 218 | 81,039 | PASS |
| Mist Diffusion | Black 1 | 3.686 | 38 | 116,555 | PASS |
| Mist Diffusion | White 1 | 14.952 | 65 | 142,643 | PASS |
| Optical Blur | Anamorphic, Blur 1.0 | 0.988 | 29 | 33,738 | PASS |

The comparison is an 8-bit screenshot measurement over the fixed 310 x 166 Resolve viewer crop (154,380 RGB channels). It supports the direct host observation and complements the existing float/Metal render-contract tests.

## Visual findings

- Halation: warm contamination is visible along the clipped practical-light edges and the subject silhouette, while the rest of the frame stays comparatively intact.
- Film Grain: the 16 mm texture is easiest to see in the large white practicals and the smooth red background.
- Lens Reflections: anamorphic ghost shapes clearly respond to the source practicals.
- Black Mist: bloom expands with more retained subject contrast.
- White Mist: the strongest global veil and highlight spread in this shot; clearly distinct from Black Mist.
- Optical Blur: edge transitions are directionally softened without introducing the reflection ghosts seen in Lens Reflections.

## Evidence retention

The measured viewer deltas and visual findings above are retained as the QA record. The source BRAW and enlarged
screenshots were removed after acceptance; source provenance remains in
[`assets/qa/raw-footage/download-provenance.json`](../../assets/qa/raw-footage/download-provenance.json).

The plugin was removed from the node after the last capture and the Resolve project was saved in its clean baseline state.
