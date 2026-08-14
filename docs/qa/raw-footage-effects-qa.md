# Official RAW footage effects QA

**Date:** 2026-08-12  
**Host:** DaVinci Resolve Free 21.0.4.5  
**Project / timeline:** `CBEF Film Effects QA` / `CBEF RAW 12K QA`  
**Result:** PASS

## Source material

- Official source page: <https://www.blackmagicdesign.com/products/blackmagicraw>
- Camera original: `A002_05241837_C028.braw`
- Download: `https://downloads.blackmagicdesign.com/products/blackmagicursaminipro12k/raw/A002_05241837_C028.braw.zip`
- Resolve-reported properties: 12288 x 6480, 24 fps, duration `00:00:04:07`
- BRAW size: 594,261,948 bytes
- BRAW SHA-256: `93672c8e2218aca8db5eb24e79e13271030021d62045ce124d8467d93ae86b54`
- ZIP size: 573,191,703 bytes
- ZIP SHA-256: `5d84ea949d51993bb71391f965264a382d7a4865bb17751c873405c1622ebb76`

Resolve imported the original BRAW directly into the Media Pool, created the timeline, decoded the frame, and displayed scopes without a missing-media or decode error.

## Method

The same viewer frame was captured before and after each effect. Every effect was set to `Rec.709 Gamma 2.4`, matching the current non-color-managed display pipeline. A strong built-in preset was intentionally chosen to make effect activation unambiguous. Each effect was removed before the next effect was applied.

The numeric comparison is an 8-bit viewer-screenshot check over a fixed 310 x 166 viewer crop (154,380 RGB channels). It is supporting evidence for host-level visible behavior, not a replacement for the existing float/Metal render-contract tests.

## Results

| Effect | Preset | Viewer MAE | Max channel delta | Channels changed by >=2 | Observation | Result |
|---|---|---:|---:|---:|---|---|
| Halation | Strong Edge | 1.515 | 59 | 37,920 | Warm edge spill appears around the large clipped lights and silhouette boundary. | PASS |
| Film Grain | 16mm | 1.390 | 13 | 57,454 | Fine stochastic texture is visible across the face, shadows, and lit background. | PASS |
| Lens Reflections | Anamorphic | 11.212 | 221 | 103,080 | Scene-reactive anamorphic ghosts are generated from the practical lights. | PASS |
| Mist Diffusion | Black 1 | 4.429 | 50 | 126,708 | Highlights bloom while the dark silhouette keeps comparatively stronger contrast. | PASS |
| Mist Diffusion | White 1 | 4.451 | 51 | 126,459 | A softer, brighter veil spreads through the highlight regions; behavior is distinct from Black 1. | PASS |
| Optical Blur | Anamorphic | 2.147 | 42 | 67,518 | Directional optical softening spreads edges and practical-light transitions. | PASS |

## Evidence retention

The measured viewer deltas and observations above are retained as the QA record. The original BRAW,
comparison sheet, and individual screenshots were removed after acceptance; the source URL and SHA-256 remain
in [`assets/qa/raw-footage/download-provenance.json`](../../assets/qa/raw-footage/download-provenance.json).

## Judgment

All five plugin effects load, render, update the viewer, and can be removed in DaVinci Resolve Free on an official 12K Blackmagic RAW camera original. The host remained responsive throughout the sequential apply/remove checks and the project saved successfully after cleanup.

These strong presets are proof-of-operation settings. A production grade should normally use subtler values and choose `DWG Intermediate` when the effect node is placed inside a DaVinci Wide Gamut Intermediate pipeline.
